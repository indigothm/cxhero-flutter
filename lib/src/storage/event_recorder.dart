import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';
import '../models/event_session.dart';
import '../models/event_value.dart';
import '../models/retention_policy.dart';
import 'event_store.dart';
import 'scheduled_survey_store.dart';

/// Prefix constants for SharedPreferences keys
class _Keys {
  static const String sessionPrefix = 'cxhero_session_';
  static const String sessionListKey = 'cxhero_session_list';
  static const String currentSessionKey = 'cxhero_current_session_id';
  static const String eventsPrefix = 'cxhero_events_';
}

/// Coordinates session lifecycle and per-session event store.
class SessionCoordinator {
  final RetentionPolicy _retentionPolicy;

  EventSession? _currentSession;
  EventStore? _currentStore;

  SessionCoordinator({
    RetentionPolicy retentionPolicy = RetentionPolicy.standard,
  }) : _retentionPolicy = retentionPolicy;

  /// Start a new session
  Future<EventSession> startSession({
    String? userId,
    Map<String, EventValue>? metadata,
  }) async {
    // Run automatic cleanup if enabled
    if (_retentionPolicy.automaticCleanupEnabled) {
      await applyRetentionPolicy();
    }

    final session = EventSession(userId: userId, metadata: metadata);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Persist session metadata
      await prefs.setString(
        '${_Keys.sessionPrefix}${session.id}',
        jsonEncode(session.toJson()),
      );

      // Track sessions list
      final listJson = prefs.getString(_Keys.sessionListKey);
      final ids = listJson != null
          ? List<String>.from(jsonDecode(listJson) as List)
          : <String>[];
      if (!ids.contains(session.id)) {
        ids.add(session.id);
        await prefs.setString(_Keys.sessionListKey, jsonEncode(ids));
      }

      // Store current session id
      await prefs.setString(_Keys.currentSessionKey, session.id);
    } catch (e) {
      // Ignore errors to keep API non-throwing
    }

    _currentSession = session;
    _currentStore = EventStore(key: '${_Keys.eventsPrefix}${session.id}');
    return session;
  }

  /// End the current session
  Future<void> endSession() async {
    final session = _currentSession;
    if (session == null) return;

    final endedSession = session.copyWith(endedAt: DateTime.now());

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_Keys.sessionPrefix}${session.id}',
        jsonEncode(endedSession.toJson()),
      );
      await prefs.remove(_Keys.currentSessionKey);
    } catch (e) {
      // Ignore errors
    }

    _currentSession = null;
    _currentStore = null;
  }

  /// Get current session info
  EventSession? get currentSessionInfo => _currentSession;

  /// Record an event
  Future<({Event? event, EventSession? autoStartedSession})> record(
    String name, {
    Map<String, EventValue>? properties,
  }) async {
    // Ensure we have a session; start an anonymous one if needed
    EventSession? autoStartedSession;
    if (_currentSession == null || _currentStore == null) {
      autoStartedSession = await startSession();
    }

    final session = _currentSession!;
    final store = _currentStore!;

    final event = Event(
      name: name,
      properties: properties,
      sessionId: session.id,
      userId: session.userId,
    );

    await store.append(event);
    return (event: event, autoStartedSession: autoStartedSession);
  }

  /// Get events in current session
  Future<List<Event>> eventsInCurrentSession() async {
    final store = _currentStore;
    if (store == null) return [];
    return await store.readAll();
  }

  /// Get all events across all sessions
  Future<List<Event>> allEvents() async {
    final all = <Event>[];
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getString(_Keys.sessionListKey);
    if (listJson == null) return all;

    final ids = List<String>.from(jsonDecode(listJson) as List);
    for (final id in ids) {
      final store = EventStore(key: '${_Keys.eventsPrefix}$id');
      final events = await store.readAll();
      all.addAll(events);
    }
    return all;
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString(_Keys.sessionListKey);
      if (listJson != null) {
        final ids = List<String>.from(jsonDecode(listJson) as List);
        for (final id in ids) {
          await prefs.remove('${_Keys.sessionPrefix}$id');
          await prefs.remove('${_Keys.eventsPrefix}$id');
        }
      }
      await prefs.remove(_Keys.sessionListKey);
      await prefs.remove(_Keys.currentSessionKey);
    } catch (e) {
      // Ignore
    }
    _currentSession = null;
    _currentStore = null;
  }

  /// List all sessions
  Future<List<EventSession>> listAllSessions() async {
    final sessions = <EventSession>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString(_Keys.sessionListKey);
      if (listJson == null) return sessions;
      final ids = List<String>.from(jsonDecode(listJson) as List);
      for (final id in ids) {
        final data = prefs.getString('${_Keys.sessionPrefix}$id');
        if (data != null) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            sessions.add(EventSession.fromJson(json));
          } catch (_) {
            // Skip malformed
          }
        }
      }
    } catch (e) {
      // Ignore
    }
    sessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return sessions;
  }

  /// List sessions for a specific user
  Future<List<EventSession>> listSessionsForUser(String? userId) async {
    final all = await listAllSessions();
    return all.where((s) => s.userId == userId).toList();
  }

  /// Get events for a specific session
  Future<List<Event>> eventsForSession(String sessionId) async {
    final store = EventStore(key: '${_Keys.eventsPrefix}$sessionId');
    return await store.readAll();
  }

  /// Apply retention policy to clean up old data
  Future<void> applyRetentionPolicy() async {
    try {
      final sessions = await listAllSessions();
      final prefs = await SharedPreferences.getInstance();
      final currentId = _currentSession?.id;

      var toKeep = sessions.where((s) => s.id != currentId).toList();

      // Age-based retention
      final maxAge = _retentionPolicy.maxAge;
      if (maxAge != null) {
        final cutoff = DateTime.now().subtract(maxAge);
        final toDelete = toKeep.where((s) => s.startedAt.isBefore(cutoff));
        for (final s in toDelete) {
          await prefs.remove('${_Keys.sessionPrefix}${s.id}');
          await prefs.remove('${_Keys.eventsPrefix}${s.id}');
        }
        toKeep = toKeep.where((s) => !s.startedAt.isBefore(cutoff)).toList();
      }

      // Count-based retention
      final maxCount = _retentionPolicy.maxSessionsPerUser;
      if (maxCount != null && toKeep.length > maxCount) {
        toKeep.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        final extras = toKeep.skip(maxCount);
        for (final s in extras) {
          await prefs.remove('${_Keys.sessionPrefix}${s.id}');
          await prefs.remove('${_Keys.eventsPrefix}${s.id}');
        }
        toKeep = toKeep.take(maxCount).toList();
      }

      // Update the sessions list
      final retainedIds = [
        if (currentId != null) currentId,
        ...toKeep.map((s) => s.id),
      ];
      await prefs.setString(_Keys.sessionListKey, jsonEncode(retainedIds));
    } catch (e) {
      // Ignore
    }
  }
}

