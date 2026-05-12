import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/i_transcription_repository.dart';
import '../datasources/local/audio_local_datasource.dart';
import '../datasources/local/session_local_datasource.dart';
import '../../../../services/whisper_service.dart';

/// Concrete implementation of [ITranscriptionRepository].
///
/// Delegates transcription to [WhisperService] (which runs whisper.cpp
/// in an Isolate), reads audio files via [AudioLocalDataSource], and
/// persists results through [SessionLocalDataSource].
///
/// Provides both single-chunk and full-session batch transcription.
/// Progress is tracked via [progressStream] for batch operations.
@LazySingleton(as: ITranscriptionRepository)
class TranscriptionRepositoryImpl implements ITranscriptionRepository {
  final WhisperService _whisperService;
  final AudioLocalDataSource _audioDataSource;
  final SessionLocalDataSource _sessionDataSource;
  final Logger _logger;

  /// Controller for progress stream broadcasting.
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  /// Current progress value (0.0 to 1.0).
  double _currentProgress = 0.0;

  /// Creates the transcription repository.
  TranscriptionRepositoryImpl({
    required WhisperService whisperService,
    required AudioLocalDataSource audioDataSource,
    required SessionLocalDataSource sessionDataSource,
    required Logger logger,
  })  : _whisperService = whisperService,
        _audioDataSource = audioDataSource,
        _sessionDataSource = sessionDataSource,
        _logger = logger;

  @override
  Stream<double> get progressStream => _progressController.stream;

  @override
  Future<Either<Failure, String>> transcribeChunk(
    Uint8List audioData, {
    String? language,
  }) async {
    try {
      // Validate audio data
      if (audioData.isEmpty) {
        return Left(const AudioFailure('Audio data is empty', code: 'EMPTY_AUDIO'));
      }

      // Ensure model is loaded
      if (!_whisperService.isModelLoaded) {
        _logger.w('TranscriptionRepository: No model loaded for transcription');
        return Left(const TranscriptionFailure(
          'No transcription model loaded. Please load a model first.',
          code: 'MODEL_NOT_LOADED',
        ));
      }

      _logger.d('TranscriptionRepository: Transcribing ${audioData.length} bytes (lang: ${language ?? 'auto'})');

      // Perform transcription via WhisperService (runs in Isolate)
      final text = await _whisperService.transcribe(audioData, language: language);

      _logger.d('TranscriptionRepository: Transcription result: "$text"');
      return Right(text.trim());
    } on TranscriptionException catch (e) {
      _logger.e('TranscriptionRepository: Transcription error', error: e);
      return Left(TranscriptionFailure(
        e.message,
        isRecoverable: e.isRecoverable,
        code: e.code,
      ));
    } on PermissionException catch (e) {
      _logger.e('TranscriptionRepository: Permission error', error: e);
      return Left(PermissionFailure(e.message, code: e.code));
    } catch (e, stackTrace) {
      _logger.e('TranscriptionRepository: Unexpected transcription error', error: e, stackTrace: stackTrace);
      return Left(TranscriptionFailure(
        'Transcription failed: $e',
        isRecoverable: true,
        code: 'TRANSCRIPTION_ERROR',
      ));
    }
  }

  @override
  Future<Either<Failure, String>> processSessionChunks(
    String sessionId, {
    String? language,
  }) async {
    try {
      // Get all chunks for the session
      final chunks = await _sessionDataSource.getChunksForSession(sessionId);

      if (chunks.isEmpty) {
        _logger.w('TranscriptionRepository: No chunks found for session $sessionId');
        return const Right('');
      }

      _logger.i('TranscriptionRepository: Processing ${chunks.length} chunks for session $sessionId');

      // Ensure model is loaded
      if (!_whisperService.isModelLoaded) {
        return Left(const TranscriptionFailure(
          'No transcription model loaded. Please load a model first.',
          code: 'MODEL_NOT_LOADED',
        ));
      }

      // Process chunks sequentially
      final StringBuffer accumulatedText = StringBuffer();
      final totalChunks = chunks.length;

      for (var i = 0; i < totalChunks; i++) {
        final chunk = chunks[i];

        try {
          // Read audio data
          final audioData = await _audioDataSource.readAudioFile(chunk.filePath);

          // Transcribe
          final text = await _whisperService.transcribe(audioData, language: language);

          // Update chunk in database
          await _sessionDataSource.updateChunkTranscription(
            chunk.id,
            text.trim(),
            null,
          );

          // Accumulate
          if (text.trim().isNotEmpty) {
            if (accumulatedText.isNotEmpty) {
              accumulatedText.write(' ');
            }
            accumulatedText.write(text.trim());
          }

          // Update progress
          _currentProgress = (i + 1) / totalChunks;
          if (!_progressController.isClosed) {
            _progressController.add(_currentProgress);
          }

          _logger.d('TranscriptionRepository: Chunk ${chunk.chunkIndex} done: "$text"');
        } catch (e) {
          _logger.e('TranscriptionRepository: Chunk ${chunk.chunkIndex} failed', error: e);

          // Update chunk status to error
          await _sessionDataSource.updateChunkStatus(chunk.id, ChunkStatus.error);

          // Mark chunk as error but continue with remaining chunks
          continue;
        }
      }

      // Update session transcribed text
      final result = accumulatedText.toString();
      await _sessionDataSource.updateTranscribedText(sessionId, result);

      // Reset progress
      _currentProgress = 0.0;
      if (!_progressController.isClosed) {
        _progressController.add(1.0);
      }

      _logger.i('TranscriptionRepository: Session $sessionId processing complete (${result.length} chars)');
      return Right(result);
    } on TranscriptionException catch (e) {
      _logger.e('TranscriptionRepository: Transcription error in batch', error: e);
      return Left(TranscriptionFailure(
        e.message,
        isRecoverable: e.isRecoverable,
        code: e.code,
      ));
    } catch (e, stackTrace) {
      _logger.e('TranscriptionRepository: Unexpected batch error', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to process session chunks: $e'));
    }
  }
}
