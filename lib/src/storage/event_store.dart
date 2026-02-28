import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event.dart';

/// Stores events as JSON Lines in SharedPreferences (cross-platform / web-safe).
class EventStore {
  final String _key;

  EventStore({required String key}) : _key = key;

  /// Append an event to the store
  Future<void> append(Event event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_key) ?? '';
      final data = jsonEncode(event.toJson());
      final updated = existing.isEmpty ? data : '$existing\n$data';
      await prefs.setString(_key, updated);
    } catch (e) {
      // Intentionally avoid throwing to keep recording non-intrusive
    }
  }

  /// Read all events from the store
  Future<List<Event>> readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key) ?? '';
      if (data.isEmpty) return [];

      final events = <Event>[];
      for (final line in data.split('\n')) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          events.add(Event.fromJson(json));
        } catch (_) {
          // Skip malformed lines
        }
      }
      return events;
    } catch (e) {
      return [];
    }
  }

  /// Clear all events from the store
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      // Swallow errors; clearing is best-effort
    }
  }
}
