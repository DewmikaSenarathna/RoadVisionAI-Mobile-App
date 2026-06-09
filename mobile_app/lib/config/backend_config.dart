import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class BackendConfig {
  static const String _backendUrlKey = 'roadvisionai_backend_url';
  static const Set<String> _legacyFallbackUrls = {
    'http://10.0.2.2:8000',
    'http://127.0.0.1:8000',
    'http://localhost:8000',
  };

  static Future<String> loadBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_backendUrlKey);
    if (savedUrl == null) {
      return AppConfig.apiBaseUrl;
    }

    if (_legacyFallbackUrls.contains(savedUrl) && !(_legacyFallbackUrls.contains(AppConfig.apiBaseUrl))) {
      return AppConfig.apiBaseUrl;
    }

    return savedUrl;
  }

  static Future<void> saveBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, url.trim());
  }
}
