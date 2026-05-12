import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';

/// Parameters for stopping a dictation session.
class StopDictationParams {
  final String sessionId;

  const StopDictationParams({required this.sessionId});
}

/// Result of stopping a dictation session.
class StopDictationResult {
  final String sessionId;
  final String finalTranscription;
  final String? refinedText;
  final Duration duration;
  final DateTime stoppedAt;

  const StopDictationResult({
    required this.sessionId,
    required this.finalTranscription,
    this.refinedText,
    required this.duration,
    required this.stoppedAt,
  });
}

/// Stops the current dictation/recording session.
///
/// Finalizes audio recording, triggers any pending transcription,
/// and marks the session as completed in the database.
class StopDictation implements UseCase<StopDictationResult, StopDictationParams> {
  @override
  Future<Either<Failure, StopDictationResult>> call(StopDictationParams params) {
    // Implementation provided by another developer
    throw UnimplementedError('StopDictation use case not yet implemented');
  }
}
