import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/event.dart';
import '../models/event_session.dart';
import '../models/event_value.dart';
import '../models/retention_policy.dart';
import 'event_store.dart';
import 'scheduled_survey_store.dart';

/// Coordinates session lifecycle and per-session event store.
class SessionCoordinator {
  final Directory _baseDirectory;
  final RetentionPolicy _retentionPolicy;

  EventSession? _currentSession;
  EventStore? _currentStore;

  SessionCoordinator({
    required Directory baseDirectory,
    RetentionPolicy retentionPolicy = RetentionPolicy.standard,
  })  : _baseDirectory = baseDirectory,
        _retentionPolicy = retentionPolicy;

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
    final paths = _pathsFor(session);

    try {
      if (!await paths.sessionDir.exists()) {
        await paths.sessionDir.create(recursive: true);
      }
      // Persist session metadata
      final metaFile = File('${paths.sessionDir.path}/session.json');
      await metaFile.writeAsString(jsonEncode(session.toJson()));
    } catch (e) {
      // Ignore errors to keep API non-throwing
    }

    _currentSession = session;
    _currentStore = EventStore(file: File('${paths.sessionDir.path}/events.jsonl'));
    return session;
  }

  /// End the current session
  Future<void> endSession() async {
    final session = _currentSession;
    if (session == null) return;

    final endedSession = session.copyWith(endedAt: DateTime.now());
    final paths = _pathsFor(session);

    try {
      final metaFile = File('${paths.sessionDir.path}/session.json');
      await metaFile.writeAsString(jsonEncode(endedSession.toJson()));
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

    await for (final entity in _baseDirectory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('events.jsonl')) {
        final store = EventStore(file: entity);
        final events = await store.readAll();
        all.addAll(events);
      }
    }

    return all;
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    try {
      if (await _baseDirectory.exists()) {
        await _baseDirectory.delete(recursive: true);
      }
    } catch (e) {
      // Ignore
    }
    _currentSession = null;
    _currentStore = null;
  }

  /// List all sessions
  Future<List<EventSession>> listAllSessions() async {
    final sessions = <EventSession>[];

    await for (final entity in _baseDirectory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('session.json')) {
        try {
          final data = await entity.readAsString();
          final json = jsonDecode(data) as Map<String, dynamic>;
          sessions.add(EventSession.fromJson(json));
        } catch (_) {
          // Skip malformed files
        }
      }
    }

    sessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return sessions;
  }

  /// List sessions for a specific user
  Future<List<EventSession>> listSessionsForUser(String? userId) async {
    final userFolder = _safeUserFolder(userId);
    final sessionsDir = Directory('${_baseDirectory.path}/users/$userFolder/sessions');

    if (!await sessionsDir.exists()) return [];

    final result = <EventSession>[];
    await for (final dir in sessionsDir.list()) {
      if (dir is Directory) {
        final metaFile = File('${dir.path}/session.json');
        if (await metaFile.exists()) {
          try {
            final data = await metaFile.readAsString();
            final json = jsonDecode(data) as Map<String, dynamic>;
            result.add(EventSession.fromJson(json));
          } catch (_) {
            // Skip
          }
        }
      }
    }

    result.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return result;
  }

  /// Get events for a specific session
  Future<List<Event>> eventsForSession(String sessionId) async {
    await for (final entity in _baseDirectory.list(recursive: true)) {
      if (entity is Directory && entity.path.endsWith(sessionId)) {
        final eventsFile = File('${entity.path}/events.jsonl');
        if (await eventsFile.exists()) {
          final store = EventStore(file: eventsFile);
          return await store.readAll();
        }
      }
    }
    return [];
  }

  /// Apply retention policy to clean up old data
  Future<void> applyRetentionPolicy() async {
    final usersDir = Directory('${_baseDirectory.path}/users');
    if (!await usersDir.exists()) return;

    await for (final userDir in usersDir.list()) {
      if (userDir is Directory) {
        final sessionsDir = Directory('${userDir.path}/sessions');
        if (await sessionsDir.exists()) {
          await _cleanupUserSessions(sessionsDir);
        }
      }
    }
  }

  Future<void> _cleanupUserSessions(Directory sessionsDir) async {
    final sessions = <({Directory dir, EventSession session})>[];

    await for (final dir in sessionsDir.list()) {
      if (dir is Directory) {
        final metaFile = File('${dir.path}/session.json');
        if (await metaFile.exists()) {
          try {
            final data = await metaFile.readAsString();
            final json = jsonDecode(data) as Map<String, dynamic>;
            sessions.add((dir: dir, session: EventSession.fromJson(json)));
          } catch (_) {
            // Skip
          }
        }
      }
    }

    final currentSessionId = _currentSession?.id;

    // Apply age-based retention
    final maxAge = _retentionPolicy.maxAge;
    if (maxAge != null) {
      final cutoffDate = DateTime.now().subtract(maxAge);
      for (final item in sessions) {
        if (item.session.id == currentSessionId) continue;
        if (item.session.startedAt.isBefore(cutoffDate)) {
          await item.dir.delete(recursive: true);
        }
      }
      sessions.removeWhere(
        (s) => s.session.startedAt.isBefore(cutoffDate),
      );
    }

    // Apply count-based retention
    final maxCount = _retentionPolicy.maxSessionsPerUser;
    if (maxCount != null && sessions.length > maxCount) {
      // Sort by start date (newest first)
      sessions.sort((a, b) => b.session.startedAt.compareTo(a.session.startedAt));

      // Delete sessions beyond the limit
      for (var i = maxCount; i < sessions.length; i++) {
        if (sessions[i].session.id != currentSessionId) {
          await sessions[i].dir.delete(recursive: true);
        }
      }
    }
  }

  _SessionPaths _pathsFor(EventSession session) {
    final userFolder = _safeUserFolder(session.userId);
    final sessionDir = Directory(
      '${_baseDirectory.path}/users/$userFolder/sessions/${session.id}',
    );
    return _SessionPaths(sessionDir: sessionDir);
  }

  String _safeUserFolder(String? userId) {
    if (userId == null || userId.isEmpty) return 'anon';
    final allowed = RegExp(r'[^a-zA-Z0-9\-_@.]');
    return userId.replaceAll(allowed, '_');
  }
}

