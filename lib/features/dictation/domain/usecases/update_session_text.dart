import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';

/// Parameters for updating session text.
class UpdateSessionTextParams {
  final String sessionId;
  final String text;

  const UpdateSessionTextParams({
    required this.sessionId,
    required this.text,
  });
}

/// Updates the transcription text for the current session.
///
/// Called when new transcription chunks arrive from the audio processor.
class UpdateSessionText implements UseCase<void, UpdateSessionTextParams> {
  @override
  Future<Either<Failure, void>> call(UpdateSessionTextParams params) {
    // Implementation provided by another developer
    throw UnimplementedError('UpdateSessionText use case not yet implemented');
  }
}
