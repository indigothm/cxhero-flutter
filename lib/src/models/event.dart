import 'event_value.dart';

/// Represents an event recorded in the system.
class Event {
  final String id;
  final String name;
  final DateTime timestamp;
  final Map<String, EventValue>? properties;
  final String sessionId;
  final String? userId;

  Event({
    String? id,
    required this.name,
    DateTime? timestamp,
    this.properties,
    required this.sessionId,
    this.userId,
  })  : id = id ?? _generateId(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      'properties': properties?.map((k, v) => MapEntry(k, v.toJson())),
      'sessionId': sessionId,
      'userId': userId,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      properties: (json['properties'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, EventValue.fromJson(v)),
      ),
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String?,
    );
  }

  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_randomString(8)}';
  }

  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[i % chars.length]);
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Event(id: $id, name: $name, sessionId: $sessionId)';
}