class _SessionPaths {
  final Directory sessionDir;

  _SessionPaths({required this.sessionDir});
}

/// Public singleton interface for recording and inspecting events
class EventRecorder {
  static EventRecorder? _instance;

  /// Singleton instance
  static EventRecorder get instance {
    _instance ??= EventRecorder._internal(
      directory: Directory(''),
      retentionPolicy: RetentionPolicy.standard,
    );
    return _instance!;
  }

  late final SessionCoordinator _coordinator;
  late final Directory _baseDirectory;
  final _eventController = StreamController<Event>.broadcast();
  final _sessionController = StreamController<SessionLifecycleEvent>.broadcast();

  /// Current retention policy
  final RetentionPolicy retentionPolicy;
  bool _initialized = false;

  EventRecorder._internal({
    required Directory directory,
    required this.retentionPolicy,
  }) : _baseDirectory = directory;

  /// Factory constructor for creating instances with custom configuration
  factory EventRecorder({
    Directory? directory,
    RetentionPolicy retentionPolicy = RetentionPolicy.standard,
  }) {
    return EventRecorder._internal(
      directory: directory ?? Directory(''),
      retentionPolicy: retentionPolicy,
    );
  }

  /// Initialize the recorder
  Future<void> initialize() async {
    if (_initialized) return;

    if (_baseDirectory.path.isEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      _baseDirectory = Directory('${appDir.path}/CXHero');
    }

    if (!await _baseDirectory.exists()) {
      await _baseDirectory.create(recursive: true);
    }

    // Re-initialize coordinator with proper directory
    _coordinator = SessionCoordinator(
      baseDirectory: _baseDirectory,
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

  // MARK: - Storage & Analytics helpers

  /// Base directory for storage
  Directory get storageBaseDirectory {
    // Lazy initialization
    if (!_initialized) {
      Future.value(initialize());
    }
    return _baseDirectory;
  }

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
    final store = ScheduledSurveyStore(baseDirectory: _baseDirectory);
    final triggered = await store.getAllTriggeredSurveys(userId);
    final pending = await store.getAllPendingSurveys(userId);
    return triggered.isNotEmpty || pending.isNotEmpty;
  }

  /// Clean up old scheduled surveys
  Future<void> cleanupOldScheduledSurveys({Duration olderThan = const Duration(hours: 24)}) async {
    await initialize();
    final store = ScheduledSurveyStore(baseDirectory: _baseDirectory);
    await store.cleanupOldScheduled(olderThan: olderThan);
  }
}
