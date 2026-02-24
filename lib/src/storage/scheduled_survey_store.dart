import 'dart:convert';
import 'dart:io';

/// Stores scheduled surveys for delayed display
class ScheduledSurveyStore {
  final Directory _baseDirectory;

  ScheduledSurveyStore({required Directory baseDirectory})
      : _baseDirectory = baseDirectory;

  /// Schedule a survey to be shown later
  Future<void> scheduleForLater({
    required String ruleId,
    String? userId,
    required String sessionId,
    required int delaySeconds,
  }) async {
    final path = _scheduledFile(userId);
    try {
      if (!await path.parent.exists()) {
        await path.parent.create(recursive: true);
      }

      ScheduledSurveys surveys;
      if (await path.exists()) {
        final data = await path.readAsString();
        surveys = ScheduledSurveys.fromJson(jsonDecode(data));
      } else {
        surveys = ScheduledSurveys();
      }

      // Remove any existing scheduled survey with same rule ID for this session
      surveys.scheduled.removeWhere(
        (s) => s.id == ruleId && s.sessionId == sessionId,
      );

      final scheduled = ScheduledSurvey(
        id: ruleId,
        userId: userId,
        sessionId: sessionId,
        scheduledAt: DateTime.now(),
        triggerAt: DateTime.now().add(Duration(seconds: delaySeconds)),
      );
      surveys.scheduled.add(scheduled);

      await path.writeAsString(jsonEncode(surveys.toJson()));
    } catch (e) {
      // Silently ignore errors
    }
  }

  /// Get pending surveys for a session that haven't triggered yet
  Future<List<ScheduledSurvey>> getPendingSurveys({
    String? userId,
    required String sessionId,
  }) async {
    final path = _scheduledFile(userId);
    if (!await path.exists()) return [];

    try {
      final data = await path.readAsString();
      final surveys = ScheduledSurveys.fromJson(jsonDecode(data));
      return surveys.scheduled
          .where((s) => s.sessionId == sessionId && !s.isExpired)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get triggered surveys for a session
  Future<List<ScheduledSurvey>> getTriggeredSurveys({
    String? userId,
    required String sessionId,
  }) async {
    final path = _scheduledFile(userId);
    if (!await path.exists()) return [];

    try {
      final data = await path.readAsString();
      final surveys = ScheduledSurveys.fromJson(jsonDecode(data));
      return surveys.scheduled
          .where((s) => s.sessionId == sessionId && s.isExpired)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all triggered surveys for a user (regardless of session)
  Future<List<ScheduledSurvey>> getAllTriggeredSurveys(String? userId) async {
    final path = _scheduledFile(userId);
    if (!await path.exists()) return [];

    try {
      final data = await path.readAsString();
      final surveys = ScheduledSurveys.fromJson(jsonDecode(data));
      return surveys.scheduled.where((s) => s.isExpired).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all pending surveys for a user (regardless of session)
  Future<List<ScheduledSurvey>> getAllPendingSurveys(String? userId) async {
    final path = _scheduledFile(userId);
    if (!await path.exists()) return [];

    try {
      final data = await path.readAsString();
      final surveys = ScheduledSurveys.fromJson(jsonDecode(data));
      return surveys.scheduled.where((s) => !s.isExpired).toList();
    } catch (e) {
      return [];
    }
  }

  /// Remove a scheduled survey
  Future<void> removeScheduled({
    required String ruleId,
    required String sessionId,
    String? userId,
  }) async {
    final path = _scheduledFile(userId);
    if (!await path.exists()) return;

    try {
      final data = await path.readAsString();
      final surveys = ScheduledSurveys.fromJson(jsonDecode(data));

      surveys.scheduled.removeWhere(
        (s) => s.id == ruleId && s.sessionId == sessionId,
      );

      await path.writeAsString(jsonEncode(surveys.toJson()));
    } catch (e) {
      // Silently ignore errors
    }
  }

  /// Clean up old scheduled surveys
  Future<void> cleanupOldScheduled({Duration olderThan = const Duration(hours: 24)}) async {
    final usersDir = Directory('${_baseDirectory.path}/users');
    if (!await usersDir.exists()) return;

    final cutoff = DateTime.now().subtract(olderThan);

    await for (final userDir in usersDir.list()) {
      if (userDir is! Directory) continue;
      final path = File('${userDir.path}/surveys/scheduled.json');
      if (!await path.exists()) continue;

      try {
        final data = await path.readAsString();
        final surveys = ScheduledSurveys.fromJson(jsonDecode(data));

        surveys.scheduled.removeWhere((s) => s.scheduledAt.isBefore(cutoff));

        await path.writeAsString(jsonEncode(surveys.toJson()));
      } catch (e) {
        // Continue to next
      }
    }
  }

  File _scheduledFile(String? userId) {
    final userFolder = _safeUserFolder(userId);
    return File(
      '${_baseDirectory.path}/users/$userFolder/surveys/scheduled.json',
    );
  }

  String _safeUserFolder(String? userId) {
    if (userId == null || userId.isEmpty) return 'anon';
    final allowed = RegExp(r'[^a-zA-Z0-9\-_@.]');
    return userId.replaceAll(allowed, '_');
  }
}

/// Collection of scheduled surveys
class ScheduledSurveys {
  final List<ScheduledSurvey> scheduled;

  ScheduledSurveys({List<ScheduledSurvey>? scheduled})
      : scheduled = scheduled ?? [];

  factory ScheduledSurveys.fromJson(Map<String, dynamic> json) {
    final scheduled = (json['scheduled'] as List<dynamic>?)
        ?.map((e) => ScheduledSurvey.fromJson(e as Map<String, dynamic>))
        .toList();
    return ScheduledSurveys(scheduled: scheduled);
  }

  Map<String, dynamic> toJson() {
    return {
      'scheduled': scheduled.map((e) => e.toJson()).toList(),
    };
  }
}

/// Individual scheduled survey
class ScheduledSurvey {
  final String id; // ruleId
  final String? userId;
  final String sessionId;
  final DateTime scheduledAt;
  final DateTime triggerAt;

  ScheduledSurvey({
    required this.id,
    this.userId,
    required this.sessionId,
    required this.scheduledAt,
    required this.triggerAt,
  });

  factory ScheduledSurvey.fromJson(Map<String, dynamic> json) {
    return ScheduledSurvey(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      sessionId: json['sessionId'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      triggerAt: DateTime.parse(json['triggerAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'sessionId': sessionId,
      'scheduledAt': scheduledAt.toIso8601String(),
      'triggerAt': triggerAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(triggerAt);

  Duration get remainingDelay {
    final remaining = triggerAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
