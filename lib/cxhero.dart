/// CXHero Flutter - Lightweight event tracking and survey SDK
///
/// This package provides:
/// - Event recording with session scoping
/// - JSONL file-based storage
/// - Retention policies for automatic cleanup
/// - Configurable micro-surveys with event-based triggers
/// - Support for option, text, and combined response types
/// - Light/dark mode support
/// - Scheduled/delayed survey triggers
/// - Attempt tracking and cooldowns
///
/// Example usage:
/// ```dart
/// // Start a session
/// final session = await EventRecorder.instance.startSession(
///   userId: 'user-123',
///   metadata: {'plan': EventValue.string('pro')},
/// );
///
/// // Record events
/// EventRecorder.instance.record('button_tap', properties: {
///   'screen': EventValue.string('Home'),
/// });
///
/// // Wrap your app with SurveyTrigger to enable surveys
/// SurveyTrigger(
///   config: surveyConfig,
///   child: MyApp(),
/// )
/// ```
library;

// Core models
export 'src/models/event.dart';
export 'src/models/event_session.dart';
export 'src/models/event_value.dart';
export 'src/models/retention_policy.dart';
export 'src/models/survey_config.dart';

// Storage
export 'src/storage/event_recorder.dart';

// Survey
export 'src/survey/survey_config_manager.dart';
export 'src/survey/survey_debug_config.dart';
export 'src/survey/survey_sheet.dart';
export 'src/survey/survey_trigger.dart';
