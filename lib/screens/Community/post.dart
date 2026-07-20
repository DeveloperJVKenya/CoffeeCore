import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_enums.dart';
import 'user_mini_profile.dart';

class CommunityPost {
  final String id;
  final UserMiniProfile author;
  final String title;
  final String description;
  final PostCategory category;
  final CropCategory? cropCategory;
  final PostType type;
  final int upvotes;
  final int downvotes;
  final int commentCount;
  final String? acceptedCommentId; // meaningful only when type == question
  final DateTime createdAt;

  /// Photos attached to the post (e.g. a leaf symptom, farm condition) —
  /// uploaded to Firebase Storage after the post document is created, then
  /// patched in via [CommunityRepository.attachImages]. Empty for
  /// text-only posts.
  final List<String> imageUrls;

  /// The CURRENT user's vote on this post. This is never stored on the post
  /// document itself — it's merged in client-side after a separate batched
  /// query against the votes collection (see CommunityRepositoryImpl).
  final VoteDirection? myVote;

  const CommunityPost({
    required this.id,
    required this.author,
    required this.title,
    required this.description,
    required this.category,
    this.cropCategory,
    required this.type,
    required this.upvotes,
    required this.downvotes,
    required this.commentCount,
    this.acceptedCommentId,
    required this.createdAt,
    this.imageUrls = const [],
    this.myVote,
  });

  bool get isQuestion => type == PostType.question;
  bool get isAnswered => acceptedCommentId != null;
  int get netScore => upvotes - downvotes;

  factory CommunityPost.fromJson(Map<String, dynamic> json, String id) {
    return CommunityPost(
      id: id,
      author: UserMiniProfile.fromJson(json['author'] as Map<String, dynamic>),
      title: json['title'] as String,
      description: json['description'] as String,
      category: PostCategory.values.byName(json['category'] as String),
      cropCategory: json['crop_category'] != null
          ? CropCategory.values.byName(json['crop_category'] as String)
          : null,
      type: PostType.values.byName(json['type'] as String? ?? 'discussion'),
      upvotes: (json['upvote_count'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvote_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      acceptedCommentId: json['accepted_comment_id'] as String?,
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrls:
          (json['image_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
      // myVote intentionally NOT read from json — merged in separately.
    );
  }

  /// Used only when creating a new post — counts and timestamp are set by
  /// the server, not the client, to prevent a malicious client from writing
  /// fake vote counts.
  Map<String, dynamic> toJson() {
    return {
      'author': author.toJson(),
      'title': title,
      'description': description,
      'category': category.name,
      'crop_category': cropCategory?.name,
      'type': type.name,
      'upvote_count': 0,
      'downvote_count': 0,
      'comment_count': 0,
      'accepted_comment_id': null,
      'created_at': FieldValue.serverTimestamp(),
      'image_urls': const <String>[],
    };
  }

  CommunityPost copyWith({
    int? upvotes,
    int? downvotes,
    int? commentCount,
    String? acceptedCommentId,
    bool clearAcceptedCommentId = false,
    List<String>? imageUrls,
    VoteDirection? myVote,
    bool clearMyVote = false,
  }) {
    return CommunityPost(
      id: id,
      author: author,
      title: title,
      description: description,
      category: category,
      cropCategory: cropCategory,
      type: type,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      commentCount: commentCount ?? this.commentCount,
      acceptedCommentId: clearAcceptedCommentId
          ? null
          : (acceptedCommentId ?? this.acceptedCommentId),
      createdAt: createdAt,
      imageUrls: imageUrls ?? this.imageUrls,
      myVote: clearMyVote ? null : (myVote ?? this.myVote),
    );
  }
}
