import 'event_value.dart';

// ─── Event Registry ──────────────────────────────────────────────────────────
// These types mirror the `events` array exported by the CXHero web configurator.
// They are decoded from the same survey.json consumed at runtime and serve as
// a schema reference — the SDK does not enforce them at runtime.

class EventPropertyDef {
  final String name;
  final String type; // 'string' | 'number' | 'boolean'
  final String? description;
  final String? example;
  final bool optional;

  const EventPropertyDef({
    required this.name,
    required this.type,
    this.description,
    this.example,
    this.optional = true,
  });

  factory EventPropertyDef.fromJson(Map<String, dynamic> json) {
    return EventPropertyDef(
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
      example: json['example'] as String?,
      optional: json['optional'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      if (description != null) 'description': description,
      if (example != null) 'example': example,
      if (optional) 'optional': true,
    };
  }
}

class EventDef {
  final String name;
  final String? description;
  final String? screen;
  final List<EventPropertyDef> properties;

  const EventDef({
    required this.name,
    this.description,
    this.screen,
    this.properties = const [],
  });

  factory EventDef.fromJson(Map<String, dynamic> json) {
    return EventDef(
      name: json['name'] as String,
      description: json['description'] as String?,
      screen: json['screen'] as String?,
      properties: (json['properties'] as List<dynamic>? ?? [])
          .map((e) => EventPropertyDef.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (screen != null) 'screen': screen,
      'properties': properties.map((p) => p.toJson()).toList(),
    };
  }
}

// ─── Survey Config ────────────────────────────────────────────────────────────

/// Top-level survey configuration
class SurveyConfig {
  final List<EventDef> events;
  final List<SurveyRule> surveys;

  const SurveyConfig({this.events = const [], required this.surveys});

  factory SurveyConfig.fromJson(Map<String, dynamic> json) {
    return SurveyConfig(
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => EventDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      surveys: (json['surveys'] as List<dynamic>)
          .map((e) => SurveyRule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (events.isNotEmpty) 'events': events.map((e) => e.toJson()).toList(),
      'surveys': surveys.map((e) => e.toJson()).toList(),
    };
  }

  factory SurveyConfig.fromJsonString(String jsonString) {
    // Remove schema reference if present
    final lines = jsonString.split('\n');
    final filtered = lines.where((line) => !line.trim().startsWith('"\$schema"')).join('\n');
    import 'dart:convert';
    return SurveyConfig.fromJson(json.decode(filtered));
  }
}


/// Notification configuration for survey triggers
class NotificationConfig {
  final String title;
  final String body;
  final bool sound;

  const NotificationConfig({
    required this.title,
    required this.body,
    this.sound = true,
  });

  factory NotificationConfig.fromJson(Map<String, dynamic> json) {
    return NotificationConfig(
      title: json['title'] as String,
      body: json['body'] as String,
      sound: json['sound'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'sound': sound,
    };
  }
}

/// A survey rule defining when and how to show a survey
class SurveyRule {
  final String id;
  final String title;
  final String message;
  final SurveyResponse response;
  final TriggerCondition trigger;
  final bool? oncePerSession;
  final bool? oncePerUser;
  final int? cooldownSeconds;
  final int? maxAttempts;
  final int? attemptCooldownSeconds;
  final NotificationConfig? notification;

  const SurveyRule({
    required this.id,
    required this.title,
    required this.message,
    required this.response,
    required this.trigger,
    this.oncePerSession,
    this.oncePerUser,
    this.cooldownSeconds,
    this.maxAttempts,
    this.attemptCooldownSeconds,
    this.notification,
  });

