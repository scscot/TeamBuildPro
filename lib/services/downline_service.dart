import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import '../models/user_model.dart';

class DownlineService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<List<UserModel>> getDownline() async {
    try {
      final callable = _functions.httpsCallable('getDownline');
      final result = await callable.call();
      final List<dynamic> downlineData = result.data['downline'];
      return downlineData
          .map((data) => UserModel.fromMap(data as Map<String, dynamic>))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      // MODIFIED: Replaced print with debugPrint
      debugPrint(
          'Error calling getDownline function: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      // MODIFIED: Replaced print with debugPrint
      debugPrint(
          'An unexpected error occurred in DownlineService.getDownline: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> getDownlineCounts() async {
    try {
      final callable = _functions.httpsCallable('getDownlineCounts');
      final result = await callable.call();
      final Map<String, dynamic> countsData = result.data['counts'];
      return countsData
          .map((key, value) => MapEntry(key, (value as num).toInt()));
    } on FirebaseFunctionsException catch (e) {
      // MODIFIED: Replaced print with debugPrint
      debugPrint(
          'Error calling getDownlineCounts function: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      // MODIFIED: Replaced print with debugPrint
      debugPrint(
          'An unexpected error occurred in DownlineService.getDownlineCounts: $e');
      rethrow;
    }
  }
}
