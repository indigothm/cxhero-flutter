import 'dart:convert';
import 'dart:io';

import '../models/event.dart';

/// Stores events as JSON Lines to a specific file.
class EventStore {
  final File _file;

  EventStore({required File file}) : _file = file;

  /// Append an event to the store
  Future<void> append(Event event) async {
    try {
      // Ensure parent directory exists
      final dir = _file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final data = jsonEncode(event.toJson());
      final toWrite = '$data\n';

      if (await _file.exists()) {
        await _file.writeAsString(toWrite, mode: FileMode.append);
      } else {
        await _file.writeAsString(toWrite);
      }
    } catch (e) {
      // Intentionally avoid throwing to keep recording non-intrusive
    }
  }

  /// Read all events from the store
  Future<List<Event>> readAll() async {
    try {
      if (!await _file.exists()) return [];

      final data = await _file.readAsString();
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
      if (await _file.exists()) {
        await _file.delete();
      }
    } catch (e) {
      // Swallow errors; clearing is best-effort
    }
  }
}