  factory SurveyRule.fromJson(Map<String, dynamic> json) {
    SurveyResponse response;
    if (json['response'] != null) {
      response = SurveyResponse.fromJson(json['response'] as Map<String, dynamic>);
    } else if (json['options'] != null) {
      // Legacy support for options array
      response = SurveyResponse.options(
        (json['options'] as List<dynamic>).cast<String>(),
      );
    } else {
      throw const FormatException('SurveyRule requires either response or options');
    }

    return SurveyRule(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      response: response,
      trigger: TriggerCondition.fromJson(json['trigger'] as Map<String, dynamic>),
      oncePerSession: json['oncePerSession'] as bool?,
      oncePerUser: json['oncePerUser'] as bool?,
      cooldownSeconds: json['cooldownSeconds'] as int?,
      maxAttempts: json['maxAttempts'] as int?,
      attemptCooldownSeconds: json['attemptCooldownSeconds'] as int?,
      notification: json['notification'] != null
          ? NotificationConfig.fromJson(json['notification'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'response': response.toJson(),
      'trigger': trigger.toJson(),
      if (oncePerSession != null) 'oncePerSession': oncePerSession,
      if (oncePerUser != null) 'oncePerUser': oncePerUser,
      if (cooldownSeconds != null) 'cooldownSeconds': cooldownSeconds,
      if (maxAttempts != null) 'maxAttempts': maxAttempts,
      if (attemptCooldownSeconds != null) 'attemptCooldownSeconds': attemptCooldownSeconds,
      if (notification != null) 'notification': notification!.toJson(),
    };
  }

  SurveyRule copyWith({
    String? id,
    String? title,
    String? message,
    SurveyResponse? response,
    TriggerCondition? trigger,
    bool? oncePerSession,
    bool? oncePerUser,
    int? cooldownSeconds,
    int? maxAttempts,
    int? attemptCooldownSeconds,
    NotificationConfig? notification,
  }) {
    return SurveyRule(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      response: response ?? this.response,
      trigger: trigger ?? this.trigger,
      oncePerSession: oncePerSession ?? this.oncePerSession,
      oncePerUser: oncePerUser ?? this.oncePerUser,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      attemptCooldownSeconds: attemptCooldownSeconds ?? this.attemptCooldownSeconds,
      notification: notification ?? this.notification,
    );
  }
}

/// Survey response type and configuration
sealed class SurveyResponse {
  const SurveyResponse();

  const factory SurveyResponse.options(List<String> options) = SurveyResponseOptions;
  const factory SurveyResponse.text(TextResponseConfig config) = SurveyResponseText;
  const factory SurveyResponse.combined(CombinedResponseConfig config) = SurveyResponseCombined;

  factory SurveyResponse.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'options':
        return SurveyResponse.options(
          (json['options'] as List<dynamic>).cast<String>(),
        );
      case 'text':
        return SurveyResponse.text(TextResponseConfig.fromJson(json));
      case 'combined':
        return SurveyResponse.combined(CombinedResponseConfig.fromJson(json));
      default:
        throw FormatException('Unknown survey response type: $type');
    }
  }

  Map<String, dynamic> toJson();

  String get analyticsType {
    return switch (this) {
      SurveyResponseOptions() => 'choice',
      SurveyResponseText() => 'text',
      SurveyResponseCombined() => 'combined',
    };
  }
}

class SurveyResponseOptions extends SurveyResponse {
  final List<String> options;
  const SurveyResponseOptions(this.options);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'options',
      'options': options,
    };
  }
}

class SurveyResponseText extends SurveyResponse {
  final TextResponseConfig config;
  const SurveyResponseText(this.config);

  @override
  Map<String, dynamic> toJson() => {'type': 'text', ...config.toJson()};
}

class SurveyResponseCombined extends SurveyResponse {
  final CombinedResponseConfig config;
  const SurveyResponseCombined(this.config);

  @override
  Map<String, dynamic> toJson() => {'type': 'combined', ...config.toJson()};
}

/// Text response configuration
class TextResponseConfig {
  final String? placeholder;
  final String? submitLabel;
  final bool allowEmpty;
  final int? minLength;
  final int? maxLength;

  const TextResponseConfig({
    this.placeholder,
    this.submitLabel,
    this.allowEmpty = false,
    this.minLength,
    this.maxLength,
  });

  factory TextResponseConfig.fromJson(Map<String, dynamic> json) {
    return TextResponseConfig(
      placeholder: json['placeholder'] as String?,
      submitLabel: json['submitLabel'] as String?,
      allowEmpty: json['allowEmpty'] as bool? ?? false,
      minLength: json['minLength'] as int?,
      maxLength: json['maxLength'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (placeholder != null) 'placeholder': placeholder,
      if (submitLabel != null) 'submitLabel': submitLabel,
      if (allowEmpty) 'allowEmpty': true,
      if (minLength != null) 'minLength': minLength,
      if (maxLength != null) 'maxLength': maxLength,
    };
  }
}

/// Combined response configuration (rating + text)
class CombinedResponseConfig {
  final List<String> options;
  final String? optionsLabel;
  final TextFieldConfig? textField;
  final String? submitLabel;

  const CombinedResponseConfig({
    required this.options,
    this.optionsLabel,
    this.textField,
    this.submitLabel,
  });

  factory CombinedResponseConfig.fromJson(Map<String, dynamic> json) {
    return CombinedResponseConfig(
      options: (json['options'] as List<dynamic>).cast<String>(),
      optionsLabel: json['optionsLabel'] as String?,
      textField: json['textField'] != null
          ? TextFieldConfig.fromJson(json['textField'] as Map<String, dynamic>)
          : null,
      submitLabel: json['submitLabel'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'options': options,
      if (optionsLabel != null) 'optionsLabel': optionsLabel,
      if (textField != null) 'textField': textField!.toJson(),
      if (submitLabel != null) 'submitLabel': submitLabel,
    };
  }
}

/// Text field configuration for combined responses
class TextFieldConfig {
  final String? label;
  final String? placeholder;
  final bool required;
  final int? minLength;
  final int? maxLength;

