import 'dart:convert';
import 'dart:io';

/// Manages survey gating state (shown/completed status per user)
class SurveyGatingStore {
  final Directory _baseDirectory;

  SurveyGatingStore({required Directory baseDirectory})
      : _baseDirectory = baseDirectory;

  /// Check if a survey can be shown based on gating rules
  Future<bool> canShow({
    required String ruleId,
    String? userId,
    bool? oncePerUser,
    int? cooldownSeconds,
    int? maxAttempts,
    int? attemptCooldownSeconds,
  }) async {
    final path = _gatingFile(userId);
    if (!await path.exists()) return true;

    try {
      final data = await path.readAsString();
      final gating = GatingRecord.fromJson(jsonDecode(data));
      final rec = gating.rules[ruleId];

      if (rec != null) {
        // If survey was completed, don't show again
        if (rec.completedOnce) return false;

        // Check if max attempts reached
        if (maxAttempts != null && rec.attemptCount >= maxAttempts) {
          return false;
        }

        // Check oncePerUser (blocks after first attempt, not completion)
        if (oncePerUser ?? false) return false;

        // Check cooldown - use attemptCooldownSeconds if available
        final cooldown = attemptCooldownSeconds ?? cooldownSeconds;
        if (cooldown != null) {
          final nextShow = rec.lastShownAt.add(Duration(seconds: cooldown));
          if (DateTime.now().isBefore(nextShow)) return false;
        }
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  /// Mark a survey as shown
  Future<void> markShown(String ruleId, String? userId) async {
    final path = _gatingFile(userId);
    try {
      if (!await path.parent.exists()) {
        await path.parent.create(recursive: true);
      }

      GatingRecord gating;
      if (await path.exists()) {
        final data = await path.readAsString();
        gating = GatingRecord.fromJson(jsonDecode(data));
      } else {
        gating = GatingRecord();
      }

      final existing = gating.rules[ruleId];
      if (existing != null) {
        gating.rules[ruleId] = GatingRuleRecord(
          lastShownAt: DateTime.now(),
          shownOnce: true,
          attemptCount: existing.attemptCount + 1,
          completedOnce: existing.completedOnce,
        );
      } else {
        gating.rules[ruleId] = GatingRuleRecord(
          lastShownAt: DateTime.now(),
          shownOnce: true,
          attemptCount: 1,
          completedOnce: false,
        );
      }

      await path.writeAsString(jsonEncode(gating.toJson()));
    } catch (e) {
      // Ignore errors
    }
  }

  /// Mark a survey as completed
  Future<void> markCompleted(String ruleId, String? userId) async {
    final path = _gatingFile(userId);
    try {
      if (!await path.parent.exists()) {
        await path.parent.create(recursive: true);
      }

      GatingRecord gating;
      if (await path.exists()) {
        final data = await path.readAsString();
        gating = GatingRecord.fromJson(jsonDecode(data));
      } else {
        gating = GatingRecord();
      }

      final existing = gating.rules[ruleId];
      if (existing != null) {
        gating.rules[ruleId] = GatingRuleRecord(
          lastShownAt: existing.lastShownAt,
          shownOnce: existing.shownOnce,
          attemptCount: existing.attemptCount,
          completedOnce: true,
        );
      } else {
        gating.rules[ruleId] = GatingRuleRecord(
          lastShownAt: DateTime.now(),
          shownOnce: true,
          attemptCount: 1,
          completedOnce: true,
        );
      }

      await path.writeAsString(jsonEncode(gating.toJson()));
    } catch (e) {
      // Ignore errors
    }
  }

  File _gatingFile(String? userId) {
    final userFolder = _safeUserFolder(userId);
    return File(
      '${_baseDirectory.path}/users/$userFolder/surveys/gating.json',
    );
  }

  String _safeUserFolder(String? userId) {
    if (userId == null || userId.isEmpty) return 'anon';
    // Restrict to safe filesystem characters
    final allowed = RegExp(r'[^a-zA-Z0-9\-_@.]');
    return userId.replaceAll(allowed, '_');
  }
}

/// Gating record for all rules
class GatingRecord {
  final Map<String, GatingRuleRecord> rules;

  GatingRecord({Map<String, GatingRuleRecord>? rules})
      : rules = rules ?? {};

  factory GatingRecord.fromJson(Map<String, dynamic> json) {
    final rules = (json['rules'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, GatingRuleRecord.fromJson(v as Map<String, dynamic>)),
    );
    return GatingRecord(rules: rules);
  }

  Map<String, dynamic> toJson() {
    return {
      'rules': rules.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}

/// Individual rule gating record
class GatingRuleRecord {
  final DateTime lastShownAt;
  final bool shownOnce;
  final int attemptCount;
  final bool completedOnce;

  GatingRuleRecord({
    required this.lastShownAt,
    this.shownOnce = false,
    this.attemptCount = 0,
    this.completedOnce = false,
  });

  factory GatingRuleRecord.fromJson(Map<String, dynamic> json) {
    return GatingRuleRecord(
      lastShownAt: DateTime.parse(json['lastShownAt'] as String),
      shownOnce: json['shownOnce'] as bool? ?? false,
      attemptCount: json['attemptCount'] as int? ?? 0,
      completedOnce: json['completedOnce'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastShownAt': lastShownAt.toIso8601String(),
      'shownOnce': shownOnce,
      'attemptCount': attemptCount,
      'completedOnce': completedOnce,
    };
  }
}
