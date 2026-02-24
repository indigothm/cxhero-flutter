/// Configuration for automatic cleanup of old events and sessions
class RetentionPolicy {
  /// Maximum age for events and sessions (older entries are deleted)
  final Duration? maxAge;

  /// Maximum number of sessions to keep per user (oldest are deleted)
  final int? maxSessionsPerUser;

  /// Whether to automatically cleanup on session start
  final bool automaticCleanupEnabled;

  const RetentionPolicy({
    this.maxAge,
    this.maxSessionsPerUser,
    this.automaticCleanupEnabled = true,
  });

  /// No retention - keep all data indefinitely
  static const none = RetentionPolicy(
    maxAge: null,
    maxSessionsPerUser: null,
    automaticCleanupEnabled: false,
  );

  /// Conservative retention - 90 days or 100 sessions per user
  static const conservative = RetentionPolicy(
    maxAge: Duration(days: 90),
    maxSessionsPerUser: 100,
    automaticCleanupEnabled: true,
  );

  /// Standard retention - 30 days or 50 sessions per user
  static const standard = RetentionPolicy(
    maxAge: Duration(days: 30),
    maxSessionsPerUser: 50,
    automaticCleanupEnabled: true,
  );

  /// Aggressive retention - 7 days or 20 sessions per user
  static const aggressive = RetentionPolicy(
    maxAge: Duration(days: 7),
    maxSessionsPerUser: 20,
    automaticCleanupEnabled: true,
  );
}
