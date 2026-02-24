import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/survey_config.dart';

/// Manages survey configuration with support for remote updates
class SurveyConfigManager {
  SurveyConfig _currentConfig;
  Timer? _timer;
  int? _lastDataHash;

  final _configController = StreamController<SurveyConfig>.broadcast();

  /// Current configuration
  SurveyConfig get currentConfig => _currentConfig;

  /// Stream of configuration updates
  Stream<SurveyConfig> get configStream => _configController.stream;

  SurveyConfigManager({required SurveyConfig initial}) : _currentConfig = initial;

  /// Load configuration from a remote URL
  Future<void> loadRemote(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to load config: ${response.statusCode}');
      }

      final hash = response.body.hashCode;
      if (_lastDataHash == hash) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final config = SurveyConfig.fromJson(json);

      _currentConfig = config;
      _lastDataHash = hash;
      _configController.add(config);
    } catch (e) {
      // Log error but don't throw - keep existing config
    }
  }

  /// Start auto-refreshing configuration from a remote URL
  void startAutoRefresh(String url, {required Duration interval}) {
    _timer?.cancel();
    // Load immediately
    loadRemote(url);
    // Then schedule periodic updates
    _timer = Timer.periodic(interval, (_) => loadRemote(url));
  }

  /// Stop auto-refreshing
  void stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose resources
  void dispose() {
    stopAutoRefresh();
    _configController.close();
  }
}
