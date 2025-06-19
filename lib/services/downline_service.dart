// lib/services/downline_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class DownlineService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<List<UserModel>> getDownline() async {
    try {
      final callable = _functions.httpsCallable('getDownline');
      final result = await callable.call();

      // Safely cast the list data
      final List<dynamic> downlineData = result.data['downline'] ?? [];

      // MODIFIED: Safely map each item in the list using Map.from()
      return downlineData.map((data) {
        final Map<String, dynamic> userMap = Map<String, dynamic>.from(data);
        return UserModel.fromMap(userMap);
      }).toList();
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          'Error calling getDownline function: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint(
          'An unexpected error occurred in DownlineService.getDownline: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> getDownlineCounts() async {
    try {
      final callable = _functions.httpsCallable('getDownlineCounts');
      final result = await callable.call();

      // MODIFIED: Safely cast the map data using Map.from()
      if (result.data != null && result.data['counts'] != null) {
        final Map<String, dynamic> countsData =
            Map<String, dynamic>.from(result.data['counts']);
        return countsData
            .map((key, value) => MapEntry(key, (value as num).toInt()));
      }
      return {};
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          'Error calling getDownlineCounts function: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint(
          'An unexpected error occurred in DownlineService.getDownlineCounts: $e');
      rethrow;
    }
  }
}
