import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/refinement_result_entity.dart';
import '../repositories/i_llm_repository.dart';

/// Use case for single-shot (non-streaming) text refinement.
///
/// Sends the entire dictation text to the LLM and waits for the
/// complete refined response. Use this when you need the full
/// result with metadata (tokens used, model, timing).
///
/// Example:
/// ```dart
/// final result = await refineText(RefineTextParams(
///   text: transcribedText,
///   languageCode: 'en',
/// ));
/// ```
class RefineText implements UseCase<RefinementResultEntity, RefineTextParams> {
  final ILLMRepository _repository;

  const RefineText(this._repository);

  @override
  Future<Either<Failure, RefinementResultEntity>> call(RefineTextParams params) {
    return _repository.refineText(
      text: params.text,
      languageCode: params.languageCode,
      customPrompt: params.customPrompt,
    );
  }
}

/// Parameters for [RefineText] use case.
class RefineTextParams extends Equatable {
  /// The original dictation text to refine.
  final String text;

  /// ISO 639-1 language code (e.g., 'en', 'ar', 'fr').
  final String languageCode;

  /// Optional custom system prompt override.
  final String? customPrompt;

  const RefineTextParams({
    required this.text,
    required this.languageCode,
    this.customPrompt,
  });

  @override
  List<Object?> get props => [text, languageCode, customPrompt];
}
