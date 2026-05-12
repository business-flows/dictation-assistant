import 'package:equatable/equatable.dart';

/// Base class for all dictation BLoC events.
///
/// All events extend this class to ensure type safety in the BLoC.
abstract class DictationEvent extends Equatable {
  const DictationEvent();

  @override
  List<Object?> get props => [];
}

/// Start a new dictation recording session.
///
/// Emitted when the user presses the record button. Creates a new
/// session and begins audio recording with the specified language.
class StartDictation extends DictationEvent {
  /// ISO 639-1 language code: 'en', 'fr', or 'ar'.
  final String languageCode;

  const StartDictation({this.languageCode = 'en'});

  @override
  List<Object?> get props => [languageCode];

  @override
  String toString() => 'StartDictation(languageCode: $languageCode)';
}

/// Stop the current dictation recording.
///
/// Emitted when the user presses the stop button. Stops recording,
/// finalizes the audio file, and completes the session.
class StopDictation extends DictationEvent {
  const StopDictation();

  @override
  String toString() => 'StopDictation()';
}

/// Pause the current recording.
///
/// Emitted when the user presses the pause button. Pauses audio
/// recording and the chunk processing pipeline. The session can
/// be resumed later.
class PauseDictation extends DictationEvent {
  const PauseDictation();

  @override
  String toString() => 'PauseDictation()';
}

/// Resume a paused recording.
///
/// Emitted when the user presses the resume button. Resumes audio
/// recording and the chunk processing pipeline.
class ResumeDictation extends DictationEvent {
  const ResumeDictation();

  @override
  String toString() => 'ResumeDictation()';
}

/// Update the transcription text.
///
/// Emitted when new transcription results arrive from the chunk
/// processor. Carries the full accumulated text.
class UpdateTranscription extends DictationEvent {
  /// The complete accumulated transcription text.
  final String text;

  const UpdateTranscription(this.text);

  @override
  List<Object?> get props => [text];

  @override
  String toString() => 'UpdateTranscription(text: ${text.length} chars)';
}

/// Update the dictation language.
///
/// Emitted when the user changes the language selection. Only
/// effective before recording starts.
class UpdateLanguage extends DictationEvent {
  /// ISO 639-1 language code: 'en', 'fr', or 'ar'.
  final String languageCode;

  const UpdateLanguage(this.languageCode);

  @override
  List<Object?> get props => [languageCode];

  @override
  String toString() => 'UpdateLanguage(languageCode: $languageCode)';
}

/// Recording amplitude update for visualization.
///
/// Emitted periodically while recording to update the waveform/level UI.
class AmplitudeUpdate extends DictationEvent {
  /// Normalized amplitude in range [0.0, 1.0].
  final double amplitude;

  const AmplitudeUpdate(this.amplitude);

  @override
  List<Object?> get props => [amplitude];

  @override
  String toString() => 'AmplitudeUpdate(amplitude: ${amplitude.toStringAsFixed(3)})';
}

/// Chunk processing status update.
///
/// Emitted when the chunk processor changes state (e.g., starts
/// transcribing, completes a chunk, encounters an error).
class ProcessingStatusUpdate extends DictationEvent {
  /// Human-readable status message.
  final String status;

  const ProcessingStatusUpdate(this.status);

  @override
  List<Object?> get props => [status];

  @override
  String toString() => 'ProcessingStatusUpdate(status: $status)';
}
