import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:coffeecore/screens/Community/comment.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';
import 'package:coffeecore/screens/Community/post.dart';
//import 'package:coffeecore/screens/Community/.dart';

import 'providers.dart';

part 'post_detail_notifier.g.dart';

class PostDetailState {
  final CommunityPost post;

  /// The accepted answer, shown pinned above the rest — null if this isn't
  /// a question or no answer has been accepted yet.
  final Comment? acceptedComment;

  /// Everything else, sorted by net score descending (Stack Overflow order).
  final List<Comment> otherComments;

  final bool isSubmittingComment;

  const PostDetailState({
    required this.post,
    this.acceptedComment,
    required this.otherComments,
    this.isSubmittingComment = false,
  });

  PostDetailState copyWith({
    CommunityPost? post,
    Comment? acceptedComment,
    bool clearAcceptedComment = false,
    List<Comment>? otherComments,
    bool? isSubmittingComment,
  }) {
    return PostDetailState(
      post: post ?? this.post,
      acceptedComment: clearAcceptedComment
          ? null
          : (acceptedComment ?? this.acceptedComment),
      otherComments: otherComments ?? this.otherComments,
      isSubmittingComment: isSubmittingComment ?? this.isSubmittingComment,
    );
  }
}

@riverpod
class PostDetailNotifier extends _$PostDetailNotifier {
  // Captured explicitly in build() rather than relying on generated
  // family-argument getters, so this stays correct across riverpod_generator
  // versions that differ on whether/how those getters are exposed.
  late final String _postId;

  @override
  Future<PostDetailState> build(String postId) async {
    _postId = postId;
    return _loadAll();
  }

  Future<PostDetailState> _loadAll() async {
    final repo = ref.read(communityRepositoryProvider);
    final post = await repo.fetchPost(_postId);
    final flatComments = await repo.fetchComments(_postId);
    return _buildState(post, flatComments);
  }

  PostDetailState _buildState(CommunityPost post, List<Comment> flat) {
    final byParent = <String?, List<Comment>>{};
    for (final c in flat) {
      byParent.putIfAbsent(c.parentCommentId, () => []).add(c);
    }

    Comment withReplies(Comment c) {
      final replies = List<Comment>.from(byParent[c.id] ?? [])
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return c.copyWith(replies: replies);
    }

    final topLevel = (byParent[null] ?? []).map(withReplies).toList();

    Comment? accepted;
    final rest = <Comment>[];
    for (final c in topLevel) {
      if (post.acceptedCommentId != null && c.id == post.acceptedCommentId) {
        accepted = c;
      } else {
        rest.add(c);
      }
    }
    rest.sort((a, b) => b.netScore.compareTo(a.netScore));

    return PostDetailState(
        post: post, acceptedComment: accepted, otherComments: rest);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_loadAll);
  }

  Future<void> votePost(VoteDirection direction) async {
    final current = state.value;
    if (current == null) return;

    final optimistic = _applyOptimisticVoteToPost(current.post, direction);
    state = AsyncData(current.copyWith(post: optimistic));

    try {
      await ref
          .read(communityRepositoryProvider)
          .voteOnPost(postId: current.post.id, direction: direction);
    } catch (_) {
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(post: current.post));
      rethrow;
    }
  }

  Future<void> voteComment(Comment comment, VoteDirection direction) async {
    final current = state.value;
    if (current == null) return;

    final optimistic = _applyOptimisticVoteToComment(comment, direction);
    state = AsyncData(_replaceComment(current, comment.id, optimistic));

    try {
      await ref.read(communityRepositoryProvider).voteOnComment(
          postId: _postId, commentId: comment.id, direction: direction);
    } catch (_) {
      final latest = state.value ?? current;
      state = AsyncData(_replaceComment(latest, comment.id, comment));
      rethrow;
    }
  }

  PostDetailState _replaceComment(
      PostDetailState s, String commentId, Comment updated) {
    if (s.acceptedComment?.id == commentId) {
      return s.copyWith(acceptedComment: updated);
    }
    return s.copyWith(
      otherComments: [
        for (final c in s.otherComments)
          if (c.id == commentId)
            updated
          else if (c.replies.any((r) => r.id == commentId))
            c.copyWith(replies: [
              for (final r in c.replies)
                if (r.id == commentId) updated else r,
            ])
          else
            c,
      ],
    );
  }

  Future<void> addComment(
      {required String body, String? parentCommentId}) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isSubmittingComment: true));
    try {
      await ref.read(communityRepositoryProvider).addComment(
          postId: _postId, body: body, parentCommentId: parentCommentId);
      // Re-fetch rather than hand-splice a new comment in — avoids having to
      // fabricate a temporary id and reconcile it against the server's real
      // one, which is a common source of duplicate-widget bugs.
      state = await AsyncValue.guard(_loadAll);
    } catch (_) {
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(isSubmittingComment: false));
      rethrow;
    }
  }

  Future<void> acceptSolution(Comment comment) async {
    final current = state.value;
    if (current == null) return;

    // Optimistic: pin it immediately, mark the post answered.
    state = AsyncData(current.copyWith(
      acceptedComment: comment.copyWith(isAcceptedSolution: true),
      otherComments:
          current.otherComments.where((c) => c.id != comment.id).toList(),
      post: current.post.copyWith(acceptedCommentId: comment.id),
    ));

    try {
      await ref
          .read(communityRepositoryProvider)
          .markAcceptedSolution(postId: _postId, commentId: comment.id);
    } catch (_) {
      state =
          await AsyncValue.guard(_loadAll); // reconcile from server on failure
      rethrow;
    }
  }

  /// Caller is responsible for popping the screen once this resolves —
  /// there's no more post to show detail for after this succeeds.
  Future<void> deletePost() {
    return ref.read(communityRepositoryProvider).deletePost(_postId);
  }

  Future<void> deleteComment(String commentId) async {
    await ref
        .read(communityRepositoryProvider)
        .deleteComment(postId: _postId, commentId: commentId);
    state = await AsyncValue.guard(_loadAll);
  }

  Future<void> reportPost(String reason) {
    return ref
        .read(communityRepositoryProvider)
        .reportPost(postId: _postId, reason: reason);
  }

  Future<void> reportComment(
      {required String commentId, required String reason}) {
    return ref
        .read(communityRepositoryProvider)
        .reportComment(postId: _postId, commentId: commentId, reason: reason);
  }

  CommunityPost _applyOptimisticVoteToPost(
      CommunityPost post, VoteDirection tapped) {
    final current = post.myVote;
    var up = post.upvotes;
    var down = post.downvotes;

    if (current == tapped) {
      tapped == VoteDirection.up ? up-- : down--;
      return post.copyWith(upvotes: up, downvotes: down, clearMyVote: true);
    }
    if (current == VoteDirection.up) up--;
    if (current == VoteDirection.down) down--;
    tapped == VoteDirection.up ? up++ : down++;
    return post.copyWith(upvotes: up, downvotes: down, myVote: tapped);
  }

  Comment _applyOptimisticVoteToComment(Comment comment, VoteDirection tapped) {
    final current = comment.myVote;
    var up = comment.upvotes;
    var down = comment.downvotes;

    if (current == tapped) {
      tapped == VoteDirection.up ? up-- : down--;
      return comment.copyWith(upvotes: up, downvotes: down, clearMyVote: true);
    }
    if (current == VoteDirection.up) up--;
    if (current == VoteDirection.down) down--;
    tapped == VoteDirection.up ? up++ : down++;
    return comment.copyWith(upvotes: up, downvotes: down, myVote: tapped);
  }
}
