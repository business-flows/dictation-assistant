import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/session_entity.dart';
import '../entities/session_summary_entity.dart';

/// Abstract repository interface for session history operations.
///
/// Defines all data operations needed by the history feature.
/// Implementations handle the actual database and filesystem interactions.
abstract class IHistoryRepository {
  /// Retrieves all sessions ordered by creation time (newest first).
  ///
  /// Returns a list of [SessionSummaryEntity] for lightweight list display.
  Future<Either<Failure, List<SessionSummaryEntity>>> getAllSessions();

  /// Searches sessions by query string on transcription content.
  ///
  /// Uses case-insensitive LIKE matching on [SessionSummaryEntity.previewText].
  Future<Either<Failure, List<SessionSummaryEntity>>> searchSessions(String query);

  /// Retrieves full session detail by ID.
  ///
  /// Returns a [SessionEntity] with complete transcription text and metadata.
  /// Returns [CacheFailure] if session not found.
  Future<Either<Failure, SessionEntity>> getSessionDetail(String id);

  /// Deletes a session and its associated audio file.
  ///
  /// Removes the session record from the database (cascades to chunks),
  /// then deletes the audio file from the filesystem.
  Future<Either<Failure, Unit>> deleteSession(String id);

  /// Gets the audio file path for a session.
  ///
  /// Returns the absolute file path to the session's audio recording.
  Future<Either<Failure, String>> getSessionAudioPath(String id);

  /// Copies the given text to the system clipboard.
  Future<Either<Failure, Unit>> copyTextToClipboard(String text);
}