  const TextFieldConfig({
    this.label,
    this.placeholder,
    this.required = false,
    this.minLength,
    this.maxLength,
  });

  factory TextFieldConfig.fromJson(Map<String, dynamic> json) {
    return TextFieldConfig(
      label: json['label'] as String?,
      placeholder: json['placeholder'] as String?,
      required: json['required'] as bool? ?? false,
      minLength: json['minLength'] as int?,
      maxLength: json['maxLength'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (label != null) 'label': label,
      if (placeholder != null) 'placeholder': placeholder,
      if (required) 'required': true,
      if (minLength != null) 'minLength': minLength,
      if (maxLength != null) 'maxLength': maxLength,
    };
  }
}

/// Trigger condition for when to show a survey
sealed class TriggerCondition {
  const TriggerCondition();

  const factory TriggerCondition.event(EventTrigger trigger) = TriggerConditionEvent;

  factory TriggerCondition.fromJson(Map<String, dynamic> json) {
    if (json['event'] != null) {
      return TriggerCondition.event(
        EventTrigger.fromJson(json['event'] as Map<String, dynamic>),
      );
    }
    throw const FormatException('Unknown trigger condition');
  }

  Map<String, dynamic> toJson();
}

class TriggerConditionEvent extends TriggerCondition {
  final EventTrigger trigger;
  const TriggerConditionEvent(this.trigger);

  @override
  Map<String, dynamic> toJson() {
    return {'event': trigger.toJson()};
  }
}

/// Event trigger configuration
class EventTrigger {
  final String name;
  final Map<String, PropertyMatcher>? properties;
  final int? scheduleAfterSeconds;

  const EventTrigger({
    required this.name,
    this.properties,
    this.scheduleAfterSeconds,
  });

  factory EventTrigger.fromJson(Map<String, dynamic> json) {
    return EventTrigger(
      name: json['name'] as String,
      properties: json['properties'] != null
          ? (json['properties'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, PropertyMatcher.fromJson(v)),
            )
          : null,
      scheduleAfterSeconds: json['scheduleAfterSeconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (properties != null)
        'properties': properties!.map((k, v) => MapEntry(k, v.toJson())),
      if (scheduleAfterSeconds != null) 'scheduleAfterSeconds': scheduleAfterSeconds,
    };
  }

  EventTrigger copyWith({
    String? name,
    Map<String, PropertyMatcher>? properties,
    int? scheduleAfterSeconds,
  }) {
    return EventTrigger(
      name: name ?? this.name,
      properties: properties ?? this.properties,
      scheduleAfterSeconds: scheduleAfterSeconds ?? this.scheduleAfterSeconds,
    );
  }
}

/// Property matcher for event property conditions
sealed class PropertyMatcher {
  const PropertyMatcher();

  factory PropertyMatcher.fromJson(dynamic json) {
    // Support shorthand equals: value directly
    if (json is String) return PropertyMatcherEquals(MatchAtom.string(json));
    if (json is int) return PropertyMatcherEquals(MatchAtom.int(json));
    if (json is double) return PropertyMatcherEquals(MatchAtom.double(json));
    if (json is bool) return PropertyMatcherEquals(MatchAtom.bool(json));

    if (json is Map<String, dynamic>) {
      final op = json['op'] as String;
      switch (op) {
        case 'eq':
          return PropertyMatcherEquals(MatchAtom.fromJson(json['value']));
        case 'ne':
          return PropertyMatcherNotEquals(MatchAtom.fromJson(json['value']));
        case 'gt':
          return PropertyMatcherGreaterThan((json['value'] as num).toDouble());
        case 'gte':
          return PropertyMatcherGreaterThanOrEqual((json['value'] as num).toDouble());
        case 'lt':
          return PropertyMatcherLessThan((json['value'] as num).toDouble());
        case 'lte':
          return PropertyMatcherLessThanOrEqual((json['value'] as num).toDouble());
        case 'contains':
          return PropertyMatcherContains(json['value'] as String);
        case 'notContains':
          return PropertyMatcherNotContains(json['value'] as String);
        case 'exists':
          return const PropertyMatcherExists(true);
        case 'notExists':
          return const PropertyMatcherExists(false);
        default:
          throw FormatException('Unknown operator: $op');
      }
    }

    throw FormatException('Invalid PropertyMatcher: $json');
  }

