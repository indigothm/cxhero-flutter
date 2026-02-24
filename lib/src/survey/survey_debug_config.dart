import '../models/survey_config.dart';

/// Configuration for debug/testing mode behavior of surveys
class SurveyDebugConfig {
  /// Enable debug mode (bypasses gating, modifies delays)
  final bool enabled;

  /// Override all survey scheduleAfterSeconds delays
  final int? overrideScheduleDelay;

  /// Override all attemptCooldownSeconds
  final int? overrideAttemptCooldown;

  /// Bypass all gating checks (oncePerUser, cooldowns, maxAttempts)
  final bool bypassGating;

  const SurveyDebugConfig({
    required this.enabled,
    this.overrideScheduleDelay,
    this.overrideAttemptCooldown,
    this.bypassGating = false,
  });

  /// Production configuration - all debug features disabled
  static const production = SurveyDebugConfig(
    enabled: false,
    overrideScheduleDelay: null,
    overrideAttemptCooldown: null,
    bypassGating: false,
  );

  /// Debug configuration - fast delays, bypassed gating
  static const debug = SurveyDebugConfig(
    enabled: true,
    overrideScheduleDelay: 60, // 60 seconds instead of production timing
    overrideAttemptCooldown: 15, // 15 seconds instead of 24 hours
    bypassGating: true, // Show every time, ignore completion/attempts
  );

  /// Apply debug overrides to a survey config
  SurveyConfig applyTo(SurveyConfig config) {
    if (!enabled) return config;

    final modifiedSurveys = config.surveys.map((survey) {
      var modifiedSurvey = survey;
      var needsRebuild = false;
      var modifiedTrigger = survey.trigger;
      int? modifiedAttemptCooldown = survey.attemptCooldownSeconds;

      // Override trigger delays if specified
      if (survey.trigger is TriggerConditionEvent) {
        final eventTrigger = (survey.trigger as TriggerConditionEvent).trigger;
        if (overrideScheduleDelay != null) {
          modifiedTrigger = TriggerCondition.event(
            eventTrigger.copyWith(scheduleAfterSeconds: overrideScheduleDelay),
          );
          needsRebuild = true;
        }
      }

      // Override attempt cooldown if specified
      if (overrideAttemptCooldown != null) {
        modifiedAttemptCooldown = overrideAttemptCooldown;
        needsRebuild = true;
      }

      // Rebuild survey rule if any overrides were applied
      if (needsRebuild) {
        modifiedSurvey = survey.copyWith(
          trigger: modifiedTrigger,
          attemptCooldownSeconds: modifiedAttemptCooldown,
        );
      }

      return modifiedSurvey;
    }).toList();

    return SurveyConfig(surveys: modifiedSurveys);
  }
}
