import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_transcription_repository.dart';

/// Parameters for processing a single audio chunk.
class ProcessAudioChunkParams {
  /// Raw audio data (PCM16 or WAV format).
  final Uint8List audioData;

  /// ISO 639-1 language code, or null for auto-detect.
  final String? language;

  /// Creates process audio chunk parameters.
  const ProcessAudioChunkParams({
    required this.audioData,
    this.language,
  });
}

/// Use case for transcribing a single audio chunk.
///
/// This is an internal use case typically called by the [ChunkProcessor]
/// to transcribe individual audio segments. It can also be used directly
/// for ad-hoc transcription of a single audio buffer.
///
/// The audio data should be in PCM16 format at 16kHz mono for optimal
/// results with whisper.cpp. WAV data is automatically handled.
@injectable
class ProcessAudioChunk implements UseCase<String, ProcessAudioChunkParams> {
  final ITranscriptionRepository _transcriptionRepository;
  final Logger _logger;

  /// Creates the process audio chunk use case.
  ProcessAudioChunk({
    required ITranscriptionRepository transcriptionRepository,
    required Logger logger,
  })  : _transcriptionRepository = transcriptionRepository,
        _logger = logger;

  @override
  Future<Either<Failure, String>> call(ProcessAudioChunkParams params) async {
    try {
      _logger.d('ProcessAudioChunk: Processing chunk (${params.audioData.length} bytes)');

      final result = await _transcriptionRepository.transcribeChunk(
        params.audioData,
        language: params.language,
      );

      return result.fold(
        (failure) {
          _logger.w('ProcessAudioChunk: Transcription failed: ${failure.message}');
          return Left(failure);
        },
        (text) {
          _logger.d('ProcessAudioChunk: Transcription result: "$text"');
          return Right(text);
        },
      );
    } catch (e, stackTrace) {
      _logger.e('ProcessAudioChunk: Unexpected error', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to process audio chunk: $e'));
    }
  }
}
