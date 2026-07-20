import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Uploads post photos to Firebase Storage under
/// `community_posts/{postId}/{uuid}.jpg`. Kept separate from
/// [CommunityRepository] so the Firestore-facing repository stays free of a
/// Storage/image_picker dependency — this service only ever returns the
/// resulting download URLs, which the repository then stores as plain
/// strings on the post document.
class CommunityStorageService {
  CommunityStorageService([FirebaseStorage? storage])
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  /// Max photos a single post may carry — keeps the create-post flow quick
  /// on the patchy rural connections this app targets.
  static const maxImagesPerPost = 3;

  Future<List<String>> uploadPostImages({
    required String postId,
    required List<XFile> images,
  }) async {
    final urls = <String>[];
    for (final image in images) {
      final ref = _storage
          .ref('community_posts')
          .child(postId)
          .child('${_uuid.v4()}.jpg');
      await ref.putFile(File(image.path));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }
}
