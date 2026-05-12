import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../services/audio_service.dart';
import '../../../../services/chunk_processor.dart';
import '../entities/session_entity.dart';
import '../repositories/i_session_repository.dart';

/// Parameters for stopping a dictation session.
class StopDictationParams {
  /// The ULID of the session to stop.
  final String sessionId;

  /// Creates stop dictation parameters.
  const StopDictationParams({required this.sessionId});
}

/// Result of stopping a dictation session.
class StopDictationResult {
  /// The final session entity after stopping.
  final SessionEntity session;

  /// Creates a stop dictation result.
  const StopDictationResult({required this.session});
}

/// Use case for stopping an active dictation session.
///
/// Orchestrates the graceful shutdown of a dictation session:
/// 1. Stops the chunk processing pipeline (waits for pending transcriptions).
/// 2. Stops audio recording and finalizes the WAV file.
/// 3. Finalizes the session in the database with status and duration.
///
/// This is a best-effort operation - it attempts all cleanup steps even
/// if some fail, to avoid leaving the system in an inconsistent state.
@injectable
class StopDictation implements UseCase<StopDictationResult, StopDictationParams> {
  final ISessionRepository _sessionRepository;
  final AudioService _audioService;
  final ChunkProcessor _chunkProcessor;
  final Logger _logger;

  /// Creates the stop dictation use case.
  StopDictation({
    required ISessionRepository sessionRepository,
    required AudioService audioService,
    required ChunkProcessor chunkProcessor,
    required Logger logger,
  })  : _sessionRepository = sessionRepository,
        _audioService = audioService,
        _chunkProcessor = chunkProcessor,
        _logger = logger;

  @override
  Future<Either<Failure, StopDictationResult>> call(StopDictationParams params) async {
    try {
      _logger.i('StopDictation: Stopping dictation for session ${params.sessionId}');

      // Get the current session
      final sessionResult = await _sessionRepository.getSession(params.sessionId);

      late final SessionEntity session;
      final getResult = sessionResult.fold(
        (failure) => failure,
        (s) {
          session = s;
          return null;
        },
      );

      if (getResult != null) {
        return Left(getResult as Failure);
      }

      // Step 1: Stop the chunk processing pipeline (wait for pending transcriptions)
      try {
        await _chunkProcessor.stopPipeline();
      } catch (e) {
        _logger.w('StopDictation: Error stopping chunk pipeline: $e');
        // Continue with cleanup - don't fail the whole operation
      }

      // Step 2: Stop audio recording
      String? finalAudioPath;
      try {
        finalAudioPath = await _audioService.stopRecording();
      } catch (e) {
        _logger.w('StopDictation: Error stopping recording: $e');
        // Continue with cleanup
      }

      // Calculate duration (approximate from audio file or session)
      final durationMs = _calculateDuration(session);

      // Step 3: Finalize the session in the database
      final finalizeResult = await _sessionRepository.finalizeSession(
        params.sessionId,
        SessionStatus.completed,
        durationMs,
      );

      // Check if finalization succeeded
      Failure? finalizeFailure;
      finalizeResult.fold(
        (failure) => finalizeFailure = failure,
        (_) {},
      );

      if (finalizeFailure != null) {
        _logger.w('StopDictation: Session finalization returned failure: $finalizeFailure');
        // Return the failure but include what we know about the session
        return Left(finalizeFailure!);
      }

      // Get the updated session
      final updatedResult = await _sessionRepository.getSession(params.sessionId);

      SessionEntity? updatedSession;
      updatedResult.fold(
        (_) => updatedSession = session.copyWith(
          status: SessionStatus.completed,
          durationMs: durationMs,
        ),
        (s) => updatedSession = s,
      );

      _logger.i('StopDictation: Dictation stopped successfully for session ${params.sessionId} '
          '(duration: ${durationMs}ms)');

      return Right(StopDictationResult(session: updatedSession!));
    } catch (e, stackTrace) {
      _logger.e('StopDictation: Unexpected error', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to stop dictation: $e'));
    }
  }

  /// Calculate the recording duration in milliseconds.
  ///
  /// Attempts to determine the actual recording duration. Falls back
  /// to the session's stored duration if the audio file isn't available.
  int _calculateDuration(SessionEntity session) {
    try {
      // The duration will be calculated more accurately elsewhere;
      // for now use a reasonable estimate based on chunk processor state
      return DateTime.now().toUtc().difference(session.createdAt).inMilliseconds;
    } catch (e) {
      _logger.w('StopDictation: Could not calculate duration: $e');
      return session.durationMs;
    }
  }
}
