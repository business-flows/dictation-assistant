import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/audio_file_naming.dart';
import '../../../../services/audio_service.dart';
import '../../../../services/chunk_processor.dart';
import '../entities/session_entity.dart';
import '../repositories/i_session_repository.dart';

/// Parameters for starting a dictation session.
class StartDictationParams {
  /// ISO 639-1 language code: 'en', 'fr', or 'ar'.
  final String languageCode;

  /// Creates start dictation parameters.
  const StartDictationParams({this.languageCode = 'en'});
}

/// Use case for starting a new dictation session.
///
/// Orchestrates the creation of a new session, starts audio recording,
/// and initializes the chunk processing pipeline. This is the main entry
/// point for beginning a dictation recording.
///
/// ## Flow:
/// 1. Creates a new session via [ISessionRepository] with a generated ULID.
/// 2. Starts audio recording to the session's audio file path.
/// 3. Initializes the chunk processor pipeline for real-time transcription.
///
/// All three operations must succeed for the dictation to start. If any
/// step fails, the use case attempts to clean up any partial state.
@injectable
class StartDictation implements UseCase<SessionEntity, StartDictationParams> {
  final ISessionRepository _sessionRepository;
  final AudioService _audioService;
  final ChunkProcessor _chunkProcessor;
  final Logger _logger;

  /// Creates the start dictation use case.
  StartDictation({
    required ISessionRepository sessionRepository,
    required AudioService audioService,
    required ChunkProcessor chunkProcessor,
    required Logger logger,
  })  : _sessionRepository = sessionRepository,
        _audioService = audioService,
        _chunkProcessor = chunkProcessor,
        _logger = logger;

  @override
  Future<Either<Failure, SessionEntity>> call(StartDictationParams params) async {
    try {
      _logger.i('StartDictation: Starting dictation with language ${params.languageCode}');

      // Step 1: Create a new session
      final sessionResult = await _sessionRepository.createSession(params.languageCode);

      late final SessionEntity session;
      final createResult = sessionResult.fold(
        (failure) => failure,
        (s) {
          session = s;
          return null;
        },
      );

      if (createResult != null) {
        return Left(createResult as Failure);
      }

      // Step 2: Start audio recording
      try {
        await _audioService.startRecording(
          outputPath: session.audioFilePath,
          languageCode: params.languageCode,
        );
      } catch (e) {
        _logger.e('StartDictation: Failed to start recording', error: e);
        // Attempt to clean up the created session
        await _sessionRepository.deleteSession(session.id);
        return Left(AudioFailure(
          'Failed to start audio recording: $e',
          code: 'RECORD_START_FAILED',
        ));
      }

      // Step 3: Start the chunk processing pipeline
      try {
        await _chunkProcessor.startPipeline(session.id, params.languageCode);
      } catch (e) {
        _logger.e('StartDictation: Failed to start chunk pipeline', error: e);
        // Attempt to clean up
        await _audioService.stopRecording();
        await _sessionRepository.deleteSession(session.id);
        return Left(AudioFailure(
          'Failed to start transcription pipeline: $e',
          code: 'PIPELINE_START_FAILED',
        ));
      }

      _logger.i('StartDictation: Dictation started successfully (session: ${session.id})');
      return Right(session);
    } catch (e, stackTrace) {
      _logger.e('StartDictation: Unexpected error', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to start dictation: $e'));
    }
  }
}
