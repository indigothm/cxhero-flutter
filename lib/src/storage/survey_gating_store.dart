import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key prefix for survey gating
const _kGatingPrefix = 'cxhero_gating_';

/// Manages survey gating state (shown/completed status per user) via SharedPreferences.
class SurveyGatingStore {
  SurveyGatingStore();

  String _key(String? userId) {
    final folder = _safeUserFolder(userId);
    return '${_kGatingPrefix}$folder';
  }

  /// Check if a survey can be shown based on gating rules
  Future<bool> canShow({
    required String ruleId,
    String? userId,
    bool? oncePerUser,
    int? cooldownSeconds,
    int? maxAttempts,
    int? attemptCooldownSeconds,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key(userId));
      if (data == null) return true;

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(userId);
      final data = prefs.getString(key);
      final gating = data != null
          ? GatingRecord.fromJson(jsonDecode(data))
          : GatingRecord();

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

      await prefs.setString(key, jsonEncode(gating.toJson()));
    } catch (e) {
      // Ignore errors
    }
  }

  /// Mark a survey as completed
  Future<void> markCompleted(String ruleId, String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(userId);
      final data = prefs.getString(key);
      final gating = data != null
          ? GatingRecord.fromJson(jsonDecode(data))
          : GatingRecord();

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

      await prefs.setString(key, jsonEncode(gating.toJson()));
    } catch (e) {
      // Ignore errors
    }
  }

  String _safeUserFolder(String? userId) {
    if (userId == null || userId.isEmpty) return 'anon';
    // Restrict to safe characters
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
