import 'dart:async';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_current_session.dart';
import '../../domain/usecases/start_dictation.dart';
import '../../domain/usecases/stop_dictation.dart';
import '../../domain/usecases/update_session_text.dart';
import 'dictation_event.dart';
import 'dictation_state.dart';

/// BLoC that manages the dictation feature state.
///
/// Handles recording lifecycle, transcription updates, language selection,
/// and error recovery. Depends on use cases that will be implemented
/// by another developer.
class DictationBloc extends Bloc<DictationEvent, DictationState> {
  final StartDictation _startDictation;
  final StopDictation _stopDictation;
  final GetCurrentSession _getCurrentSession;
  final UpdateSessionText _updateSessionText;

  Timer? _timer;
  StreamSubscription? _amplitudeSubscription;

  DictationBloc({
    required StartDictation startDictation,
    required StopDictation stopDictation,
    required GetCurrentSession getCurrentSession,
    required UpdateSessionText updateSessionText,
  })  : _startDictation = startDictation,
        _stopDictation = stopDictation,
        _getCurrentSession = getCurrentSession,
        _updateSessionText = updateSessionText,
        super(const DictationInitial()) {
    on<LanguageSelected>(_onLanguageSelected);
    on<StartDictationPressed>(_onStartDictation);
    on<StopDictationPressed>(_onStopDictation);
    on<PauseDictationPressed>(_onPauseDictation);
    on<ResumeDictationPressed>(_onResumeDictation);
    on<TranscriptionUpdated>(_onTranscriptionUpdated);
    on<RefinedTextUpdated>(_onRefinedTextUpdated);
    on<ToggleRefinedView>(_onToggleRefinedView);
  }

  /// Handle language selection — only allowed when idle.
  void _onLanguageSelected(
    LanguageSelected event,
    Emitter<DictationState> emit,
  ) {
    // Language cannot be changed while recording or processing
    if (state is DictationRecording || state is DictationProcessing) {
      return;
    }

    if (event.languageCode == null) {
      emit(const DictationInitial());
      return;
    }

    emit(DictationReady(selectedLanguage: event.languageCode));
  }

  /// Handle start dictation — validate and begin recording.
  Future<void> _onStartDictation(
    StartDictationPressed event,
    Emitter<DictationState> emit,
  ) async {
    if (!state.hasLanguage) {
      emit(DictationError(
        error: 'Please select a language before starting',
        previousState: state,
      ));
      // Recover after showing error
      await Future.delayed(const Duration(seconds: 3));
      emit(DictationReady(selectedLanguage: state.selectedLanguage));
      return;
    }

    final result = await _startDictation(
      StartDictationParams(languageCode: state.selectedLanguage!),
    );

    result.fold(
      (failure) => emit(DictationError(error: _mapFailure(failure), previousState: state)),
      (sessionResult) {
        emit(DictationRecording(
          sessionId: sessionResult.sessionId,
          currentText: '',
          elapsedMs: 0,
          currentAmplitude: 0.0,
          selectedLanguage: state.selectedLanguage,
        ));
        _startTimer(sessionResult.sessionId);
      },
    );
  }

  /// Handle stop dictation — finalize and process.
  Future<void> _onStopDictation(
    StopDictationPressed event,
    Emitter<DictationState> emit,
  ) async {
    if (state is! DictationRecording) return;

    final recordingState = state as DictationRecording;
    _stopTimer();

    emit(DictationProcessing(
      sessionId: recordingState.sessionId,
      currentText: recordingState.currentText,
      progress: 0.0,
      selectedLanguage: state.selectedLanguage,
    ));

    final result = await _stopDictation(
      StopDictationParams(sessionId: recordingState.sessionId),
    );

    result.fold(
      (failure) => emit(DictationError(error: _mapFailure(failure), previousState: state)),
      (stopResult) {
        emit(DictationCompleted(
          sessionId: stopResult.sessionId,
          finalText: stopResult.finalTranscription,
          refinedText: stopResult.refinedText,
          selectedLanguage: state.selectedLanguage,
        ));
      },
    );
  }

