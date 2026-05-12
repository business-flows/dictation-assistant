import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_llm_repository.dart';

/// Use case for streaming text refinement.
///
/// Returns a [Stream] of partial text tokens as they arrive from
/// the LLM API. This provides real-time feedback to the user.
///
/// Each emission in the stream is an [Either]:
/// - [Right] contains the next token string to append
/// - [Left] contains a [Failure] if an error occurred
///
/// Example:
/// ```dart
/// final stream = streamRefinement(StreamRefinementParams(
///   text: transcribedText,
///   languageCode: 'en',
/// ));
/// stream.listen((result) {
///   result.fold(
///     (failure) => handleError(failure),
///     (token) => appendToken(token),
///   );
/// });
/// ```
class StreamRefinement
    implements UseCase<Stream<Either<Failure, String>>, StreamRefinementParams> {
  final ILLMRepository _repository;

  const StreamRefinement(this._repository);

  @override
  Future<Either<Failure, Stream<Either<Failure, String>>>> call(
    StreamRefinementParams params,
  ) async {
    try {
      final stream = _repository.refineTextStream(
        text: params.text,
        languageCode: params.languageCode,
        customPrompt: params.customPrompt,
      );
      return Right(stream);
    } catch (e) {
      return Left(UnexpectedFailure('Failed to start refinement stream: $e'));
    }
  }
}

/// Parameters for [StreamRefinement] use case.
class StreamRefinementParams extends Equatable {
  /// The original dictation text to refine.
  final String text;

  /// ISO 639-1 language code (e.g., 'en', 'ar', 'fr').
  final String languageCode;

  /// Optional custom system prompt override.
  final String? customPrompt;

  const StreamRefinementParams({
    required this.text,
    required this.languageCode,
    this.customPrompt,
  });

  @override
  List<Object?> get props => [text, languageCode, customPrompt];
}
