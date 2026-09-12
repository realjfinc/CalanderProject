import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads a picked file to Cloud Storage so a confirmed event's
/// `attachments` field can reference it, and returns its download URL.
abstract class UploadStorage {
  Future<String> upload({required Uint8List bytes, required String fileName, String? contentType});
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

  String _uniqueFileName(String originalName) {
    final suffix = Random().nextInt(1 << 32).toRadixString(16);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final dotIndex = originalName.lastIndexOf('.');
    final ext = dotIndex >= 0 ? originalName.substring(dotIndex) : '';
    return '$timestamp-$suffix$ext';
  }
}
