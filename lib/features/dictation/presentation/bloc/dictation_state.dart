import 'package:equatable/equatable.dart';

/// Enum representing the recording status for UI components.
enum RecordingStatus { idle, recording, processing }

/// Base class for all dictation states.
abstract class DictationState extends Equatable {
  final String? selectedLanguage;
  final String? errorMessage;

  const DictationState({
    this.selectedLanguage,
    this.errorMessage,
  });

  /// The current transcription text, if any.
  String? get currentText => null;

  /// The current recording status derived from the state.
  RecordingStatus get recordingStatus => RecordingStatus.idle;

  /// Whether a language has been selected.
  bool get hasLanguage => selectedLanguage != null;

  /// Whether the dictation is currently recording.
  bool get isRecording => false;

  /// Whether the dictation is processing.
  bool get isProcessing => false;

  /// The session ID, if an active or completed session exists.
  String? get sessionId => null;

  @override
  List<Object?> get props => [selectedLanguage, errorMessage];
}

/// Initial state — no language selected, record button disabled.
class DictationInitial extends DictationState {
  const DictationInitial() : super();

  @override
  RecordingStatus get recordingStatus => RecordingStatus.idle;
}

/// Language has been selected, ready to start recording.
class DictationReady extends DictationState {
  const DictationReady({required String? selectedLanguage})
      : super(selectedLanguage: selectedLanguage);

  @override
  RecordingStatus get recordingStatus => RecordingStatus.idle;
}

/// Currently recording — microphone active, transcription streaming.
class DictationRecording extends DictationState {
  @override
  final String sessionId;
  @override
  final String currentText;
  final int elapsedMs;
  final double currentAmplitude;

  const DictationRecording({
    required this.sessionId,
    required this.currentText,
    required this.elapsedMs,
    required this.currentAmplitude,
    required String? selectedLanguage,
  }) : super(selectedLanguage: selectedLanguage);

  @override
  RecordingStatus get recordingStatus => RecordingStatus.recording;

  @override
  bool get isRecording => true;

  @override
  List<Object?> get props => [
        sessionId,
        currentText,
        elapsedMs,
        currentAmplitude,
        selectedLanguage,
      ];
}

/// Recording stopped, processing final transcription.
class DictationProcessing extends DictationState {
  @override
  final String sessionId;
  @override
  final String currentText;
  final double progress;

  const DictationProcessing({
    required this.sessionId,
    required this.currentText,
    required this.progress,
    required String? selectedLanguage,
  }) : super(selectedLanguage: selectedLanguage);

  @override
  RecordingStatus get recordingStatus => RecordingStatus.processing;

  @override
  bool get isProcessing => true;

  @override
  List<Object?> get props => [sessionId, currentText, progress, selectedLanguage];
}

/// Dictation completed — final text (and optional refined text) available.
class DictationCompleted extends DictationState {
  @override
  final String sessionId;
  final String finalText;
  final String? refinedText;

  const DictationCompleted({
    required this.sessionId,
    required this.finalText,
    this.refinedText,
    required String? selectedLanguage,
  }) : super(selectedLanguage: selectedLanguage);

  @override
  String? get currentText => finalText;

  @override
  RecordingStatus get recordingStatus => RecordingStatus.idle;

  @override
  List<Object?> get props => [sessionId, finalText, refinedText, selectedLanguage];
}

/// Error state — holds the previous state so UI can recover gracefully.
class DictationError extends DictationState {
  final String error;
  final DictationState previousState;

  const DictationError({
    required this.error,
    required this.previousState,
  }) : super(
          selectedLanguage: previousState.selectedLanguage,
          errorMessage: error,
        );

  @override
  RecordingStatus get recordingStatus => previousState.recordingStatus;

  @override
  String? get currentText => previousState.currentText;

  @override
  String? get sessionId => previousState.sessionId;

  @override
  List<Object?> get props => [error, previousState];
}
