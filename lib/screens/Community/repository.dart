import 'package:coffeecore/screens/Community/comment.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';
import 'package:coffeecore/screens/Community/post.dart';

/// One page of posts plus an opaque cursor for fetching the next page.
/// [cursor] is typed `Object?` rather than `DocumentSnapshot` so this file —
/// part of the domain layer — has zero dependency on `cloud_firestore`.
/// The data-layer implementation is what knows what's actually inside it.
class PostsPage {
  final List<CommunityPost> posts;
  final Object? cursor;

  const PostsPage({required this.posts, required this.cursor});
}

abstract class CommunityRepository {
  Future<PostsPage> fetchPosts({
    required SortOption sort,
    PostCategory? category,
    CropCategory? crop,
    required int limit,
    Object? startAfter,
  });

  Future<CommunityPost> fetchPost(String postId);

  Future<CommunityPost> createPost({
    required String title,
    required String description,
    required PostCategory category,
    CropCategory? crop,
    required PostType type,
  });

  /// Patches the photo URLs onto an already-created post — called after
  /// [createPost] once the images have been uploaded to Storage under the
  /// new post's id (see CommunityStorageService).
  Future<void> attachImages(
      {required String postId, required List<String> imageUrls});

  Future<void> voteOnPost(
      {required String postId, required VoteDirection direction});

  /// Returns the flat list of comments for a post (both top-level and
  /// replies) — nesting into a tree is the presentation/application layer's
  /// job, not the repository's.
  Future<List<Comment>> fetchComments(String postId);

  Future<Comment> addComment({
    required String postId,
    required String body,
    String? parentCommentId,
  });

  Future<void> voteOnComment(
      {required String postId,
      required String commentId,
      required VoteDirection direction});

  Future<void> markAcceptedSolution(
      {required String postId, required String commentId});

  /// Only the original author may delete their own post (enforced by
  /// firestore.rules too — this is not the only line of defense).
  Future<void> deletePost(String postId);

  Future<void> deleteComment(
      {required String postId, required String commentId});

  Future<void> reportPost({required String postId, required String reason});

  Future<void> reportComment(
      {required String postId,
      required String commentId,
      required String reason});
}
