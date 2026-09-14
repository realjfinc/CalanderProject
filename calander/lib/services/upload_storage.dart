import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads a picked file to Cloud Storage so a confirmed event's
/// `attachments` field can reference it, and returns its download URL.
abstract class UploadStorage {
  Future<String> upload({required Uint8List bytes, required String fileName, String? contentType});

  /// Deletes a previously-uploaded file by the download URL [upload]
  /// returned for it -- used when the event that referenced it is deleted,
  /// so a removed event doesn't leave its attachment behind in storage
  /// indefinitely. Must be a no-op (not an error) when the object is
  /// already gone, since callers use this for best-effort cleanup.
  Future<void> deleteByUrl(String url);
}

/// Production [UploadStorage] backed by Firebase Storage, storing under
/// `users/{uid}/uploads/`.
class FirebaseUploadStorage implements UploadStorage {
  factory FirebaseUploadStorage({required String uid, FirebaseStorage? storage}) {
    return FirebaseUploadStorage._(uid, storage ?? FirebaseStorage.instance);
  }

  FirebaseUploadStorage._(this._uid, this._storage);

  final String _uid;
  final FirebaseStorage _storage;

  @override
  Future<String> upload({required Uint8List bytes, required String fileName, String? contentType}) async {
    final safeName = _uniqueFileName(fileName);
    final ref = _storage.ref('users/$_uid/uploads/$safeName');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  @override
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } on FirebaseException catch (error) {
      // object-not-found means it's already gone -- exactly the end state
      // this call wants, so that's success, not failure. Any other error
      // (a transient network/permission issue) is a real failure and
      // rethrown; callers that want best-effort cleanup (deleting an
      // event must never block on this) are responsible for catching it.
      if (error.code != 'object-not-found') rethrow;
    }
  }

  String _uniqueFileName(String originalName) {
    final suffix = Random().nextInt(1 << 32).toRadixString(16);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final dotIndex = originalName.lastIndexOf('.');
    final ext = dotIndex >= 0 ? originalName.substring(dotIndex) : '';
    return '$timestamp-$suffix$ext';
  }
}