  /// Handle pause dictation — temporarily stop recording.
  Future<void> _onPauseDictation(
    PauseDictationPressed event,
    Emitter<DictationState> emit,
  ) async {
    // Pause will be implemented by another developer
    // For now, stop the timer but keep the session alive
    _stopTimer();
  }

  /// Handle resume dictation — continue recording after pause.
  Future<void> _onResumeDictation(
    ResumeDictationPressed event,
    Emitter<DictationState> emit,
  ) async {
    // Resume will be implemented by another developer
    if (state is DictationRecording) {
      final recordingState = state as DictationRecording;
      _startTimer(recordingState.sessionId);
    }
  }

  /// Handle transcription text updates from the audio processor.
  Future<void> _onTranscriptionUpdated(
    TranscriptionUpdated event,
    Emitter<DictationState> emit,
  ) async {
    if (state is DictationRecording) {
      final recordingState = state as DictationRecording;
      // Only update if the session ID matches
      if (recordingState.sessionId == event.sessionId) {
        emit(DictationRecording(
          sessionId: recordingState.sessionId,
          currentText: event.text,
          elapsedMs: recordingState.elapsedMs,
          currentAmplitude: recordingState.currentAmplitude,
          selectedLanguage: state.selectedLanguage,
        ));
      }
    } else if (state is DictationProcessing) {
      final processingState = state as DictationProcessing;
      if (processingState.sessionId == event.sessionId) {
        emit(DictationProcessing(
          sessionId: processingState.sessionId,
          currentText: event.text,
          progress: processingState.progress,
          selectedLanguage: state.selectedLanguage,
        ));
      }
    }
  }

  /// Handle refined text updates from LLM processing.
  void _onRefinedTextUpdated(
    RefinedTextUpdated event,
    Emitter<DictationState> emit,
  ) {
    if (state is DictationCompleted) {
      final completedState = state as DictationCompleted;
      emit(DictationCompleted(
        sessionId: completedState.sessionId,
        finalText: completedState.finalText,
        refinedText: event.refinedText,
        selectedLanguage: state.selectedLanguage,
      ));
    }
  }

  /// Handle toggling between raw and refined text views.
  void _onToggleRefinedView(
    ToggleRefinedView event,
    Emitter<DictationState> emit,
  ) {
    // Toggle state is managed in the UI layer via BlocBuilder's buildWhen
    // This event serves as a signal for the UI to rebuild
  }

  /// Start the elapsed time timer.
  ///
  /// Emits updated [DictationRecording] state every second with incremented
  /// [elapsedMs] and simulated amplitude for the visualizer.
  void _startTimer(String sessionId) {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state is DictationRecording) {
        final recordingState = state as DictationRecording;
        if (recordingState.sessionId == sessionId) {
          emit(DictationRecording(
            sessionId: recordingState.sessionId,
            currentText: recordingState.currentText,
            elapsedMs: recordingState.elapsedMs + 1000,
            currentAmplitude: _simulateAmplitude(),
            selectedLanguage: state.selectedLanguage,
          ));
        }
      }
    });
  }

  /// Stop the elapsed time timer.
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Simulate audio amplitude for the visualizer during recording.
  ///
  /// Returns a value between 0.15 and 0.85 that varies over time
  /// to create a realistic visualizer effect.
  double _simulateAmplitude() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = (now % 2000) / 2000.0; // 0 to 1 over 2 seconds
    final wave = math.sin(base * 2 * math.pi).abs(); // sinusoidal pattern
    return 0.15 + (wave * 0.7); // range: 0.15 to 0.85
  }

  /// Map failure types to user-friendly error messages.
  String _mapFailure(Failure failure) {
    return switch (failure) {
      PermissionFailure() => 'Microphone permission denied. Please enable it in settings.',
      AudioFailure() => 'Audio recording error: ${failure.message}',
      TranscriptionFailure() => 'Transcription failed: ${failure.message}',
      NetworkFailure() => 'Network error: ${failure.message}',
      ServerFailure() => 'Server error: ${failure.message}',
      ValidationFailure() => failure.message,
      _ => 'An unexpected error occurred: ${failure.message}',
    };
  }

  @override
  Future<void> close() {
    _stopTimer();
    _amplitudeSubscription?.cancel();
    return super.close();
  }
}
