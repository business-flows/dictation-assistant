import 'package:equatable/equatable.dart';

import '../../domain/entities/session_entity.dart';

/// Base class for all dictation BLoC states.
///
/// All states extend this class to ensure type safety and provide
/// common properties for the UI to consume.
abstract class DictationState extends Equatable {
  const DictationState();

  @override
  List<Object?> get props => [];
}

/// Initial state - BLoC just created, not ready yet.
///
/// The UI should show a loading indicator or splash while
/// dependencies are being initialized.
class DictationInitial extends DictationState {
  const DictationInitial();

  @override
  String toString() => 'DictationInitial()';
}

/// Ready state - BLoC is initialized and ready to start recording.
///
/// The UI should show the record button and language selector.
/// This is the idle state when no session is active.
class DictationReady extends DictationState {
  /// Currently selected language code.
  final String languageCode;

  /// Whether the whisper model is loaded.
  final bool isModelLoaded;

  const DictationReady({
    this.languageCode = 'en',
    this.isModelLoaded = false,
  });

  DictationReady copyWith({
    String? languageCode,
    bool? isModelLoaded,
  }) {
    return DictationReady(
      languageCode: languageCode ?? this.languageCode,
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
    );
  }

  @override
  List<Object?> get props => [languageCode, isModelLoaded];

  @override
  String toString() => 'DictationReady(languageCode: $languageCode, modelLoaded: $isModelLoaded)';
}

/// Recording state - actively capturing audio and transcribing.
///
/// The UI should show a live waveform, the accumulating transcription
/// text, and pause/stop buttons.
class DictationRecording extends DictationState {
  /// The active session being recorded.
  final SessionEntity session;

  /// The accumulated transcription text so far.
  final String transcriptionText;

  /// Current audio amplitude for visualization [0.0, 1.0].
  final double amplitude;

  /// Current processing status message.
  final String statusMessage;

  const DictationRecording({
    required this.session,
    this.transcriptionText = '',
    this.amplitude = 0.0,
    this.statusMessage = 'Recording...',
  });

  DictationRecording copyWith({
    SessionEntity? session,
    String? transcriptionText,
    double? amplitude,
    String? statusMessage,
  }) {
    return DictationRecording(
      session: session ?? this.session,
      transcriptionText: transcriptionText ?? this.transcriptionText,
      amplitude: amplitude ?? this.amplitude,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  @override
  List<Object?> get props => [
        session.id,
        transcriptionText,
        amplitude,
        statusMessage,
      ];

  @override
  String toString() =>
      'DictationRecording(session: ${session.id}, text: ${transcriptionText.length} chars, '
      'amplitude: ${amplitude.toStringAsFixed(3)})';
}

/// Paused state - recording is paused.
///
/// The UI should show a static waveform, the transcription text
/// received so far, and a resume button.
class DictationPaused extends DictationState {
  /// The active session (still open, not finalized).
  final SessionEntity session;

  /// The accumulated transcription text received before pausing.
  final String transcriptionText;

  const DictationPaused({
    required this.session,
    this.transcriptionText = '',
  });

  DictationPaused copyWith({
    SessionEntity? session,
    String? transcriptionText,
  }) {
    return DictationPaused(
      session: session ?? this.session,
      transcriptionText: transcriptionText ?? this.transcriptionText,
    );
  }

  @override
  List<Object?> get props => [session.id, transcriptionText];

  @override
  String toString() =>
      'DictationPaused(session: ${session.id}, text: ${transcriptionText.length} chars)';
}

/// Processing state - recording stopped, finalizing.
///
/// The UI should show a progress indicator while pending
/// transcriptions complete and the session is being finalized.
class DictationProcessing extends DictationState {
  /// The session being finalized.
  final SessionEntity session;

  /// Current processing message for the UI.
  final String message;

  /// Optional progress value [0.0, 1.0].
  final double? progress;

  const DictationProcessing({
    required this.session,
    this.message = 'Finalizing...',
    this.progress,
  });

  @override
  List<Object?> get props => [session.id, message, progress];

  @override
  String toString() => 'DictationProcessing(session: ${session.id}, message: $message)';
}

/// Error state - something went wrong.
///
/// The UI should display the error message and provide a way
/// to recover (e.g., retry button or return to ready state).
class DictationError extends DictationState {
  /// Human-readable error message.
  final String message;

  /// Error code for programmatic handling.
  final String? code;

  /// The previous state that can be restored.
  final DictationState? previousState;

  const DictationError({
    required this.message,
    this.code,
    this.previousState,
  });

  DictationError copyWith({
    String? message,
    String? code,
    DictationState? previousState,
  }) {
    return DictationError(
      message: message ?? this.message,
      code: code ?? this.code,
      previousState: previousState ?? this.previousState,
    );
  }

  @override
  List<Object?> get props => [message, code, previousState];

  @override
  String toString() => 'DictationError(message: $message, code: $code)';
}
