import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import 'start_dictation.dart';

/// Result containing the current active session info (if any).
class CurrentSessionInfo {
  final String sessionId;
  final String languageCode;
  final String currentText;
  final DateTime startedAt;
  final int elapsedMs;

  const CurrentSessionInfo({
    required this.sessionId,
    required this.languageCode,
    required this.currentText,
    required this.startedAt,
    required this.elapsedMs,
  });
}

/// Retrieves the currently active dictation session.
///
/// Returns [None] if no session is currently active.
class GetCurrentSession implements UseCase<CurrentSessionInfo?, NoParams> {
  @override
  Future<Either<Failure, CurrentSessionInfo?>> call(NoParams params) {
    // Implementation provided by another developer
    throw UnimplementedError('GetCurrentSession use case not yet implemented');
  }
}
