import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../../services/app_database.dart';

/// Local data source for session CRUD operations.
///
/// Thin wrapper around [AppDatabase] that provides a clean interface
/// for session-related database operations. This class isolates the
/// data access layer from the repository, making it easier to swap
/// implementations or add caching in the future.
///
/// All methods directly delegate to the corresponding [AppDatabase]
/// methods with added logging for debugging purposes.
@injectable
class SessionLocalDataSource {
  final AppDatabase _database;
  final Logger _logger;

  /// Creates the session local data source.
  SessionLocalDataSource({
    required AppDatabase database,
    required Logger logger,
  })  : _database = database,
        _logger = logger;

  // ---- Session queries ----

  /// Watch all sessions ordered by creation time (newest first).
  ///
  /// Returns a stream that emits the full list of sessions whenever
  /// any session row changes.
  Stream<List<Session>> watchAllSessions() {
    _logger.d('SessionLocalDataSource: Watching all sessions');
    return _database.watchAllSessions();
  }

  /// Get all sessions as a one-time query.
  ///
  /// Returns a list of all sessions ordered by creation time.
  Future<List<Session>> getAllSessions() async {
    _logger.d('SessionLocalDataSource: Getting all sessions');
    return _database.getAllSessions();
  }

  /// Get a single session by its ULID.
  ///
  /// [id] - The 26-character ULID of the session.
  ///
  /// Returns the session, or null if not found.
  Future<Session?> getSession(String id) async {
    _logger.d('SessionLocalDataSource: Getting session $id');
    return _database.getSession(id);
  }

  /// Insert a new session into the database.
  ///
  /// [session] - The session data to insert.
  ///
  /// Returns the number of rows affected (1 on success).
  Future<int> insertSession(SessionsCompanion session) async {
    _logger.d('SessionLocalDataSource: Inserting session ${session.id.value}');
    return _database.insertSession(session);
  }

  /// Update session data.
  ///
  /// [id] - The ULID of the session to update.
  /// [data] - The updated session data.
  ///
  /// Returns true if the update was successful.
  Future<bool> updateSession(String id, SessionsCompanion data) async {
    _logger.d('SessionLocalDataSource: Updating session $id');
    return _database.updateSession(id, data);
  }

  /// Update only the transcribed text for a session.
  ///
  /// [id] - The session ULID.
  /// [text] - The new transcription text.
  ///
  /// Returns the number of rows affected.
  Future<int> updateTranscribedText(String id, String text) async {
    _logger.d('SessionLocalDataSource: Updating transcribed text for session $id');
    return _database.updateSessionText(id, text);
  }

  /// Update the refined text for a session.
  ///
  /// [id] - The session ULID.
  /// [refinedText] - The refined text, or null to clear it.
  ///
  /// Returns the number of rows affected.
  Future<int> updateRefinedText(String id, String? refinedText) async {
    _logger.d('SessionLocalDataSource: Updating refined text for session $id');
    return _database.updateRefinedText(id, refinedText);
  }

  /// Finalize a session with status and duration.
  ///
  /// [id] - The session ULID.
  /// [status] - The final status.
  /// [durationMs] - The total recording duration in milliseconds.
  ///
  /// Returns the number of rows affected.
  Future<int> finalizeSession(String id, SessionStatus status, int durationMs) async {
    _logger.d('SessionLocalDataSource: Finalizing session $id (status: $status, duration: ${durationMs}ms)');
    return _database.finalizeSession(id, status, durationMs);
  }

  /// Delete a session by its ULID.
  ///
  /// Cascades to delete all associated audio chunks via foreign key.
  ///
  /// [id] - The ULID of the session to delete.
  ///
  /// Returns the number of rows deleted.
  Future<int> deleteSession(String id) async {
    _logger.d('SessionLocalDataSource: Deleting session $id');
    return _database.deleteSession(id);
  }

  // ---- Chunk queries ----

  /// Get all chunks for a session.
  ///
  /// [sessionId] - The ULID of the parent session.
  ///
  /// Returns chunks ordered by chunk index.
  Future<List<AudioChunk>> getChunksForSession(String sessionId) async {
    _logger.d('SessionLocalDataSource: Getting chunks for session $sessionId');
    return _database.getChunksForSession(sessionId);
  }

  /// Insert a new audio chunk.
  ///
  /// [chunk] - The chunk data to insert.
  ///
  /// Returns the number of rows affected.
  Future<int> insertChunk(AudioChunksCompanion chunk) async {
    _logger.d('SessionLocalDataSource: Inserting chunk ${chunk.id.value}');
    return _database.insertChunk(chunk);
  }

  /// Update chunk transcription result.
  ///
  /// [id] - The chunk ULID.
  /// [transcription] - The transcription text.
  /// [confidence] - Optional confidence score (0.0-1.0).
  ///
  /// Returns the number of rows affected.
  Future<int> updateChunkTranscription(
    String id,
    String transcription,
    double? confidence,
  ) async {
    _logger.d('SessionLocalDataSource: Updating transcription for chunk $id');
    return _database.updateChunkTranscription(id, transcription, confidence);
  }

  /// Update chunk status.
  ///
  /// [id] - The chunk ULID.
  /// [status] - The new chunk status.
  ///
  /// Returns the number of rows affected.
  Future<int> updateChunkStatus(String id, ChunkStatus status) async {
    _logger.d('SessionLocalDataSource: Updating status for chunk $id to $status');
    return _database.updateChunkStatus(id, status);
  }
}
