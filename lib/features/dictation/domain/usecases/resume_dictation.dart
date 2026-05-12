import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../services/audio_service.dart';
import '../repositories/i_session_repository.dart';

/// Parameters for resuming a paused dictation session.
class ResumeDictationParams {
  /// The ULID of the session to resume.
  final String sessionId;

  const ResumeDictationParams({required this.sessionId});
}

/// Use case for resuming a paused dictation session.
///
/// Resumes audio recording and updates the session status back to
/// [SessionStatus.recording]. The chunk processing pipeline is also
/// restarted to continue real-time transcription.
@injectable
class ResumeDictation implements UseCase<Unit, ResumeDictationParams> {
  final ISessionRepository _sessionRepository;
  final AudioService _audioService;
  final Logger _logger;

  ResumeDictation({
    required ISessionRepository sessionRepository,
    required AudioService audioService,
    required Logger logger,
  })  : _sessionRepository = sessionRepository,
        _audioService = audioService,
        _logger = logger;

  @override
  Future<Either<Failure, Unit>> call(ResumeDictationParams params) async {
    try {
      _logger.i('ResumeDictation: Resuming session ${params.sessionId}');

      // Resume audio recording
      await _audioService.resumeRecording();

      // Update session status back to recording
      final sessionResult = await _sessionRepository.getSession(params.sessionId);
      
      return await sessionResult.fold(
        (failure) async {
          _logger.w('ResumeDictation: Session not found: ${params.sessionId}');
          return Left(failure);
        },
        (session) async {
          final updateResult = await _sessionRepository.updateSession(
            session.copyWith(status: SessionStatus.recording),
          );
          
          return updateResult.fold(
            (failure) => Left(failure),
            (_) {
              _logger.i('ResumeDictation: Session ${params.sessionId} resumed');
              return const Right(unit);
            },
          );
        },
      );
    } catch (e, stackTrace) {
      _logger.e('ResumeDictation: Unexpected error', error: e, stackTrace: stackTrace);
      return Left(AudioFailure('Failed to resume dictation: $e'));
    }
  }
}
