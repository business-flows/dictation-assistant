import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';

/// Abstract repository for audio transcription operations.
///
/// Defines the contract for converting audio data to text using the
/// whisper.cpp model. The implementation handles model loading, isolate
///-based transcription, and chunk sequencing.
///
/// All operations return [Either<Failure, T>] for explicit error handling.
/// Transcription failures are typically [TranscriptionFailure] instances
/// which include a [TranscriptionFailure.isRecoverable] flag.
abstract class ITranscriptionRepository {
  /// Transcribe a single audio chunk.
  ///
  /// [audioData] - Raw audio bytes (PCM16 or WAV format). If WAV, the
  ///   header is automatically stripped before processing.
  /// [language] - Language code for transcription ('en', 'fr', 'ar'),
  ///   or null for automatic language detection.
  ///
  /// Returns the transcribed text on success.
  /// Returns [TranscriptionFailure] if model is not loaded or transcription fails.
  /// Returns [AudioFailure] if the audio data is invalid.
  Future<Either<Failure, String>> transcribeChunk(
    Uint8List audioData, {
    String? language,
  });

  /// Process all audio chunks for a session sequentially.
  ///
  /// Retrieves all chunks for the given session, transcribes each one
  /// in order, and returns the combined transcription text.
  ///
  /// [sessionId] - The ULID of the session to process.
  /// [language] - Optional language override (defaults to session's language).
  ///
  /// Returns the combined transcription text from all chunks.
  /// Returns [TranscriptionFailure] if any chunk fails.
  /// Returns [CacheFailure] if the database query fails.
  Future<Either<Failure, String>> processSessionChunks(
    String sessionId, {
    String? language,
  });

  /// Stream of transcription progress updates.
  ///
  /// Emits values in range [0.0, 1.0] representing the fraction of
  /// chunks that have been transcribed for the current operation.
  ///
  /// Listen to this stream to show a progress indicator during
  /// batch transcription operations.
  Stream<double> get progressStream;
}
