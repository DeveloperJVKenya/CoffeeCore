import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_enums.dart';
import 'user_mini_profile.dart';

class Comment {
  final String id;
  final String postId;

  /// null = top-level comment. Non-null = a one-level-deep reply to another
  /// comment. Replies never reply to replies — that's the "at least 1 level
  /// deep" requirement, kept intentionally shallow rather than infinitely
  /// recursive (which gets hard to read on a phone screen anyway).
  final String? parentCommentId;

  final UserMiniProfile author;
  final String body;
  final int upvotes;
  final int downvotes;
  final bool isAcceptedSolution;
  final DateTime createdAt;

  /// Populated by PostDetailNotifier after fetching the flat list — never
  /// stored nested in Firestore. See CommunityRepositoryImpl.fetchComments.
  final List<Comment> replies;

  final VoteDirection? myVote;

  const Comment({
    required this.id,
    required this.postId,
    this.parentCommentId,
    required this.author,
    required this.body,
    required this.upvotes,
    required this.downvotes,
    required this.isAcceptedSolution,
    required this.createdAt,
    this.replies = const [],
    this.myVote,
  });

  bool get isTopLevel => parentCommentId == null;
  int get netScore => upvotes - downvotes;

  factory Comment.fromJson(Map<String, dynamic> json, String id) {
    return Comment(
      id: id,
      postId: json['post_id'] as String,
      parentCommentId: json['parent_comment_id'] as String?,
      author: UserMiniProfile.fromJson(json['author'] as Map<String, dynamic>),
      body: json['body'] as String,
      upvotes: (json['upvote_count'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvote_count'] as num?)?.toInt() ?? 0,
      isAcceptedSolution: json['is_accepted_solution'] as bool? ?? false,
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'parent_comment_id': parentCommentId,
      'author': author.toJson(),
      'body': body,
      'upvote_count': 0,
      'downvote_count': 0,
      'is_accepted_solution': false,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  Comment copyWith({
    int? upvotes,
    int? downvotes,
    bool? isAcceptedSolution,
    List<Comment>? replies,
    VoteDirection? myVote,
    bool clearMyVote = false,
  }) {
    return Comment(
      id: id,
      postId: postId,
      parentCommentId: parentCommentId,
      author: author,
      body: body,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      isAcceptedSolution: isAcceptedSolution ?? this.isAcceptedSolution,
      createdAt: createdAt,
      replies: replies ?? this.replies,
      myVote: clearMyVote ? null : (myVote ?? this.myVote),
    );
  }
}
