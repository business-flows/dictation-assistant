import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';

/// Parameters for starting a dictation session.
class StartDictationParams {
  final String languageCode;

  const StartDictationParams({required this.languageCode});
}

/// Result of starting a dictation session.
class DictationSessionResult {
  final String sessionId;
  final String languageCode;
  final DateTime startedAt;

  const DictationSessionResult({
    required this.sessionId,
    required this.languageCode,
    required this.startedAt,
  });
}

/// Starts a new dictation/recording session.
///
/// Validates the language code, initializes audio recording,
/// and creates a new session entry in the database.
class StartDictation implements UseCase<DictationSessionResult, StartDictationParams> {
  @override
  Future<Either<Failure, DictationSessionResult>> call(StartDictationParams params) {
    // Implementation provided by another developer
    throw UnimplementedError('StartDictation use case not yet implemented');
  }
}
