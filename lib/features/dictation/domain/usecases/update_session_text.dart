import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_session_repository.dart';

/// Parameters for updating session transcription text.
class UpdateSessionTextParams {
  /// The ULID of the session to update.
  final String sessionId;

  /// The new accumulated transcription text.
  final String text;

  /// Whether this is refined text (LLM-processed) vs raw transcription.
  final bool isRefined;

  /// Creates update session text parameters.
  const UpdateSessionTextParams({
    required this.sessionId,
    required this.text,
    this.isRefined = false,
  });
}

/// Use case for updating the transcription text of a session.
///
/// Updates either the raw transcribed text or the refined (LLM-processed)
/// text depending on the [isRefined] flag. This is typically called:
/// - By the [ChunkProcessor] when new chunk transcriptions arrive.
/// - By the BLoC when applying LLM refinement results.
/// - Directly by UI when the user edits the transcription.
@injectable
class UpdateSessionText implements UseCase<Unit, UpdateSessionTextParams> {
  final ISessionRepository _sessionRepository;
  final Logger _logger;

  /// Creates the update session text use case.
  UpdateSessionText({
    required ISessionRepository sessionRepository,
    required Logger logger,
  })  : _sessionRepository = sessionRepository,
        _logger = logger;

  @override
  Future<Either<Failure, Unit>> call(UpdateSessionTextParams params) async {
    try {
      _logger.d(
        'UpdateSessionText: Updating ${params.isRefined ? "refined" : "transcribed"} text '
        'for session ${params.sessionId} (${params.text.length} chars)',
      );

      if (params.isRefined) {
        return await _sessionRepository.updateRefinedText(
          params.sessionId,
          params.text,
        );
      } else {
        return await _sessionRepository.updateTranscribedText(
          params.sessionId,
          params.text,
        );
      }
    } catch (e, stackTrace) {
      _logger.e('UpdateSessionText: Unexpected error', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to update session text: $e'));
    }
  }
}
