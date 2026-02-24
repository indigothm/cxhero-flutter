import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/survey_config.dart';

/// Handles scheduling and managing local notifications for delayed surveys
class SurveyNotificationScheduler {
  final FlutterLocalNotificationsPlugin _notifications;

  SurveyNotificationScheduler({
    FlutterLocalNotificationsPlugin? notifications,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  /// Initialize the notification plugin
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  /// Check if notification permissions are authorized
  Future<bool> checkPermissions() async {
    final settings = await _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings ?? false;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final result = await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return result ?? false;
  }

  /// Schedule a notification for a survey
  Future<void> schedule({
    required String ruleId,
    required String sessionId,
    required NotificationConfig notificationConfig,
    required int triggerAfterSeconds,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'cxhero_surveys',
      'CXHero Surveys',
      channelDescription: 'Notifications for survey reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: notificationConfig.sound,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: notificationConfig.sound,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final identifier = _notificationIdentifier(ruleId, sessionId);

    // Note: zonedSchedule requires timezone support
    // For simplicity, we'll use a simple delayed notification approach
    // In production, use proper timezone handling

    await _notifications.show(
      identifier.hashCode,
      notificationConfig.title,
      notificationConfig.body,
      details,
      payload: jsonEncode({
        'surveyId': ruleId,
        'sessionId': sessionId,
        'source': 'cxhero',
      }),
    );
  }

  /// Cancel a scheduled notification
  Future<void> cancel(String ruleId, String sessionId) async {
    final identifier = _notificationIdentifier(ruleId, sessionId);
    await _notifications.cancel(identifier.hashCode);
  }

  /// Cancel all pending survey notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Get pending notification identifiers
  Future<List<String>> getPendingIdentifiers() async {
    final pending = await _notifications.pendingNotificationRequests();
    return pending
        .where((p) => p.payload?.contains('"source":"cxhero"') ?? false)
        .map((p) => p.payload!)
        .toList();
  }

  String _notificationIdentifier(String ruleId, String sessionId) {
    return 'cxhero-survey-$ruleId-$sessionId';
  }
}