/// Public singleton interface for recording and inspecting events
class EventRecorder {
  static EventRecorder? _instance;

  /// Singleton instance
  static EventRecorder get instance {
    _instance ??= EventRecorder._internal(
      retentionPolicy: RetentionPolicy.standard,
    );
    return _instance!;
  }

  late final SessionCoordinator _coordinator;
  final _eventController = StreamController<Event>.broadcast();
  final _sessionController = StreamController<SessionLifecycleEvent>.broadcast();

  /// Current retention policy
  final RetentionPolicy retentionPolicy;
  bool _initialized = false;

  EventRecorder._internal({
    required this.retentionPolicy,
  });

  /// Factory constructor for creating instances with custom configuration
  factory EventRecorder({
    RetentionPolicy retentionPolicy = RetentionPolicy.standard,
  }) {
    return EventRecorder._internal(
      retentionPolicy: retentionPolicy,
    );
  }

  /// Initialize the recorder
  Future<void> initialize() async {
    if (_initialized) return;

    _coordinator = SessionCoordinator(
      retentionPolicy: retentionPolicy,
    );

    _initialized = true;
  }

  // MARK: - Session API

  /// Start a new session
  Future<EventSession> startSession({
    String? userId,
    Map<String, EventValue>? metadata,
  }) async {
    await initialize();
    final session = await _coordinator.startSession(
      userId: userId,
      metadata: metadata,
    );
    _sessionController.add(SessionStarted(session));
    return session;
  }

  /// End the current session
  Future<void> endSession() async {
    final session = _coordinator.currentSessionInfo;
    await _coordinator.endSession();
    _sessionController.add(SessionEnded(session));
  }

  /// Get current session
  EventSession? get currentSession => _coordinator.currentSessionInfo;

  // MARK: - Event API

  /// Record an event
  void record(String name, {Map<String, EventValue>? properties}) {
    Future(() async {
      await initialize();
      final result = await _coordinator.record(name, properties: properties);

      // If a session was auto-started, publish the lifecycle event
      if (result.autoStartedSession != null) {
        _sessionController.add(SessionStarted(result.autoStartedSession!));
      }

      // Publish the event
      if (result.event != null) {
        _eventController.add(result.event!);
      }
    });
  }

  /// Get events in current session
  Future<List<Event>> eventsInCurrentSession() async {
    await initialize();
    return await _coordinator.eventsInCurrentSession();
  }

  /// Get all events across all sessions
  Future<List<Event>> allEvents() async {
    await initialize();
    return await _coordinator.allEvents();
  }

  /// Clear all stored data
  Future<void> clear() async {
    await initialize();
    await _coordinator.clearAll();
  }

  // MARK: - Event stream

  /// Stream of recorded events
  Stream<Event> get eventsStream => _eventController.stream;

  /// Stream of session lifecycle events
  Stream<SessionLifecycleEvent> get sessionStream => _sessionController.stream;

  // MARK: - Analytics helpers

  /// List all sessions
  Future<List<EventSession>> listAllSessions() async {
    await initialize();
    return await _coordinator.listAllSessions();
  }

  /// List sessions for a user
  Future<List<EventSession>> listSessionsForUser(String? userId) async {
    await initialize();
    return await _coordinator.listSessionsForUser(userId);
  }

  /// Get events for a specific session
  Future<List<Event>> eventsForSession(String sessionId) async {
    await initialize();
    return await _coordinator.eventsForSession(sessionId);
  }

  /// Manually apply retention policy
  Future<void> applyRetentionPolicy() async {
    await initialize();
    await _coordinator.applyRetentionPolicy();
  }

  /// Check if there are any scheduled surveys for a user
  Future<bool> hasScheduledSurveys({String? userId}) async {
    await initialize();
    final store = ScheduledSurveyStore();
    final triggered = await store.getAllTriggeredSurveys(userId);
    final pending = await store.getAllPendingSurveys(userId);
    return triggered.isNotEmpty || pending.isNotEmpty;
  }

  /// Clean up old scheduled surveys
  Future<void> cleanupOldScheduledSurveys(
      {Duration olderThan = const Duration(hours: 24)}) async {
    await initialize();
    final store = ScheduledSurveyStore();
    await store.cleanupOldScheduled(olderThan: olderThan);
  }
}
