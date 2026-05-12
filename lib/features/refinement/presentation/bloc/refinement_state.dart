import 'package:equatable/equatable.dart';

/// Base class for all refinement states.
abstract class RefinementState extends Equatable {
  const RefinementState();

  @override
  List<Object?> get props => [];
}

/// Initial idle state - no refinement is active.
///
/// The UI shows the original text with an option to start refinement.
class RefinementIdle extends RefinementState {
  const RefinementIdle();
}

/// Refinement is in progress (streaming).
///
/// The UI shows the original text alongside the accumulating refined text.
/// A shimmer/pulse animation indicates that the stream is still active.
class RefinementInProgress extends RefinementState {
  /// The original unrefined text.
  final String originalText;

  /// The accumulated refined text received so far.
  final String accumulatedText;

  /// The session ID being refined.
  final String sessionId;

  /// Whether the stream is still active (not yet complete).
  final bool isStreaming;

  const RefinementInProgress({
    required this.originalText,
    required this.accumulatedText,
    required this.sessionId,
    this.isStreaming = true,
  });

  /// Create a copy with updated accumulated text.
  RefinementInProgress copyWith({
    String? accumulatedText,
    bool? isStreaming,
  }) {
    return RefinementInProgress(
      originalText: originalText,
      accumulatedText: accumulatedText ?? this.accumulatedText,
      sessionId: sessionId,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  @override
  List<Object?> get props => [originalText, accumulatedText, sessionId, isStreaming];

  @override
  String toString() =>
      'RefinementInProgress(accumulated: ${accumulatedText.length} chars, streaming: $isStreaming)';
}

/// Refinement has completed successfully.
///
/// The UI shows both original and final refined text for comparison.
/// User can accept or discard the result.
class RefinementCompleted extends RefinementState {
  /// The original unrefined text.
  final String originalText;

  /// The final refined text.
  final String refinedText;

  /// The session ID.
  final String sessionId;

  const RefinementCompleted({
    required this.originalText,
    required this.refinedText,
    required this.sessionId,
  });

  @override
  List<Object?> get props => [originalText, refinedText, sessionId];

  @override
  String toString() =>
      'RefinementCompleted(refined: ${refinedText.length} chars)';
}

/// Refinement failed with an error.
///
/// The UI shows an error message with a retry button.
class RefinementError extends RefinementState {
  /// The original text that was being refined.
  final String originalText;

  /// Human-readable error message.
  final String errorMessage;

  /// Optional error code for specific handling.
  final String? errorCode;

  const RefinementError({
    required this.originalText,
    required this.errorMessage,
    this.errorCode,
  });

  @override
  List<Object?> get props => [originalText, errorMessage, errorCode];

  @override
  String toString() => 'RefinementError(message: $errorMessage, code: $errorCode)';
}

/// The refined text has been accepted and saved.
///
/// UI can navigate back or show a success confirmation.
class RefinementAccepted extends RefinementState {
  /// The session ID that was updated.
  final String sessionId;

  /// The accepted refined text.
  final String refinedText;

  const RefinementAccepted({
    required this.sessionId,
    required this.refinedText,
  });

  @override
  List<Object?> get props => [sessionId, refinedText];
}

/// The refined text has been discarded.
///
/// UI can navigate back or show a discard confirmation.
class RefinementDiscarded extends RefinementState {
  /// The session ID that was updated.
  final String sessionId;

  const RefinementDiscarded({
    required this.sessionId,
  });

  @override
  List<Object?> get props => [sessionId];
}
