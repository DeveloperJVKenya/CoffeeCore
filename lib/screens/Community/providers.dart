import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:coffeecore/screens/Community/repository_impl.dart';
import 'package:coffeecore/screens/Community/repository.dart';

part 'providers.g.dart';

// NOTE ON RIVERPOD VERSION: this targets riverpod_generator ^2.6 style,
// where generated providers take a generic `Ref`. If your installed
// riverpod_generator is older (2.3–2.5), build_runner will instead expect a
// typed ref like `CommunityRepositoryRef` — swap the parameter type below if
// so; check `flutter pub outdated` if codegen complains.

@riverpod
CommunityRepository communityRepository(Ref ref) {
  return CommunityRepositoryImpl(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
}

/// The signed-in user's uid, or null. Widgets use this to decide whether to
/// show the "Accept Solution" button (only the post author sees it) and
/// whether voting/commenting controls are enabled at all.
@riverpod
String? currentUserId(Ref ref) {
  return FirebaseAuth.instance.currentUser?.uid;
}
