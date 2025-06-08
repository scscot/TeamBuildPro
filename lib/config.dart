import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get googleApiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';
  // Add others as needed...
}
