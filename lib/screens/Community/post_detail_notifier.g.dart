// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_detail_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PostDetailNotifier)
final postDetailProvider = PostDetailNotifierFamily._();

final class PostDetailNotifierProvider
    extends $AsyncNotifierProvider<PostDetailNotifier, PostDetailState> {
  PostDetailNotifierProvider._(
      {required PostDetailNotifierFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'postDetailProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$postDetailNotifierHash();

  @override
  String toString() {
    return r'postDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PostDetailNotifier create() => PostDetailNotifier();

  @override
  bool operator ==(Object other) {
    return other is PostDetailNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$postDetailNotifierHash() =>
    r'20ab5ce47d4100be078fc2550dd11beb6a819d3f';

final class PostDetailNotifierFamily extends $Family
    with
        $ClassFamilyOverride<PostDetailNotifier, AsyncValue<PostDetailState>,
            PostDetailState, FutureOr<PostDetailState>, String> {
  PostDetailNotifierFamily._()
      : super(
          retry: null,
          name: r'postDetailProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  PostDetailNotifierProvider call(
    String postId,
  ) =>
      PostDetailNotifierProvider._(argument: postId, from: this);

  @override
  String toString() => r'postDetailProvider';
}

abstract class _$PostDetailNotifier extends $AsyncNotifier<PostDetailState> {
  late final _$args = ref.$arg as String;
  String get postId => _$args;

  FutureOr<PostDetailState> build(
    String postId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PostDetailState>, PostDetailState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<PostDetailState>, PostDetailState>,
        AsyncValue<PostDetailState>,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
