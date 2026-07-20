import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Community/comment.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';
import 'package:coffeecore/screens/Community/community_notification.dart';
import 'package:coffeecore/screens/Community/community_notification_service.dart';
import 'package:coffeecore/screens/Community/post.dart';
import 'package:coffeecore/screens/Community/user_mini_profile.dart';
import 'package:coffeecore/screens/Community/repository.dart';

/// Firestore collections used by this feature:
///   community_posts/{postId}
///   community_posts/{postId} fields include denormalized upvote_count,
///     downvote_count, comment_count — never trust a client write to these
///     directly; only transactions/increments touch them.
///   community_comments/{commentId}            (flat, has post_id + parent_comment_id)
///   community_post_votes/{postId}_{userId}     (direction: 'up' | 'down')
///   community_comment_votes/{commentId}_{userId}
///
/// Composite indexes: Firestore will show a console link the first time you
/// run a query combining a `where` filter with `orderBy` on a different
/// field (e.g. category + sort by created_at) — click it once per query
/// shape, it's a one-time setup per index, not a per-request cost.
class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl(this._firestore, this._auth)
      : _notifications = CommunityNotificationService(_firestore, _auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final CommunityNotificationService _notifications;
  final Logger _logger = Logger(printer: PrettyPrinter());

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('community_posts');
  CollectionReference<Map<String, dynamic>> get _comments =>
      _firestore.collection('community_comments');
  CollectionReference<Map<String, dynamic>> get _postVotes =>
      _firestore.collection('community_post_votes');
  CollectionReference<Map<String, dynamic>> get _commentVotes =>
      _firestore.collection('community_comment_votes');
  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('community_reports');

  String get _uidOrThrow {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Must be signed in to do this.');
    return uid;
  }

  @override
  Future<PostsPage> fetchPosts({
    required SortOption sort,
    PostCategory? category,
    CropCategory? crop,
    required int limit,
    Object? startAfter,
  }) async {
    try {
      _logger.i(
        'Community fetchPosts: sort=${sort.name}, category=${category?.name}, crop=${crop?.name}, limit=$limit, hasCursor=${startAfter is DocumentSnapshot<Map<String, dynamic>>}',
      );

      Query<Map<String, dynamic>> query = _posts;

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }
      if (crop != null) {
        query = query.where('crop_category', isEqualTo: crop.name);
      }

      query = sort == SortOption.topVoted
          ? query
              .orderBy('upvote_count', descending: true)
              .orderBy('created_at', descending: true)
          : query.orderBy('created_at', descending: true);

      query = query.limit(limit);
      if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      var posts = snapshot.docs
          .map((doc) => CommunityPost.fromJson(doc.data(), doc.id))
          .toList(growable: true);

      posts = await _mergeMyPostVotes(posts);

      _logger.i('Community fetchPosts succeeded with ${posts.length} posts');

      return PostsPage(
        posts: posts,
        cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (error, stackTrace) {
      _logger.e(
        'Community fetchPosts failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Batches the "does the current user have a vote on any of these posts"
  /// check into a single query instead of one read per post. whereIn
  /// supports up to 30 values, which comfortably covers one feed page.
  Future<List<CommunityPost>> _mergeMyPostVotes(
      List<CommunityPost> posts) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || posts.isEmpty) return posts;

    final ids = posts.map((p) => p.id).toList();
    final voteSnap = await _postVotes
        .where('user_id', isEqualTo: uid)
        .where('post_id', whereIn: ids)
        .get();

    final myVotes = {
      for (final d in voteSnap.docs)
        d.data()['post_id'] as String: d.data()['direction'] as String,
    };

    return [
      for (final p in posts)
        if (myVotes[p.id] != null)
          p.copyWith(
              myVote:
                  myVotes[p.id] == 'up' ? VoteDirection.up : VoteDirection.down)
        else
          p,
    ];
  }

  @override
  Future<CommunityPost> fetchPost(String postId) async {
    final doc = await _posts.doc(postId).get();
    if (!doc.exists) throw StateError('Post not found.');
    var post = CommunityPost.fromJson(doc.data()!, doc.id);
    final merged = await _mergeMyPostVotes([post]);
    return merged.first;
  }

  @override
  Future<CommunityPost> createPost({
    required String title,
    required String description,
    required PostCategory category,
    CropCategory? crop,
    required PostType type,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Must be signed in to post.');

    final author = UserMiniProfile(
      uid: user.uid,
      displayName: user.displayName ?? 'Anonymous Farmer',
      avatarUrl: user.photoURL,
    );

    final draft = CommunityPost(
      id: '',
      author: author,
      title: title,
      description: description,
      category: category,
      cropCategory: crop,
      type: type,
      upvotes: 0,
      downvotes: 0,
      commentCount: 0,
      createdAt: DateTime.now(),
    );

    final ref = await _posts.add(draft.toJson());
    final saved = await ref.get();
    return CommunityPost.fromJson(saved.data()!, saved.id);
  }

  @override
  Future<void> attachImages(
      {required String postId, required List<String> imageUrls}) async {
    await _posts.doc(postId).update({'image_urls': imageUrls});
  }

  @override
  Future<void> voteOnPost(
      {required String postId, required VoteDirection direction}) async {
    final uid = _uidOrThrow;
    final voteRef = _postVotes.doc('${postId}_$uid');
    final postRef = _posts.doc(postId);

    await _firestore.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) throw StateError('Post no longer exists.');

      final existing = voteSnap.data()?['direction'] as String?;
      final updates = <String, dynamic>{};

      if (existing == direction.name) {
        // Same direction tapped again — undo the vote.
        tx.delete(voteRef);
        updates[_countField(direction)] = FieldValue.increment(-1);
      } else {
        if (existing != null) {
          updates[_countField(_fromName(existing))] = FieldValue.increment(-1);
        }
        updates[_countField(direction)] = FieldValue.increment(1);
        tx.set(voteRef, {
          'post_id': postId,
          'user_id': uid,
          'direction': direction.name,
          'voted_at': FieldValue.serverTimestamp(),
        });
      }

      tx.update(postRef, updates);
    });
  }

  @override
  Future<List<Comment>> fetchComments(String postId) async {
    try {
      _logger.i('Community fetchComments: postId=$postId');

      final snapshot = await _comments
          .where('post_id', isEqualTo: postId)
          .orderBy('created_at', descending: false)
          .get();

      var comments = snapshot.docs
          .map((doc) => Comment.fromJson(doc.data(), doc.id))
          .toList(growable: true);

      final uid = _auth.currentUser?.uid;
      if (uid != null && comments.isNotEmpty) {
        // Q&A threads rarely exceed 30 comments; if yours regularly do, chunk
        // this into batches of 30 ids per whereIn call.
        final ids = comments.map((c) => c.id).toList();
        final voteSnap = await _commentVotes
            .where('user_id', isEqualTo: uid)
            .where('comment_id', whereIn: ids)
            .get();
        final myVotes = {
          for (final d in voteSnap.docs)
            d.data()['comment_id'] as String: d.data()['direction'] as String,
        };
        comments = [
          for (final c in comments)
            if (myVotes[c.id] != null)
              c.copyWith(
                  myVote: myVotes[c.id] == 'up'
                      ? VoteDirection.up
                      : VoteDirection.down)
            else
              c,
        ];
      }

      _logger.i(
          'Community fetchComments succeeded with ${comments.length} comments');
      return comments;
    } catch (error, stackTrace) {
      _logger.e(
        'Community fetchComments failed for postId=$postId',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<Comment> addComment({
    required String postId,
    required String body,
    String? parentCommentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Must be signed in to comment.');

    final author = UserMiniProfile(
      uid: user.uid,
      displayName: user.displayName ?? 'Anonymous Farmer',
      avatarUrl: user.photoURL,
    );

    final draft = Comment(
      id: '',
      postId: postId,
      parentCommentId: parentCommentId,
      author: author,
      body: body,
      upvotes: 0,
      downvotes: 0,
      isAcceptedSolution: false,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    final commentRef = _comments.doc();
    batch.set(commentRef, draft.toJson());
    batch
        .update(_posts.doc(postId), {'comment_count': FieldValue.increment(1)});
    await batch.commit();

    final saved = await commentRef.get();
    final comment = Comment.fromJson(saved.data()!, saved.id);

    await _notifyOnComment(
        postId: postId, parentCommentId: parentCommentId, body: body);

    return comment;
  }

  /// Notifies the post author, and — for a reply — the parent comment's
  /// author too (if different from the post author, so they're not double
  /// notified). Failures here are logged, never surfaced to the commenter:
  /// a notification that didn't send shouldn't make posting look like it
  /// failed.
  Future<void> _notifyOnComment({
    required String postId,
    required String? parentCommentId,
    required String body,
  }) async {
    try {
      final postSnap = await _posts.doc(postId).get();
      final postData = postSnap.data();
      if (postData == null) return;
      final postTitle = postData['title'] as String? ?? 'your post';
      final postAuthorId =
          (postData['author'] as Map<String, dynamic>?)?['uid'] as String?;

      final preview = body.length > 100 ? '${body.substring(0, 100)}...' : body;

      if (postAuthorId != null) {
        await _notifications.notify(
          recipientId: postAuthorId,
          type: parentCommentId == null
              ? CommunityNotificationType.replyToPost
              : CommunityNotificationType.replyToComment,
          message: 'New comment on "$postTitle": $preview',
          postId: postId,
        );
      }

      if (parentCommentId != null) {
        final parentSnap = await _comments.doc(parentCommentId).get();
        final parentAuthorId = (parentSnap.data()?['author']
            as Map<String, dynamic>?)?['uid'] as String?;
        if (parentAuthorId != null && parentAuthorId != postAuthorId) {
          await _notifications.notify(
            recipientId: parentAuthorId,
            type: CommunityNotificationType.replyToComment,
            message: 'New reply on "$postTitle": $preview',
            postId: postId,
            commentId: parentCommentId,
          );
        }
      }
    } catch (error, stackTrace) {
      _logger.e('Failed to send comment notification',
          error: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> voteOnComment({
    required String postId,
    required String commentId,
    required VoteDirection direction,
  }) async {
    final uid = _uidOrThrow;
    final voteRef = _commentVotes.doc('${commentId}_$uid');
    final commentRef = _comments.doc(commentId);

    await _firestore.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      final commentSnap = await tx.get(commentRef);
      if (!commentSnap.exists) throw StateError('Comment no longer exists.');

      final existing = voteSnap.data()?['direction'] as String?;
      final updates = <String, dynamic>{};

      if (existing == direction.name) {
        tx.delete(voteRef);
        updates[_countField(direction)] = FieldValue.increment(-1);
      } else {
        if (existing != null) {
          updates[_countField(_fromName(existing))] = FieldValue.increment(-1);
        }
        updates[_countField(direction)] = FieldValue.increment(1);
        tx.set(voteRef, {
          'comment_id': commentId,
          'user_id': uid,
          'direction': direction.name,
          'voted_at': FieldValue.serverTimestamp(),
        });
      }

      tx.update(commentRef, updates);
    });
  }

  @override
  Future<void> markAcceptedSolution(
      {required String postId, required String commentId}) async {
    final batch = _firestore.batch();
    batch.update(_posts.doc(postId), {'accepted_comment_id': commentId});
    batch.update(_comments.doc(commentId), {'is_accepted_solution': true});
    await batch.commit();
    // The previously-accepted comment's own is_accepted_solution flag (if
    // any) is cleared server-side by the onCommunityPostUpdated Cloud
    // Function trigger (functions/index.js), not here — keeps "only one
    // accepted answer" enforced even if the client that made this call
    // never sees the result.

    try {
      final commentSnap = await _comments.doc(commentId).get();
      final commentAuthorId = (commentSnap.data()?['author']
          as Map<String, dynamic>?)?['uid'] as String?;
      final postSnap = await _posts.doc(postId).get();
      final postTitle = postSnap.data()?['title'] as String? ?? 'your answer';
      if (commentAuthorId != null) {
        await _notifications.notify(
          recipientId: commentAuthorId,
          type: CommunityNotificationType.acceptedSolution,
          message: 'Your answer was accepted as the solution to "$postTitle"',
          postId: postId,
          commentId: commentId,
        );
      }
    } catch (error, stackTrace) {
      _logger.e('Failed to send accepted-solution notification',
          error: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    final uid = _uidOrThrow;
    final snap = await _posts.doc(postId).get();
    final authorId =
        (snap.data()?['author'] as Map<String, dynamic>?)?['uid'] as String?;
    if (authorId != uid) {
      throw StateError('Only the author can delete this post.');
    }
    await _posts.doc(postId).delete();
  }

  @override
  Future<void> deleteComment(
      {required String postId, required String commentId}) async {
    final uid = _uidOrThrow;
    final snap = await _comments.doc(commentId).get();
    final authorId =
        (snap.data()?['author'] as Map<String, dynamic>?)?['uid'] as String?;
    if (authorId != uid) {
      throw StateError('Only the author can delete this comment.');
    }

    final batch = _firestore.batch();
    batch.delete(_comments.doc(commentId));
    batch.update(
        _posts.doc(postId), {'comment_count': FieldValue.increment(-1)});
    await batch.commit();
  }

  @override
  Future<void> reportPost(
      {required String postId, required String reason}) async {
    final uid = _uidOrThrow;
    await _reports.add({
      'target_type': 'post',
      'target_id': postId,
      'reporter_id': uid,
      'reason': reason,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String reason,
  }) async {
    final uid = _uidOrThrow;
    await _reports.add({
      'target_type': 'comment',
      'target_id': commentId,
      'post_id': postId,
      'reporter_id': uid,
      'reason': reason,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  String _countField(VoteDirection d) =>
      d == VoteDirection.up ? 'upvote_count' : 'downvote_count';
  VoteDirection _fromName(String name) =>
      name == 'up' ? VoteDirection.up : VoteDirection.down;
}
