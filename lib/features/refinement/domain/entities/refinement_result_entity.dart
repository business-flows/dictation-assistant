import 'package:equatable/equatable.dart';

/// Entity representing the result of an LLM text refinement operation.
///
/// Contains both the original and refined text, along with metadata
/// about the refinement process (model used, tokens, timing).
class RefinementResultEntity extends Equatable {
  /// The original unrefined transcription text.
  final String originalText;

  /// The LLM-refined text.
  final String refinedText;

  /// Whether the user has accepted this refinement.
  final bool isAccepted;

  /// Timestamp when the refinement was completed.
  final DateTime refinedAt;

  /// The LLM model name used for refinement (e.g., 'gpt-4o-mini').
  final String? modelUsed;

  /// Number of tokens consumed during refinement.
  final int? tokensUsed;

  /// Duration of the refinement API call.
  final Duration? processingTime;

  /// Creates a [RefinementResultEntity].
  const RefinementResultEntity({
    required this.originalText,
    required this.refinedText,
    this.isAccepted = false,
    required this.refinedAt,
    this.modelUsed,
    this.tokensUsed,
    this.processingTime,
  });

  /// Creates a copy with optionally updated fields.
  RefinementResultEntity copyWith({
    String? originalText,
    String? refinedText,
    bool? isAccepted,
    DateTime? refinedAt,
    String? modelUsed,
    int? tokensUsed,
    Duration? processingTime,
  }) {
    return RefinementResultEntity(
      originalText: originalText ?? this.originalText,
      refinedText: refinedText ?? this.refinedText,
      isAccepted: isAccepted ?? this.isAccepted,
      refinedAt: refinedAt ?? this.refinedAt,
      modelUsed: modelUsed ?? this.modelUsed,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      processingTime: processingTime ?? this.processingTime,
    );
  }

  @override
  List<Object?> get props => [
        originalText,
        refinedText,
        isAccepted,
        refinedAt,
        modelUsed,
        tokensUsed,
        processingTime,
      ];

  @override
  String toString() =>
      'RefinementResultEntity(originalText: ${originalText.substring(0, originalText.length > 30 ? 30 : originalText.length)}..., '
      'refinedText: ${refinedText.substring(0, refinedText.length > 30 ? 30 : refinedText.length)}..., '
      'isAccepted: $isAccepted, modelUsed: $modelUsed, tokensUsed: $tokensUsed)';
}
