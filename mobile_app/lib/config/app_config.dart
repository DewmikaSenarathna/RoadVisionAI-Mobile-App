import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String appName = 'RoadVisionAI';

  static String get apiBaseUrl => dotenv.env['ROADVISIONAI_API_BASE_URL']?.trim() ?? 'http://10.0.2.2:8000';

  static String get weatherApiBaseUrl => dotenv.env['ROADVISIONAI_WEATHER_API_BASE_URL']?.trim() ?? 'https://api.openweathermap.org/data/2.5';

  static String get weatherApiKey => dotenv.env['ROADVISIONAI_WEATHER_API_KEY']?.trim() ?? '';
}