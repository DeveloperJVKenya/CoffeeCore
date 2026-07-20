// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CommunityFeedNotifier)
final communityFeedProvider = CommunityFeedNotifierProvider._();

final class CommunityFeedNotifierProvider
    extends $AsyncNotifierProvider<CommunityFeedNotifier, CommunityFeedState> {
  CommunityFeedNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'communityFeedProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$communityFeedNotifierHash();

  @$internal
  @override
  CommunityFeedNotifier create() => CommunityFeedNotifier();
}

String _$communityFeedNotifierHash() =>
    r'c0fe7d6442f097a1e85a9a69ba17b6e5e68a9d23';

abstract class _$CommunityFeedNotifier
    extends $AsyncNotifier<CommunityFeedState> {
  FutureOr<CommunityFeedState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<CommunityFeedState>, CommunityFeedState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<CommunityFeedState>, CommunityFeedState>,
        AsyncValue<CommunityFeedState>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}
