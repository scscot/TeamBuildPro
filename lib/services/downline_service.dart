// lib/services/downline_service.dart

import 'package:flutter/foundation.dart'; // ADDED for debugPrint
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';

class DownlineService {
  final HttpsCallable _getDownlineCallable =
      FirebaseFunctions.instance.httpsCallable('getDownline');
  final HttpsCallable _getDownlineCountsCallable =
      FirebaseFunctions.instance.httpsCallable('getDownlineCounts');

  Future<List<UserModel>> getDownline(String userId) async {
    try {
      // The userId parameter is kept for potential future use but is not
      // currently passed to the function, which uses auth context instead.
      final result = await _getDownlineCallable.call();
      final List<dynamic> usersData = result.data['downline'];
      return usersData.map((data) => UserModel.fromMap(data)).toList();
    } catch (e) {
      // MODIFIED: Switched to debugPrint for better logging.
      debugPrint('Error getting downline: $e');
      return [];
    }
  }

  Future<Map<String, int>> getDownlineCounts(String userId) async {
    try {
      // The userId parameter is kept for potential future use but is not
      // currently passed to the function, which uses auth context instead.
      final result = await _getDownlineCountsCallable.call();
      return Map<String, int>.from(result.data['counts']);
    } catch (e) {
      // MODIFIED: Switched to debugPrint for better logging.
      debugPrint('Error getting downline counts: $e');
      return {};
    }
  }
}
