import 'event_value.dart';

/// Represents a session for recording events.
class EventSession {
  final String id;
  final String? userId;
  final Map<String, EventValue>? metadata;
  final DateTime startedAt;
  final DateTime? endedAt;

  EventSession({
    String? id,
    this.userId,
    this.metadata,
    DateTime? startedAt,
    this.endedAt,
  })  : id = id ?? _generateId(),
        startedAt = startedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'metadata': metadata?.map((k, v) => MapEntry(k, v.toJson())),
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
    };
  }

  factory EventSession.fromJson(Map<String, dynamic> json) {
    return EventSession(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, EventValue.fromJson(v)),
      ),
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
    );
  }

  EventSession copyWith({
    String? id,
    String? userId,
    Map<String, EventValue>? metadata,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return EventSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      metadata: metadata ?? this.metadata,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
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
      other is EventSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'EventSession(id: $id, userId: $userId, startedAt: $startedAt)';
}

/// Session lifecycle events emitted by EventRecorder
sealed class SessionLifecycleEvent {
  const SessionLifecycleEvent();
}

class SessionStarted extends SessionLifecycleEvent {
  final EventSession session;
  const SessionStarted(this.session);
}

class SessionEnded extends SessionLifecycleEvent {
  final EventSession? session;
  const SessionEnded(this.session);
}
