import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';
import 'package:coffeecore/screens/Community/post.dart';
import 'providers.dart';

part 'feed_notifier.g.dart';

const _pageSize = 15;

class CommunityFeedState {
  final List<CommunityPost> posts;
  final bool hasMore;
  final bool isLoadingMore;
  final SortOption sort;
  final PostCategory? categoryFilter;
  final CropCategory? cropFilter;
  final Object? cursor;

  const CommunityFeedState({
    this.posts = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.sort = SortOption.mostRecent,
    this.categoryFilter,
    this.cropFilter,
    this.cursor,
  });

  CommunityFeedState copyWith({
    List<CommunityPost>? posts,
    bool? hasMore,
    bool? isLoadingMore,
    SortOption? sort,
    PostCategory? categoryFilter,
    bool clearCategoryFilter = false,
    CropCategory? cropFilter,
    bool clearCropFilter = false,
    Object? cursor,
  }) {
    return CommunityFeedState(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      sort: sort ?? this.sort,
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      cropFilter: clearCropFilter ? null : (cropFilter ?? this.cropFilter),
      cursor: cursor ?? this.cursor,
    );
  }
}

@riverpod
class CommunityFeedNotifier extends _$CommunityFeedNotifier {
  final Logger _logger = Logger(printer: PrettyPrinter());

  @override
  Future<CommunityFeedState> build() {
    return _fetchFirstPage(
      sort: SortOption.mostRecent,
      category: null,
      crop: null,
    );
  }

  Future<CommunityFeedState> _fetchFirstPage({
    required SortOption sort,
    required PostCategory? category,
    required CropCategory? crop,
  }) async {
    try {
      _logger.i(
        'Community feed initial load: sort=${sort.name}, category=${category?.name}, crop=${crop?.name}',
      );

      final repo = ref.read(communityRepositoryProvider);
      final page = await repo.fetchPosts(
          sort: sort, category: category, crop: crop, limit: _pageSize);
      return CommunityFeedState(
        posts: page.posts,
        hasMore: page.posts.length == _pageSize,
        cursor: page.cursor,
        sort: sort,
        categoryFilter: category,
        cropFilter: crop,
      );
    } catch (error, stackTrace) {
      _logLoadFailure('initial feed load', error, stackTrace);
      rethrow;
    }
  }

  /// Called by the scroll listener near the bottom of the list.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final repo = ref.read(communityRepositoryProvider);
      final page = await repo.fetchPosts(
        sort: current.sort,
        category: current.categoryFilter,
        crop: current.cropFilter,
        limit: _pageSize,
        startAfter: current.cursor,
      );

      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(
        posts: [...latest.posts, ...page.posts],
        hasMore: page.posts.length == _pageSize,
        cursor: page.cursor ?? latest.cursor,
        isLoadingMore: false,
      ));
    } catch (error, stackTrace) {
      _logLoadFailure('load more feed items', error, stackTrace);
      state = AsyncData(current.copyWith(isLoadingMore: false));
      rethrow;
    }
  }

  Future<void> refresh() async {
    final current = state.value ?? const CommunityFeedState();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(
          sort: current.sort,
          category: current.categoryFilter,
          crop: current.cropFilter),
    );
  }

  Future<void> updateSort(SortOption sort) async {
    final current = state.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(
        sort: sort,
        category: current?.categoryFilter,
        crop: current?.cropFilter,
      ),
    );
  }

  Future<void> updateCategoryFilter(PostCategory? category) async {
    final current = state.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(
        sort: current?.sort ?? SortOption.mostRecent,
        category: category,
        crop: current?.cropFilter,
      ),
    );
  }

  Future<void> updateCropFilter(CropCategory? crop) async {
    final current = state.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(
        sort: current?.sort ?? SortOption.mostRecent,
        category: current?.categoryFilter,
        crop: crop,
      ),
    );
  }

  /// Optimistic vote: the UI updates instantly; if the network call fails,
  /// the original post is restored and the caller can show a snackbar.
  Future<void> vote(CommunityPost post, VoteDirection direction) async {
    final current = state.value;
    if (current == null) return;

    final optimistic = _applyOptimisticVote(post, direction);
    state = AsyncData(current.copyWith(
      posts: [
        for (final p in current.posts)
          if (p.id == post.id) optimistic else p
      ],
    ));

    try {
      await ref
          .read(communityRepositoryProvider)
          .voteOnPost(postId: post.id, direction: direction);
    } catch (error, stackTrace) {
      _logger.e(
        'Community vote failed for postId=${post.id}, direction=${direction.name}',
        error: error,
        stackTrace: stackTrace,
      );
      final latest = state.value;
      if (latest != null) {
        state = AsyncData(latest.copyWith(
          posts: [
            for (final p in latest.posts)
              if (p.id == post.id) post else p
          ],
        ));
      }
      rethrow;
    }
  }

  void _logLoadFailure(String operation, Object error, StackTrace stackTrace) {
    if (error is FirebaseException) {
      _logger.e(
        'Community $operation failed with FirebaseException code=${error.code}, message=${error.message}',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _logger.e(
      'Community $operation failed with ${error.runtimeType}: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  CommunityPost _applyOptimisticVote(CommunityPost post, VoteDirection tapped) {
    final current = post.myVote;
    var upvotes = post.upvotes;
    var downvotes = post.downvotes;

    if (current == tapped) {
      // Un-voting.
      if (tapped == VoteDirection.up) {
        upvotes--;
      } else {
        downvotes--;
      }
      return post.copyWith(
          upvotes: upvotes, downvotes: downvotes, clearMyVote: true);
    }

    if (current == VoteDirection.up) upvotes--;
    if (current == VoteDirection.down) downvotes--;
    if (tapped == VoteDirection.up) {
      upvotes++;
    } else {
      downvotes++;
    }
    return post.copyWith(
        upvotes: upvotes, downvotes: downvotes, myVote: tapped);
  }
}
