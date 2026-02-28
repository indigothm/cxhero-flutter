import 'dart:async';

import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/event_value.dart';
import '../models/survey_config.dart';
import '../storage/event_recorder.dart';
import '../storage/scheduled_survey_store.dart';
import '../storage/survey_gating_store.dart';
import 'survey_config_manager.dart';
import 'survey_debug_config.dart';
import 'survey_sheet.dart';

/// Widget that handles survey triggering based on events
class SurveyTrigger extends StatefulWidget {
  final SurveyConfig config;
  final SurveyConfigManager? configManager;
  final EventRecorder? recorder;
  final SurveyDebugConfig debugConfig;
  final bool notificationsEnabled;
  final Widget child;

  const SurveyTrigger({
    super.key,
    required this.config,
    this.configManager,
    this.recorder,
    this.debugConfig = SurveyDebugConfig.production,
    this.notificationsEnabled = false,
    required this.child,
  });

  @override
  State<SurveyTrigger> createState() => _SurveyTriggerState();
}

class _SurveyTriggerState extends State<SurveyTrigger>
    with WidgetsBindingObserver {
  late SurveyConfig _config;
  late final EventRecorder _recorder;
  late final SurveyGatingStore _gating;
  late final ScheduledSurveyStore _scheduledStore;

  final _shownThisSession = <String>{};
  String? _lastSessionId;
  SurveyRule? _activeRule;
  final _scheduledTimers = <String, Timer>{};

  StreamSubscription<Event>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _config = widget.debugConfig.applyTo(widget.config);
    _recorder = widget.recorder ?? EventRecorder.instance;
    _gating = SurveyGatingStore();
    _scheduledStore = ScheduledSurveyStore();

    // Subscribe to events
    _eventSubscription = _recorder.eventsStream.listen(_handleEvent);

    // Subscribe to config updates if manager is provided
    widget.configManager?.configStream.listen((config) {
      setState(() {
        _config = widget.debugConfig.applyTo(config);
      });
    });

    WidgetsBinding.instance.addObserver(this);

    // Restore pending surveys on init
    _restorePendingSurveys();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restorePendingSurveys();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    _scheduledTimers.clear();
    super.dispose();
  }

  void _handleEvent(Event event) {
    // Reset shown rules for new session
    if (_lastSessionId != event.sessionId) {
      _shownThisSession.clear();
      // Cancel timers from previous session
      for (final timer in _scheduledTimers.values) {
        timer.cancel();
      }
      _scheduledTimers.clear();
      _lastSessionId = event.sessionId;
    }

    _processEvent(event);
  }

  Future<void> _processEvent(Event event) async {
    for (final rule in _config.surveys) {
      // In debug mode with gating bypass, skip all gating checks
      if (!widget.debugConfig.bypassGating) {
        if (rule.oncePerSession ?? true) {
          if (_shownThisSession.contains(rule.id)) continue;
        }
      }

      if (!_matchesTrigger(rule.trigger, event)) continue;

      // In debug mode with gating bypass, skip gating checks
      if (!widget.debugConfig.bypassGating) {
        final allow = await _gating.canShow(
          ruleId: rule.id,
          userId: event.userId,
          oncePerUser: rule.oncePerUser,
          cooldownSeconds: rule.cooldownSeconds,
          maxAttempts: rule.maxAttempts,
          attemptCooldownSeconds: rule.attemptCooldownSeconds,
        );
        if (!allow) continue;
      }

      // Check if trigger has a delay
      if (rule.trigger is TriggerConditionEvent) {
        final trigger = (rule.trigger as TriggerConditionEvent).trigger;
        if (trigger.scheduleAfterSeconds != null &&
            trigger.scheduleAfterSeconds! > 0) {
          _scheduleDelayedSurvey(
            rule: rule,
            userId: event.userId,
            delaySeconds: trigger.scheduleAfterSeconds!,
          );
        } else {
          _showSurvey(rule: rule, userId: event.userId);
        }
      }
      break; // Only show first matching rule
    }
  }

  bool _matchesTrigger(TriggerCondition trigger, Event event) {
    switch (trigger) {
      case TriggerConditionEvent(:final trigger):
        if (trigger.name != event.name) return false;
        final props = trigger.properties;
        if (props == null) return true;

        final evProps = event.properties ?? {};
        for (final entry in props.entries) {
          final key = entry.key;
          final matcher = entry.value;

          if (matcher is PropertyMatcherExists) {
            final exists = evProps.containsKey(key);
            if (matcher.exists != exists) return false;
          } else {
            final value = evProps[key];
            if (value == null) return false;
            if (!matcher.matches(value)) return false;
          }
        }
        return true;
    }
  }

  Future<void> _scheduleDelayedSurvey({
    required SurveyRule rule,
    String? userId,
    required int delaySeconds,
  }) async {
    // Cancel any existing timer for this rule
    _scheduledTimers[rule.id]?.cancel();

    final session = _recorder.currentSession;
    if (session == null) return;
    final sessionId = session.id;

    // Deduplicate: check if already pending
    final alreadyPending = await _scheduledStore.getPendingSurveys(
      userId: userId,
      sessionId: sessionId,
    );
    if (alreadyPending.any((s) => s.id == rule.id)) {
      return;
    }

    await _scheduledStore.scheduleForLater(
      ruleId: rule.id,
      userId: userId,
      sessionId: sessionId,
      delaySeconds: delaySeconds,
    );

    final timer = Timer(Duration(seconds: delaySeconds), () async {
      _showSurvey(rule: rule, userId: userId);
      await _scheduledStore.removeScheduled(
        ruleId: rule.id,
        sessionId: sessionId,
        userId: userId,
      );
      _scheduledTimers.remove(rule.id);
    });

    _scheduledTimers[rule.id] = timer;
  }

  void _showSurvey({required SurveyRule rule, String? userId}) {
    if (!mounted) return;

    setState(() {
      _activeRule = rule;
    });

    // Mark as shown
    if (!widget.debugConfig.bypassGating) {
      if (rule.oncePerSession ?? true) {
        _shownThisSession.add(rule.id);
      }
      _gating.markShown(rule.id, userId);
    }

    // Record survey presented event
    _recorder.record('survey_presented', properties: {
      'id': EventValue.string(rule.id),
      'responseType': EventValue.string(rule.response.analyticsType),
      'debugMode': EventValue.bool(widget.debugConfig.enabled),
    });

    _showSurveySheet(rule, userId);
  }

  void _showSurveySheet(SurveyRule rule, String? userId) {
    // Use root navigator to ensure sheets work regardless of where SurveyTrigger
    // is placed in the widget tree (e.g. inside MaterialApp builder)
    final navigator = Navigator.of(context, rootNavigator: true);
    showModalBottomSheet(
      context: navigator.context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SurveySheet(
        rule: rule,
        onSubmitOption: (option) {
          _recorder.record('survey_response', properties: {
            'id': EventValue.string(rule.id),
            'type': EventValue.string('choice'),
            'option': EventValue.string(option),
          });
          _markCompleted(rule.id, userId);
          Navigator.of(sheetContext).pop();
          if (mounted) setState(() => _activeRule = null);
        },
        onSubmitText: (text) {
          _recorder.record('survey_response', properties: {
            'id': EventValue.string(rule.id),
            'type': EventValue.string('text'),
            'text': EventValue.string(text),
          });
          _markCompleted(rule.id, userId);
          Navigator.of(sheetContext).pop();
          if (mounted) setState(() => _activeRule = null);
        },
        onClose: () {
          _recorder.record('survey_dismissed', properties: {
            'id': EventValue.string(rule.id),
            'responseType': EventValue.string(rule.response.analyticsType),
          });
          Navigator.of(sheetContext).pop();
          if (mounted) setState(() => _activeRule = null);
        },
      ),
    );
  }

  void _markCompleted(String ruleId, String? userId) {
    _gating.markCompleted(ruleId, userId);

    // Clean up scheduled state
    final session = _recorder.currentSession;
    if (session != null) {
      _scheduledStore.removeScheduled(
        ruleId: ruleId,
        sessionId: session.id,
        userId: userId,
      );
    }
    _scheduledTimers[ruleId]?.cancel();
    _scheduledTimers.remove(ruleId);
  }

  Future<void> _restorePendingSurveys() async {
    final session = _recorder.currentSession;
    if (session == null) return;

    final userId = session.userId;

    // Check for triggered surveys (time has passed)
    final triggered = await _scheduledStore.getAllTriggeredSurveys(userId);
    for (final scheduled in triggered) {
      final rule = _config.surveys.where((r) => r.id == scheduled.id).firstOrNull;
      if (rule != null) {
        _showSurvey(rule: rule, userId: userId);
        await _scheduledStore.removeScheduled(
          ruleId: rule.id,
          sessionId: scheduled.sessionId,
          userId: userId,
        );
        return; // Only show one at a time
      }
    }

    // Check for pending surveys
    final pending = await _scheduledStore.getAllPendingSurveys(userId);
    for (final scheduled in pending) {
      final rule = _config.surveys.where((r) => r.id == scheduled.id).firstOrNull;
      if (rule != null) {
        final remaining = scheduled.remainingDelay.inSeconds;
        if (remaining <= 0) {
          _showSurvey(rule: rule, userId: userId);
          await _scheduledStore.removeScheduled(
            ruleId: rule.id,
            sessionId: scheduled.sessionId,
            userId: userId,
          );
        } else {
          // Re-schedule with remaining time
          _scheduleDelayedSurvey(
            rule: rule,
            userId: userId,
            delaySeconds: remaining,
          );
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
