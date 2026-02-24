# CXHero Flutter

Lightweight event tracking for Flutter with per-session and optional user-id scoping, persisted as JSON on disk.

## Features

- **Singleton API**: `EventRecorder.instance`
- **Sessions** with optional `userId` and session metadata
- **Durable local storage** using JSON Lines per session
- **Automatic Data Retention** - Configurable cleanup prevents storage bloat (30 days / 50 sessions default)
- **Primitive properties** with type-safe encoding
- **Session Lifecycle Streams** - Automatic coordination via Dart streams
- **Modern, Polished Survey UI** - Professional, brand-agnostic design with emoji rating buttons
- **Light/Dark Mode Support** - Automatically adapts to system appearance
- **Cross-Session Persistence** - Surveys scheduled in one session show in the next (app restarts)
- **Flutter micro-survey trigger widget** driven by JSON config
- **Multi-Question Surveys** - Combined response type supports rating + optional text in one sheet
- Supports button-choice, free-text, or combined (rating + text) feedback surveys
- Smart emoji mapping for rating labels (Poor 😞, Fair 😐, Good 🙂, Great 😊, Excellent 🤩)
- **Explicit Submit Button** - Combined surveys require user to tap submit (no accidental taps)
- **Debug Configuration** - Presets for production and testing
- Once-per-user gating and cooldowns
- **Scheduled/Delayed Triggers** - Show surveys after a delay (e.g., 70 minutes after check-in)
- **Attempt Tracking** - Track how many times a survey was shown but not completed
- **Max Attempts** - Stop showing a survey after N failed attempts
- **Attempt-Specific Cooldowns** - Different cooldown periods for re-attempts vs initial shows
- Rich trigger operators (eq, ne, gt, gte, lt, lte, contains, notContains, exists)
- Remote config loading with auto-refresh

## Storage Layout

- Base directory: `ApplicationDocumentsDirectory/CXHero`
- Path: `users/<user-or-anon>/sessions/<session-id>/`
  - `session.json` — metadata (id, userId, startedAt, endedAt, metadata)
  - `events.jsonl` — one JSON event per line

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cxhero: ^0.1.0
```

Run:

```bash
flutter pub get
```

### Android Setup

For local notifications (optional), add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

### iOS Setup

For local notifications (optional), add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## Quick Start

```dart
import 'package:cxhero/cxhero.dart';

// EventRecorder.instance uses .standard retention policy by default
// (30 days, 50 sessions per user, automatic cleanup)

// Start an event session (optional userId + metadata)
final session = await EventRecorder.instance.startSession(
  userId: 'user-123',
  metadata: {
    'plan': EventValue.string('pro'),
    'ab': EventValue.string('variantA'),
  },
);
// ↑ Automatic cleanup runs here (removes sessions > 30 days or beyond 50 per user)

// Record events scoped to the current session
EventRecorder.instance.record('button_tap', properties: {
  'screen': EventValue.string('Home'),
  'count': EventValue.int(1),
  'success': EventValue.bool(true),
});

// Read events
final sessionEvents = await EventRecorder.instance.eventsInCurrentSession();
final allEvents = await EventRecorder.instance.allEvents();

// End session (optional)
await EventRecorder.instance.endSession();

// Manual cleanup (if needed)
await EventRecorder.instance.applyRetentionPolicy();

// Clear all stored data
await EventRecorder.instance.clear();
```

### Custom Retention Policy

```dart
// Option 1: Use a preset
final recorder = EventRecorder(
  retentionPolicy: RetentionPolicy.conservative, // 90 days, 100 sessions
);

// Option 2: Custom policy
final custom = RetentionPolicy(
  maxAge: Duration(days: 60),  // 60 days
  maxSessionsPerUser: 75,
  automaticCleanupEnabled: true,
);
final recorder = EventRecorder(retentionPolicy: custom);

// Option 3: Disable retention (for testing)
final recorder = EventRecorder(retentionPolicy: RetentionPolicy.none);
```

## Flutter Micro Survey

Define a JSON config that describes survey rules and triggers.

### Example config JSON (choices + text feedback)

```json
{
  "surveys": [
    {
      "id": "ask_rating",
      "title": "Quick question",
      "message": "How would you rate your experience?",
      "response": {
        "type": "options",
        "options": ["Great", "Okay", "Poor"]
      },
      "oncePerSession": true,
      "oncePerUser": false,
      "cooldownSeconds": 86400,
      "trigger": {
        "event": {
          "name": "checkout_success",
          "properties": {
            "amount": {"op": "gt", "value": 50},
            "coupon": {"op": "exists"},
            "utm": {"op": "contains", "value": "spring"}
          }
        }
      }
    },
    {
      "id": "open_feedback",
      "title": "We'd love your feedback",
      "message": "Tell us what worked well or what could improve.",
      "response": {
        "type": "text",
        "placeholder": "Share your thoughts…",
        "submitLabel": "Send feedback",
        "minLength": 5,
        "maxLength": 500
      },
      "trigger": {
        "event": {
          "name": "checkout_success",
          "properties": {
            "amount": {"op": "gt", "value": 100}
          }
        }
      }
    }
  ]
}
```

### Use in your app

```dart
import 'package:cxhero/cxhero.dart';

class MyApp extends StatelessWidget {
  final SurveyConfig config;

  const MyApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return SurveyTrigger(
      config: config,
      child: MaterialApp(
        title: 'My App',
        home: HomeScreen(),
      ),
    );
  }
}
```

### Loading JSON config from your assets

```dart
import 'package:flutter/services.dart';

