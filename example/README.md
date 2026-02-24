# CXHero Example App

A comprehensive demo app showcasing all features of the CXHero Flutter SDK.

## Features Demonstrated

### 1. Dashboard Tab
- **Session Info**: View current session details including ID, user ID, start time, and metadata
- **Quick Stats**: Tap to see event count and session count
- **Quick Actions**: Quickly record common events (button tap, page view, add to cart, checkout)
- **Survey Config Info**: Overview of available survey triggers

### 2. Triggers Tab
- **Option Survey**: Trigger a simple rating survey (Poor to Excellent)
- **Combined Survey**: Trigger a survey with rating buttons + optional text feedback
- **Text Survey**: Trigger a free-form text feedback survey
- **Custom Event Builder**: Create and record custom events with properties

### 3. Event Log Tab
- Real-time event log that updates as events are recorded
- Visual event icons and color coding
- Event properties display
- Relative timestamps

### 4. Settings Tab
- Storage location info
- Manual retention policy application
- About dialog
- Clear all data option

## Survey Types Configured

The example includes 5 different survey configurations in `assets/surveys.json`:

1. **Rating Experience** (`feature_used` event) - Simple 5-star rating
2. **Checkout Feedback** (`checkout_complete` event with amount > 50) - Combined rating + text
3. **General Feedback** (`feedback_requested` event) - Free-form text
4. **NPS Survey** (`page_view` on settings screen) - 0-10 scale, once per user
5. **Purchase Feedback** (`purchase_made` with amount >= 100) - Satisfaction + feedback

## Running the App

```bash
# Navigate to example directory
cd example

# Get dependencies
flutter pub get

# Run on your preferred device
flutter run
```

## Testing Surveys

### Test Option Survey:
1. Go to Dashboard tab
2. Tap "Trigger Rating Survey" OR tap the "Button Tap" quick action
3. The rating survey should appear

### Test Combined Survey:
1. Go to Triggers tab
2. Tap "Trigger Checkout Survey"
3. A combined survey with emoji rating buttons and optional text field appears

### Test Text Survey:
1. Go to Triggers tab
2. Tap "Trigger Feedback Survey"
3. A text-only survey appears

### Test NPS Survey:
1. Record a `page_view` event with `screen: settings`
2. Use Custom Event Builder with name `page_view` and property `screen: settings`

## Debug Mode

To test surveys repeatedly without gating restrictions, uncomment the debug config in `main.dart`:

```dart
SurveyTrigger(
  config: config,
  debugConfig: SurveyDebugConfig.debug, // Add this line
  child: MaterialApp(...),
)
```

With debug mode:
- All gating rules are bypassed (surveys show every time)
- Cooldowns are ignored
- Attempt limits are ignored
- Delays are shortened to 60 seconds
