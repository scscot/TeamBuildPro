// lib/services/storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final fileExtension = p.extension(imageFile.path);
      final ref = _storage.ref('profile_images/$userId$fileExtension');

      UploadTask uploadTask = ref.putFile(imageFile);

      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint("StorageService: Upload successful, URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("StorageService: Error uploading profile image: $e");
      return null;
    }
  }
}