Future<SurveyConfig> loadSurveyConfig() async {
  final jsonString = await rootBundle.loadString('assets/surveys.json');
  return SurveyConfig.fromJsonString(jsonString);
}
```

### Remote config with live updates

```dart
final config = await loadSurveyConfig();
final manager = SurveyConfigManager(initial: config);
manager.startAutoRefresh(
  'https://example.com/surveys.json',
  interval: Duration(minutes: 5),
);

// In your widget:
SurveyTrigger(
  configManager: manager,
  child: MyAppContent(),
)
```

## Survey Config Reference

### Top-level

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `surveys` | `List<SurveyRule>` | Yes | — | Ordered list of survey rules; the first matching rule is presented. |

### SurveyRule

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | `String` | Yes | — | Stable identifier for the survey rule. |
| `title` | `String` | Yes | — | Title shown in the survey sheet. |
| `message` | `String` | Yes | — | Message/body shown in the survey sheet. |
| `response` | `SurveyResponse` | Yes* | — | Response configuration (choices or text). |
| `trigger` | `TriggerCondition` | Yes | — | When to show the survey. |
| `oncePerSession` | `bool` | No | `true` | If true, shown at most once per session. |
| `oncePerUser` | `bool` | No | `false` | If true, never shown again for same userId. |
| `cooldownSeconds` | `int` | No | — | Minimum time between presentations. |
| `maxAttempts` | `int` | No | — | Maximum times to show before giving up. |
| `attemptCooldownSeconds` | `int` | No | — | Cooldown for re-attempts after dismissals. |
| `notification` | `NotificationConfig` | No | — | Local notification to send when survey is ready. |

### SurveyResponse

| Type | Fields | Description |
|------|--------|-------------|
| `"options"` | `options: List<String>` | Presents buttons for each option. |
| `"text"` | `placeholder`, `submitLabel`, `allowEmpty`, `minLength`, `maxLength` | Multiline text editor. |
| `"combined"` | `options`, `optionsLabel`, `textField`, `submitLabel` | Rating + optional text. |

### TriggerCondition

```json
{
  "event": {
    "name": "checkout_success",
    "properties": {
      "amount": {"op": "gt", "value": 50}
    },
    "scheduleAfterSeconds": 3600
  }
}
```

### PropertyMatcher operators

| Operator | JSON form | Matches when |
|----------|-----------|--------------|
| equals | `"key": "value"` or `{"op": "eq", "value": "value"}` | Property equals value |
| not equals | `{"op": "ne", "value": "value"}` | Property does not equal |
| greater than | `{"op": "gt", "value": 10}` | Numeric property > value |
| greater or equal | `{"op": "gte", "value": 10}` | Numeric property >= value |
| less than | `{"op": "lt", "value": 10}` | Numeric property < value |
| less or equal | `{"op": "lte", "value": 10}` | Numeric property <= value |
| contains | `{"op": "contains", "value": "foo"}` | String property contains substring |
| notContains | `{"op": "notContains", "value": "x"}` | String property does not contain |
| exists | `{"op": "exists"}` | Property key exists |
| notExists | `{"op": "notExists"}` | Property key is absent |

### Events emitted by the survey

- `survey_presented` with `{ id, responseType }`
- `survey_response`:
  - Choice: `{ id, type: "choice", option }`
  - Text: `{ id, type: "text", text }`
  - Combined: `{ id, type: "text", text }` where format is `"SelectedOption||User feedback"`
- `survey_dismissed` with `{ id, responseType }`

## Advanced Example: Multi-Question Feedback Survey with Delayed Trigger

```json
{
  "surveys": [
    {
      "id": "experience-feedback",
      "title": "How was your experience?",
      "message": "We'd love to hear your thoughts!",
      "response": {
        "type": "combined",
        "options": ["Poor", "Fair", "Good", "Great", "Excellent"],
        "optionsLabel": "How would you rate your experience?",
        "textField": {
          "label": "Tell us more about your experience (optional)...",
          "placeholder": "Share any additional feedback or suggestions",
          "required": false,
          "maxLength": 500
        },
        "submitLabel": "Submit Feedback"
      },
      "trigger": {
        "event": {
          "name": "visit_completed",
          "scheduleAfterSeconds": 3600
        }
      },
      "oncePerSession": true,
      "maxAttempts": 3,
      "attemptCooldownSeconds": 86400
    }
  ]
}
```

## Debug Mode Testing

```dart
SurveyTrigger(
  config: config,
  debugConfig: SurveyDebugConfig.debug, // Bypasses gating, fast delays
  child: MyApp(),
)
```

With `debugConfig: SurveyDebugConfig.debug`:
- ✅ All gating rules bypassed - surveys show every time
- ✅ No completion tracking - test UI repeatedly
- ✅ No attempt limits - unlimited shows
- ✅ Fast delays (60s instead of production values)
- ✅ Events still recorded for analytics testing

## Analytics Helpers

```dart
// List all sessions
final all = await EventRecorder.instance.listAllSessions();

// List sessions for a specific user
final userSessions = await EventRecorder.instance.listSessionsForUser('user-123');

// Get events for a session
final events = await EventRecorder.instance.eventsForSession(userSessions.first.id);
```

## License

MIT License. See `LICENSE` for details.

## Contributing

We use the Developer Certificate of Origin (DCO). Please sign your commits with `-s`.

By contributing, you agree to the inbound=outbound terms.
