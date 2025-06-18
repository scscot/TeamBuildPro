import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';

class DownlineService {
  final HttpsCallable _getDownlineCallable =
      FirebaseFunctions.instance.httpsCallable('getDownline');
  final HttpsCallable _getDownlineCountsCallable =
      FirebaseFunctions.instance.httpsCallable('getDownlineCounts');

  Future<List<UserModel>> getDownline(String userId) async {
    try {
      // The Cloud Function uses the authenticated user's context to get the UID,
      // so we don't need to pass a parameter here.
      final result = await _getDownlineCallable.call();
      final List<dynamic> usersData = result.data['downline'];
      return usersData.map((data) => UserModel.fromMap(data)).toList();
    } catch (e) {
      debugPrint('Error getting downline: $e');
      return [];
    }
  }

  Future<Map<String, int>> getDownlineCounts(String userId) async {
    try {
      // The Cloud Function uses the authenticated user's context to get the UID.
      final result = await _getDownlineCountsCallable.call();
      return Map<String, int>.from(result.data['counts']);
    } catch (e) {
      debugPrint('Error getting downline counts: $e');
      return {};
    }
  }
}
