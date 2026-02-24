/// Represents a JSON-encodable primitive value for event properties.
sealed class EventValue {
  const EventValue();

  const factory EventValue.string(String value) = EventValueString;
  const factory EventValue.int(int value) = EventValueInt;
  const factory EventValue.double(double value) = EventValueDouble;
  const factory EventValue.bool(bool value) = EventValueBool;

  factory EventValue.fromJson(dynamic json) {
    if (json is String) return EventValueString(json);
    if (json is int) return EventValueInt(json);
    if (json is double) return EventValueDouble(json);
    if (json is bool) return EventValueBool(json);
    throw FormatException('Unsupported EventValue type: $json');
  }

  dynamic toJson();

  /// Extract string value if this is a string case
  String? get asString {
    return switch (this) {
      EventValueString(:final value) => value,
      _ => null,
    };
  }

  /// Extract int value if this is an int case
  int? get asInt {
    return switch (this) {
      EventValueInt(:final value) => value,
      _ => null,
    };
  }

  /// Extract double value if this is a double case, or convert int to double
  double? get asDouble {
    return switch (this) {
      EventValueDouble(:final value) => value,
      EventValueInt(:final value) => value.toDouble(),
      _ => null,
    };
  }

  /// Extract bool value if this is a bool case
  bool? get asBool {
    return switch (this) {
      EventValueBool(:final value) => value,
      _ => null,
    };
  }

  @override
  String toString() => toJson().toString();
}

class EventValueString extends EventValue {
  final String value;
  const EventValueString(this.value);

  @override
  dynamic toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventValueString &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class EventValueInt extends EventValue {
  final int value;
  const EventValueInt(this.value);

  @override
  dynamic toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventValueInt &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class EventValueDouble extends EventValue {
  final double value;
  const EventValueDouble(this.value);

  @override
  dynamic toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventValueDouble &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class EventValueBool extends EventValue {
  final bool value;
  const EventValueBool(this.value);

  @override
  dynamic toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventValueBool &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
