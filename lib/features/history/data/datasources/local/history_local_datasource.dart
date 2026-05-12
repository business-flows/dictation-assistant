import 'package:injectable/injectable.dart';

import '../../../../../services/app_database.dart';

/// Thin wrapper around [AppDatabase] for history-related queries.
///
/// Decouples the repository implementation from direct database access,
/// making it easier to swap or mock the data layer.
@singleton
class HistoryLocalDatasource {
  final AppDatabase _db;

  const HistoryLocalDatasource(this._db);

  /// Retrieves all sessions ordered by creation time (newest first).
  Future<List<Session>> getAllSessions() => _db.getAllSessions();

  /// Searches sessions by transcription content using case-insensitive LIKE.
  Future<List<Session>> searchSessions(String query) => _db.searchSessions(query);

  /// Retrieves a single session by ID.
  Future<Session?> getSession(String id) => _db.getSession(id);

  /// Deletes a session (cascades to audio chunks via FK constraint).
  Future<int> deleteSession(String id) => _db.deleteSession(id);

  /// Gets all audio chunks for a session.
  Future<List<AudioChunk>> getChunksForSession(String sessionId) =>
      _db.getChunksForSession(sessionId);
}
