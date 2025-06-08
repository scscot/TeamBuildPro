import 'package:flutter/foundation.dart';

class AnalyticsService {
  void logEvent(String name, Map<String, dynamic> params) {
    // Placeholder: integrate with real analytics later
    debugPrint('Analytics event: $name, data: $params');
  }
}
