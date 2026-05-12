import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/session_entity.dart';

/// Abstract repository for dictation session CRUD operations.
///
/// Defines the contract for persisting and retrieving [SessionEntity] objects.
/// All operations return [Either<Failure, T>] for explicit error handling.
///
/// The implementation uses the Drift database (AppDatabase) as the
/// underlying data source. Session IDs are ULIDs generated at creation time.
abstract class ISessionRepository {
  /// Create a new dictation session with the given language code.
  ///
  /// [languageCode] - ISO 639-1 code: 'en', 'fr', or 'ar'.
  ///
  /// Returns the newly created [SessionEntity] with a generated ULID.
  /// Returns [CacheFailure] if the database operation fails.
  Future<Either<Failure, SessionEntity>> createSession(String languageCode);

  /// Retrieve a session by its ULID.
  ///
  /// [id] - The 26-character ULID of the session.
  ///
  /// Returns the [SessionEntity] if found.
  /// Returns [CacheFailure] if the session doesn't exist or DB fails.
  Future<Either<Failure, SessionEntity>> getSession(String id);

  /// Update an existing session.
  ///
  /// [session] - The complete updated session entity (replaces the stored version).
  ///
  /// Returns the updated [SessionEntity].
  /// Returns [CacheFailure] if the session doesn't exist or DB fails.
  Future<Either<Failure, SessionEntity>> updateSession(SessionEntity session);

  /// Delete a session by its ULID.
  ///
  /// [id] - The ULID of the session to delete.
  ///
  /// Returns [Unit] on success. Cascades to delete all associated chunks.
  /// Returns [CacheFailure] if the deletion fails.
  Future<Either<Failure, Unit>> deleteSession(String id);

  /// Get all sessions ordered by creation time (newest first).
  ///
  /// Returns a list of all [SessionEntity] objects.
  /// Returns [CacheFailure] if the database query fails.
  Future<Either<Failure, List<SessionEntity>>> getAllSessions();

  /// Watch all sessions as a reactive stream.
  ///
  /// Emits the full list of sessions whenever any session changes.
  /// The list is ordered by creation time (newest first).
  ///
  /// Returns a stream that emits [Either<Failure, List<SessionEntity>>].
  /// The stream will emit a [CacheFailure] if a query fails.
  Stream<Either<Failure, List<SessionEntity>>> watchAllSessions();

  /// Update only the transcribed text for a session.
  ///
  /// [id] - The session ULID.
  /// [text] - The new accumulated transcription text.
  ///
  /// Returns [Unit] on success.
  /// Returns [CacheFailure] if the update fails.
  Future<Either<Failure, Unit>> updateTranscribedText(String id, String text);

  /// Update the refined (LLM-processed) text for a session.
  ///
  /// [id] - The session ULID.
  /// [text] - The refined text, or null to clear it.
  ///
  /// Returns [Unit] on success.
  /// Returns [CacheFailure] if the update fails.
  Future<Either<Failure, Unit>> updateRefinedText(String id, String? text);

  /// Finalize a session after recording stops.
  ///
  /// [id] - The session ULID.
  /// [status] - The final status (typically [SessionStatus.completed]).
  /// [durationMs] - The total recording duration in milliseconds.
  ///
  /// Returns [Unit] on success.
  /// Returns [CacheFailure] if the update fails.
  Future<Either<Failure, Unit>> finalizeSession(
    String id,
    SessionStatus status,
    int durationMs,
  );
}