  dynamic toJson();
  bool matches(EventValue value);
}

class PropertyMatcherEquals extends PropertyMatcher {
  final MatchAtom atom;
  const PropertyMatcherEquals(this.atom);

  @override
  bool matches(EventValue value) => atom.matches(value);

  @override
  dynamic toJson() => atom.toJson();
}

class PropertyMatcherNotEquals extends PropertyMatcher {
  final MatchAtom atom;
  const PropertyMatcherNotEquals(this.atom);

  @override
  bool matches(EventValue value) => !atom.matches(value);

  @override
  dynamic toJson() => {'op': 'ne', 'value': atom.toJson()};
}

class PropertyMatcherGreaterThan extends PropertyMatcher {
  final double value;
  const PropertyMatcherGreaterThan(this.value);

  @override
  bool matches(EventValue ev) => ev.asDouble != null && ev.asDouble! > value;

  @override
  dynamic toJson() => {'op': 'gt', 'value': value};
}

class PropertyMatcherGreaterThanOrEqual extends PropertyMatcher {
  final double value;
  const PropertyMatcherGreaterThanOrEqual(this.value);

  @override
  bool matches(EventValue ev) => ev.asDouble != null && ev.asDouble! >= value;

  @override
  dynamic toJson() => {'op': 'gte', 'value': value};
}

class PropertyMatcherLessThan extends PropertyMatcher {
  final double value;
  const PropertyMatcherLessThan(this.value);

  @override
  bool matches(EventValue ev) => ev.asDouble != null && ev.asDouble! < value;

  @override
  dynamic toJson() => {'op': 'lt', 'value': value};
}

class PropertyMatcherLessThanOrEqual extends PropertyMatcher {
  final double value;
  const PropertyMatcherLessThanOrEqual(this.value);

  @override
  bool matches(EventValue ev) => ev.asDouble != null && ev.asDouble! <= value;

  @override
  dynamic toJson() => {'op': 'lte', 'value': value};
}

class PropertyMatcherContains extends PropertyMatcher {
  final String value;
  const PropertyMatcherContains(this.value);

  @override
  bool matches(EventValue ev) => ev.asString?.contains(value) ?? false;

  @override
  dynamic toJson() => {'op': 'contains', 'value': value};
}

class PropertyMatcherNotContains extends PropertyMatcher {
  final String value;
  const PropertyMatcherNotContains(this.value);

  @override
  bool matches(EventValue ev) => !(ev.asString?.contains(value) ?? false);

  @override
  dynamic toJson() => {'op': 'notContains', 'value': value};
}

class PropertyMatcherExists extends PropertyMatcher {
  final bool shouldExist;
  const PropertyMatcherExists(this.shouldExist);

  @override
  bool matches(EventValue value) => true; // Handled by caller

  bool get exists => shouldExist;

  @override
  dynamic toJson() => {'op': shouldExist ? 'exists' : 'notExists'};
}

/// Match atom for property values
sealed class MatchAtom {
  const MatchAtom();

  const factory MatchAtom.string(String value) = MatchAtomString;
  const factory MatchAtom.int(int value) = MatchAtomInt;
  const factory MatchAtom.double(double value) = MatchAtomDouble;
  const factory MatchAtom.bool(bool value) = MatchAtomBool;

  factory MatchAtom.fromJson(dynamic json) {
    if (json is String) return MatchAtomString(json);
    if (json is int) return MatchAtomInt(json);
    if (json is double) return MatchAtomDouble(json);
    if (json is bool) return MatchAtomBool(json);
    throw FormatException('Unsupported MatchAtom: $json');
  }

  dynamic toJson();
  bool matches(EventValue value);
}

class MatchAtomString extends MatchAtom {
  final String value;
  const MatchAtomString(this.value);

  @override
  dynamic toJson() => value;

  @override
  bool matches(EventValue ev) => ev.asString == value;
}

class MatchAtomInt extends MatchAtom {
  final int value;
  const MatchAtomInt(this.value);

  @override
  dynamic toJson() => value;

  @override
  bool matches(EventValue ev) =>
      ev.asInt == value || ev.asDouble == value.toDouble();
}

class MatchAtomDouble extends MatchAtom {
  final double value;
  const MatchAtomDouble(this.value);

  @override
  dynamic toJson() => value;

  @override
  bool matches(EventValue ev) =>
      ev.asDouble == value || ev.asInt == value.toInt();
}

class MatchAtomBool extends MatchAtom {
  final bool value;
  const MatchAtomBool(this.value);

  @override
  dynamic toJson() => value;

  @override
  bool matches(EventValue ev) => ev.asBool == value;
}
