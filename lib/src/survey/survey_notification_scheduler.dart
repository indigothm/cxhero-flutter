import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/survey_config.dart';

/// Handles scheduling and managing local notifications for delayed surveys.
/// On web, all notification operations are no-ops.
class SurveyNotificationScheduler {
  SurveyNotificationScheduler();

  /// Initialize the notification plugin (no-op on web)
  Future<void> initialize() async {
    if (kIsWeb) return;
    await _initNative();
  }

  Future<void> _initNative() async {
    // Native notification initialization is done lazily via the platform plugin.
    // flutter_local_notifications is not a dependency of this library.
    // Consumers who want local notifications should handle initialization themselves.
  }

  /// Check if notification permissions are authorized
  Future<bool> checkPermissions() async {
    if (kIsWeb) return false;
    return false;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    return false;
  }

  /// Schedule a notification for a survey (no-op on web)
  Future<void> schedule({
    required String ruleId,
    required String sessionId,
    required NotificationConfig notificationConfig,
    required int triggerAfterSeconds,
  }) async {
    if (kIsWeb) return;
    // Native notification scheduling is handled by the app layer.
    // This store manages the in-memory timer for delayed surveys.
  }

  /// Cancel a scheduled notification (no-op on web)
  Future<void> cancel(String ruleId, String sessionId) async {}

  /// Cancel all pending survey notifications (no-op on web)
  Future<void> cancelAll() async {}

  /// Get pending notification identifiers
  Future<List<String>> getPendingIdentifiers() async => [];

  String _notificationIdentifier(String ruleId, String sessionId) {
    return 'cxhero-survey-$ruleId-$sessionId';
  }
}
