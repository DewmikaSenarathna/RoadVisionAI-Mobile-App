import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> fetchWeatherSummary(double latitude, double longitude) async {
    if (AppConfig.weatherApiKey.isEmpty) {
      return 'Weather API key not configured';
    }

    final uri = Uri.parse('${AppConfig.weatherApiBaseUrl}/weather').replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'units': 'metric',
        'appid': AppConfig.weatherApiKey,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return 'Weather unavailable (${response.statusCode})';
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final weatherList = decoded['weather'] as List<dynamic>?;
    final weatherDescription = weatherList != null && weatherList.isNotEmpty
        ? (weatherList.first['description'] ?? '').toString()
        : '';
    final temp = decoded['main']?['temp'];
    final tempValue = temp is num ? temp.toDouble() : double.tryParse(temp?.toString() ?? '');

    final summaryParts = <String>[];
    if (weatherDescription.isNotEmpty) {
      summaryParts.add(weatherDescription);
    }
    if (tempValue != null) {
      summaryParts.add('${tempValue.toStringAsFixed(1)}°C');
    }

    return summaryParts.isNotEmpty ? summaryParts.join(', ') : 'Weather unavailable';
  }
}
