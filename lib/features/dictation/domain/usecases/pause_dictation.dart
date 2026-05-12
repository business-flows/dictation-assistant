import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../services/audio_service.dart';
import '../../../../services/chunk_processor.dart';
import '../repositories/i_session_repository.dart';

/// Parameters for pausing a dictation session.
class PauseDictationParams {
  /// The ULID of the session to pause.
  final String sessionId;

  const PauseDictationParams({required this.sessionId});
}

/// Use case for pausing an active dictation session.
///
/// Pauses audio recording without finalizing the session. The recording
/// can be resumed later by calling [ResumeDictation].
///
/// Updates the session status to [SessionStatus.paused] in the database.
@injectable
class PauseDictation implements UseCase<Unit, PauseDictationParams> {
  final ISessionRepository _sessionRepository;
  final AudioService _audioService;
  final Logger _logger;

  PauseDictation({
    required ISessionRepository sessionRepository,
    required AudioService audioService,
    required Logger logger,
  })  : _sessionRepository = sessionRepository,
        _audioService = audioService,
        _logger = logger;

  @override
  Future<Either<Failure, Unit>> call(PauseDictationParams params) async {
    try {
      _logger.i('PauseDictation: Pausing session ${params.sessionId}');

      // Pause audio recording
      await _audioService.pauseRecording();

      // Update session status to paused
      final sessionResult = await _sessionRepository.getSession(params.sessionId);
      
      return await sessionResult.fold(
        (failure) async {
          _logger.w('PauseDictation: Session not found: ${params.sessionId}');
          return Left(failure);
        },
        (session) async {
          final updateResult = await _sessionRepository.updateSession(
            session.copyWith(status: SessionStatus.paused),
          );
          
          return updateResult.fold(
            (failure) => Left(failure),
            (_) {
              _logger.i('PauseDictation: Session ${params.sessionId} paused');
              return const Right(unit);
            },
          );
        },
      );
    } catch (e, stackTrace) {
      _logger.e('PauseDictation: Unexpected error', error: e, stackTrace: stackTrace);
      return Left(AudioFailure('Failed to pause dictation: $e'));
    }
  }
}
