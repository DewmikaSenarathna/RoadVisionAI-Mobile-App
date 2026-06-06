import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/prediction_result.dart';

class RoadVisionApiException implements Exception {
  RoadVisionApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RoadVisionApiService {
  static const List<String> _legacyFallbackUrls = [
    'http://10.0.2.2:8000',
    'http://127.0.0.1:8000',
    'http://localhost:8000',
  ];

  RoadVisionApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String baseUrl;

  List<String> get _endpointCandidates {
    final orderedUrls = <String>{baseUrl};
    if (AppConfig.apiBaseUrl.isNotEmpty) {
      orderedUrls.add(AppConfig.apiBaseUrl);
    }
    orderedUrls.addAll(_legacyFallbackUrls);
    return orderedUrls.toList();
  }

  Uri _resolve(String currentBaseUrl, String path) => Uri.parse('$currentBaseUrl$path');

  Future<http.Response> _sendRequest(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    http.Response? lastResponse;

    for (final candidate in _endpointCandidates) {
      try {
        final uri = _resolve(candidate, path);
        final response = method == 'GET'
            ? await _client.get(uri, headers: headers)
            : await _client.post(uri, headers: headers, body: body);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        lastResponse = response;
      } on SocketException {
        continue;
      } on http.ClientException {
        continue;
      } on IOException {
        continue;
      }
    }

    if (lastResponse != null) {
      return lastResponse;
    }

    throw RoadVisionApiException(
      'Unable to reach backend. Tried: ${_endpointCandidates.join(', ')}',
    );
  }

  Future<HealthSnapshot> fetchHealth() async {
    final response = await _sendRequest('GET', '/api/health');
    _ensureSuccess(response, 'Unable to load backend health status');
    return HealthSnapshot.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PredictionResult> predictAuto({
    required double latitude,
    required double longitude,
    required double distanceMi,
    double? speedMph,
    Map<String, bool>? roadFeatures,
  }) {
    return _predict(
      '/api/predict/auto',
      latitude: latitude,
      longitude: longitude,
      distanceMi: distanceMi,
      speedMph: speedMph,
      roadFeatures: roadFeatures,
    );
  }

  Future<PredictionResult> predictSnapshot({
    required double latitude,
    required double longitude,
    required double distanceMi,
    double? speedMph,
    Map<String, bool>? roadFeatures,
  }) {
    return _predict(
      '/api/predict/snapshot',
      latitude: latitude,
      longitude: longitude,
      distanceMi: distanceMi,
      speedMph: speedMph,
      roadFeatures: roadFeatures,
    );
  }

  Future<PredictionResult> _predict(
    String path, {
    required double latitude,
    required double longitude,
    required double distanceMi,
    double? speedMph,
    Map<String, bool>? roadFeatures,
  }) async {
    final response = await _sendRequest(
      'POST',
      path,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'distance_mi': distanceMi,
        'speed_mph': speedMph,
        'road_features': roadFeatures ?? {
          'traffic_signal': false,
          'crosswalk': false,
          'construction_zone': false,
          'school_zone': false,
        },
      }),
    );
    _ensureSuccess(response, 'Prediction request failed');
    return PredictionResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _ensureSuccess(http.Response response, String message) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw RoadVisionApiException('$message (${response.statusCode})');
  }
}