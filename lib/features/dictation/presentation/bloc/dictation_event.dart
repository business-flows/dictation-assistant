import 'package:equatable/equatable.dart';

/// Base class for all dictation events.
abstract class DictationEvent extends Equatable {
  const DictationEvent();

  @override
  List<Object?> get props => [];
}

/// Event to select/change the transcription language.
/// Only allowed when the dictation is idle (not recording).
class LanguageSelected extends DictationEvent {
  final String? languageCode;

  const LanguageSelected({required this.languageCode});

  @override
  List<Object?> get props => [languageCode];
}

/// Event triggered when the user presses the record button to start dictation.
class StartDictationPressed extends DictationEvent {
  const StartDictationPressed();
}

/// Event triggered when the user presses the stop button to end dictation.
class StopDictationPressed extends DictationEvent {
  const StopDictationPressed();
}

/// Event triggered when the user presses pause during recording.
class PauseDictationPressed extends DictationEvent {
  const PauseDictationPressed();
}

/// Event triggered when the user presses resume after pausing.
class ResumeDictationPressed extends DictationEvent {
  const ResumeDictationPressed();
}

/// Event fired when new transcription text arrives from the audio processor.
class TranscriptionUpdated extends DictationEvent {
  final String text;
  final String sessionId;

  const TranscriptionUpdated({
    required this.text,
    required this.sessionId,
  });

  @override
  List<Object?> get props => [text, sessionId];
}

/// Event fired when refined/structured text is available from LLM processing.
class RefinedTextUpdated extends DictationEvent {
  final String refinedText;

  const RefinedTextUpdated({required this.refinedText});

  @override
  List<Object?> get props => [refinedText];
}

/// Event to toggle between raw and refined text views.
class ToggleRefinedView extends DictationEvent {
  final bool showRefined;

  const ToggleRefinedView({required this.showRefined});

  @override
  List<Object?> get props => [showRefined];
}
