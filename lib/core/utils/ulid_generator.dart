import 'package:ulid/ulid.dart';

/// Generates ULID (Universally Unique Lexicographically Sortable Identifier) strings.
///
/// ULIDs are preferred over UUIDs for session IDs because:
/// - They are sortable by creation time (first 48 bits are timestamp)
/// - They are lexicographically sortable in SQLite without special handling
/// - They are URL-safe and compact (26 characters)
class UlidGenerator {
  UlidGenerator._();

  static final _ulid = Ulid();

  /// Generate a new ULID string.
  static String generate() => _ulid.toString();

  /// Generate a ULID with a specific timestamp (for testing).
  static String generateAt(DateTime timestamp) {
    return Ulid(millis: timestamp.millisecondsSinceEpoch).toString();
  }
}