import 'package:equatable/equatable.dart';

/// Base class for all refinement events.
abstract class RefinementEvent extends Equatable {
  const RefinementEvent();

  @override
  List<Object?> get props => [];
}

/// Start a new text refinement (streaming).
///
/// Emitted when the user initiates refinement on a dictation session.
/// Triggers the streaming LLM refinement process.
class StartRefinement extends RefinementEvent {
  /// The session ID associated with the text being refined.
  final String sessionId;

  /// The original dictation text to refine.
  final String text;

  /// ISO 639-1 language code.
  final String languageCode;

  /// Optional custom system prompt override.
  final String? customPrompt;

  const StartRefinement({
    required this.sessionId,
    required this.text,
    required this.languageCode,
    this.customPrompt,
  });

  @override
  List<Object?> get props => [sessionId, text, languageCode, customPrompt];

  @override
  String toString() =>
      'StartRefinement(sessionId: $sessionId, text: ${text.length} chars, language: $languageCode)';
}

/// Cancel the ongoing refinement stream.
///
/// Emitted when the user cancels refinement before it completes.
/// Closes the active stream subscription and resets to idle state.
class CancelRefinement extends RefinementEvent {
  const CancelRefinement();
}

/// Accept the refined text and persist it to the database.
///
/// Emitted when the user accepts the LLM-refined output.
/// Saves the refined text to the session record.
class AcceptRefinement extends RefinementEvent {
  /// The session ID to update.
  final String sessionId;

  /// The refined text to save.
  final String refinedText;

  const AcceptRefinement({
    required this.sessionId,
    required this.refinedText,
  });

  @override
  List<Object?> get props => [sessionId, refinedText];
}

/// Discard the refined text and revert to original.
///
/// Emitted when the user rejects the LLM-refined output.
/// Clears the refined text from the session record.
class DiscardRefinement extends RefinementEvent {
  /// The session ID to update.
  final String sessionId;

  const DiscardRefinement({
    required this.sessionId,
  });

  @override
  List<Object?> get props => [sessionId];
}

/// Regenerate the refined text with the same input.
///
/// Emitted when the user requests a new refinement attempt.
/// Restarts the streaming process from scratch.
class RegenerateRefinement extends RefinementEvent {
  /// The session ID associated with the text being refined.
  final String sessionId;

  /// The original dictation text to refine.
  final String text;

  /// ISO 639-1 language code.
  final String languageCode;

  const RegenerateRefinement({
    required this.sessionId,
    required this.text,
    required this.languageCode,
  });

  @override
  List<Object?> get props => [sessionId, text, languageCode];
}
