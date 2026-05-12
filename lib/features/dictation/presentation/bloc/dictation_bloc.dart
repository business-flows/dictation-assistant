import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../services/audio_service.dart';
import '../../../../services/chunk_processor.dart';
import '../../../../services/whisper_service.dart';
import '../../domain/usecases/pause_dictation.dart';
import '../../domain/usecases/resume_dictation.dart';
import '../../domain/usecases/start_dictation.dart';
import '../../domain/usecases/stop_dictation.dart';
import 'dictation_event.dart';
import 'dictation_state.dart';

/// BLoC that manages the dictation feature state machine.
///
/// Coordinates between the UI layer and the domain layer to manage
/// the full dictation lifecycle: ready -> recording -> paused ->
/// recording -> processing -> ready.
///
/// ## State Machine:
/// ```
/// [DictationInitial] -> [DictationReady] (on init)
/// [DictationReady] -> [DictationRecording] (on StartDictation)
/// [DictationReady] -> [DictationReady] (on UpdateLanguage)
/// [DictationRecording] -> [DictationPaused] (on PauseDictation)
/// [DictationRecording] -> [DictationProcessing] (on StopDictation)
/// [DictationRecording] -> [DictationRecording] (on UpdateTranscription)
/// [DictationPaused] -> [DictationRecording] (on ResumeDictation)
/// [DictationPaused] -> [DictationProcessing] (on StopDictation)
/// [DictationProcessing] -> [DictationReady] (on complete)
/// Any -> [DictationError] (on error) -> [DictationReady] (on recovery)
/// ```
///
/// ## Amplitude Stream:
/// The BLoC subscribes to [AudioService.amplitudeStream] while recording
/// and emits [AmplitudeUpdate] events to drive the waveform visualization.
///
/// ## Transcription Stream:
/// The BLoC subscribes to [ChunkProcessor.transcriptionStream] and
/// maps incoming text to [UpdateTranscription] events.
@injectable
class DictationBloc extends Bloc<DictationEvent, DictationState> {
  final StartDictation _startDictation;
  final StopDictation _stopDictation;
  final AudioService _audioService;
  final ChunkProcessor _chunkProcessor;
  final WhisperService _whisperService;
  final Logger _logger;

  /// Subscription to audio amplitude stream.
  StreamSubscription<double>? _amplitudeSubscription;

  /// Subscription to chunk processor transcription stream.
  StreamSubscription<String>? _transcriptionSubscription;

  /// Subscription to chunk processor status stream.
  StreamSubscription<ChunkProcessingStatus>? _statusSubscription;

  /// Currently selected language code.
  String _currentLanguage = 'en';

  DictationBloc({
    required StartDictation startDictation,
    required StopDictation stopDictation,
    required AudioService audioService,
    required ChunkProcessor chunkProcessor,
    required WhisperService whisperService,
    required Logger logger,
  })  : _startDictation = startDictation,
        _stopDictation = stopDictation,
        _audioService = audioService,
        _chunkProcessor = chunkProcessor,
        _whisperService = whisperService,
        _logger = logger,
        super(const DictationInitial()) {
    // Register event handlers
    on<StartDictation>(_onStartDictation);
    on<StopDictation>(_onStopDictation);
    on<PauseDictation>(_onPauseDictation);
    on<ResumeDictation>(_onResumeDictation);
    on<UpdateTranscription>(_onUpdateTranscription);
    on<UpdateLanguage>(_onUpdateLanguage);
    on<AmplitudeUpdate>(_onAmplitudeUpdate);
    on<ProcessingStatusUpdate>(_onProcessingStatusUpdate);

    // Initialize
    _initialize();
  }

  /// Initialize the BLoC state.
  ///
  /// Checks if the whisper model is loaded and transitions to ready.
  void _initialize() {
    _logger.i('DictationBloc: Initializing');
    emit(DictationReady(
      languageCode: _currentLanguage,
      isModelLoaded: _whisperService.isModelLoaded,
    ));
  }

  // ---- Event Handlers ----

  /// Handle [StartDictation] event.
  ///
  /// Creates a new session, starts recording, and subscribes to
  /// amplitude and transcription streams.
  Future<void> _onStartDictation(
    StartDictation event,
    Emitter<DictationState> emit,
  ) async {
    _logger.i('DictationBloc: Handling StartDictation (lang: ${event.languageCode})');

    // Update language
    _currentLanguage = event.languageCode;

    // Check if model is loaded
    if (!_whisperService.isModelLoaded) {
      emit(DictationError(
        message: 'No transcription model loaded. Please download and load a model first.',
        code: 'MODEL_NOT_LOADED',
        previousState: state is DictationReady ? state : null,
      ));
      return;
    }

    // Start dictation
    final result = await _startDictation(
      StartDictationParams(languageCode: event.languageCode),
    );

    await result.fold(
      (failure) async {
        _logger.e('DictationBloc: Failed to start dictation: ${failure.message}');
        emit(DictationError(
          message: failure.message,
          code: failure.code,
          previousState: state is DictationReady ? state as DictationReady : null,
        ));

        // Return to ready state after error
        await Future.delayed(const Duration(seconds: 3));
        if (!isClosed) {
          emit(DictationReady(
            languageCode: _currentLanguage,
            isModelLoaded: _whisperService.isModelLoaded,
          ));
        }
      },
      (session) async {
        _logger.i('DictationBloc: Dictation started (session: ${session.id})');

        // Emit recording state
        emit(DictationRecording(
          session: session,
          transcriptionText: '',
          amplitude: 0.0,
          statusMessage: 'Recording...',
        ));

        // Subscribe to amplitude stream
        _subscribeToAmplitudeStream();

        // Subscribe to transcription stream
        _subscribeToTranscriptionStream(session.id);

        // Subscribe to status stream
        _subscribeToStatusStream();
      },
    );
  }

  /// Handle [StopDictation] event.
  ///
  /// Stops recording and the chunk pipeline, finalizes the session.
  Future<void> _onStopDictation(
    StopDictation event,
    Emitter<DictationState> emit,
  ) async {
    _logger.i('DictationBloc: Handling StopDictation');

    // Get current session info before we lose it
    String? sessionId;
    String lastTranscription = '';
    if (state is DictationRecording) {
      sessionId = (state as DictationRecording).session.id;
      lastTranscription = (state as DictationRecording).transcriptionText;
    } else if (state is DictationPaused) {
      sessionId = (state as DictationPaused).session.id;
      lastTranscription = (state as DictationPaused).transcriptionText;
    }

    if (sessionId == null) {
      _logger.w('DictationBloc: No active session to stop');
      emit(DictationReady(
        languageCode: _currentLanguage,
        isModelLoaded: _whisperService.isModelLoaded,
      ));
      return;
    }

    // Show processing state
    emit(DictationProcessing(
      session: (state is DictationRecording)
          ? (state as DictationRecording).session
          : (state as DictationPaused).session,
      message: 'Stopping recording...',
    ));

    // Cancel subscriptions
    await _cancelSubscriptions();

    // Stop dictation
    final result = await _stopDictation(
      StopDictationParams(sessionId: sessionId),
    );

    result.fold(
      (failure) {
        _logger.e('DictationBloc: Failed to stop dictation: ${failure.message}');
        emit(DictationError(
          message: failure.message,
          code: failure.code,
        ));
      },
      (result) {
        _logger.i('DictationBloc: Dictation stopped successfully');
      },
    );

    // Return to ready state
    emit(DictationReady(
      languageCode: _currentLanguage,
      isModelLoaded: _whisperService.isModelLoaded,
    ));
  }

  /// Handle [PauseDictation] event.
  ///
  /// Pauses recording and the chunk pipeline.
  Future<void> _onPauseDictation(
    PauseDictation event,
    Emitter<DictationState> emit,
  ) async {
    _logger.i('DictationBloc: Handling PauseDictation');

    if (state is! DictationRecording) {
      _logger.w('DictationBloc: Cannot pause - not recording');
      return;
    }

    final recordingState = state as DictationRecording;

    try {
      await _audioService.pauseRecording();

      emit(DictationPaused(
        session: recordingState.session,
        transcriptionText: recordingState.transcriptionText,
      ));

      // Cancel amplitude subscription while paused
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      _logger.i('DictationBloc: Recording paused');
    } catch (e) {
      _logger.e('DictationBloc: Failed to pause recording', error: e);
      emit(DictationError(
        message: 'Failed to pause recording: $e',
        code: 'PAUSE_FAILED',
        previousState: recordingState,
      ));
    }
  }

  /// Handle [ResumeDictation] event.
  ///
  /// Resumes a paused recording session.
  Future<void> _onResumeDictation(
    ResumeDictation event,
    Emitter<DictationState> emit,
  ) async {
    _logger.i('DictationBloc: Handling ResumeDictation');

    if (state is! DictationPaused) {
      _logger.w('DictationBloc: Cannot resume - not paused');
      return;
    }

    final pausedState = state as DictationPaused;

    try {
      await _audioService.resumeRecording();

      emit(DictationRecording(
        session: pausedState.session,
        transcriptionText: pausedState.transcriptionText,
        amplitude: 0.0,
        statusMessage: 'Recording...',
      ));

      // Re-subscribe to amplitude stream
      _subscribeToAmplitudeStream();

      _logger.i('DictationBloc: Recording resumed');
    } catch (e) {
      _logger.e('DictationBloc: Failed to resume recording', error: e);
      emit(DictationError(
        message: 'Failed to resume recording: $e',
        code: 'RESUME_FAILED',
        previousState: pausedState,
      ));
    }
  }

  /// Handle [UpdateTranscription] event.
  ///
  /// Updates the accumulated transcription text in the recording state.
  Future<void> _onUpdateTranscription(
    UpdateTranscription event,
    Emitter<DictationState> emit,
  ) async {
    if (state is DictationRecording) {
      final current = state as DictationRecording;
      emit(current.copyWith(transcriptionText: event.text));
    } else if (state is DictationPaused) {
      final current = state as DictationPaused;
      emit(current.copyWith(transcriptionText: event.text));
    }
  }

  /// Handle [UpdateLanguage] event.
  ///
  /// Updates the selected language code (only effective before recording).
  Future<void> _onUpdateLanguage(
    UpdateLanguage event,
    Emitter<DictationState> emit,
  ) async {
    _currentLanguage = event.languageCode;

    if (state is DictationReady) {
      emit((state as DictationReady).copyWith(languageCode: event.languageCode));
    }
  }

  /// Handle [AmplitudeUpdate] event.
  ///
  /// Updates the amplitude in the recording state for waveform visualization.
  Future<void> _onAmplitudeUpdate(
    AmplitudeUpdate event,
    Emitter<DictationState> emit,
  ) async {
    if (state is DictationRecording) {
      emit((state as DictationRecording).copyWith(amplitude: event.amplitude));
    }
  }

  /// Handle [ProcessingStatusUpdate] event.
  ///
  /// Updates the status message in the recording state.
  Future<void> _onProcessingStatusUpdate(
    ProcessingStatusUpdate event,
    Emitter<DictationState> emit,
  ) async {
    if (state is DictationRecording) {
      emit((state as DictationRecording).copyWith(statusMessage: event.status));
    }
  }

  // ---- Stream Subscriptions ----

  /// Subscribe to the audio amplitude stream.
  ///
  /// Maps amplitude values to [AmplitudeUpdate] events while recording.
  void _subscribeToAmplitudeStream() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _audioService.amplitudeStream.listen(
      (amplitude) {
        if (!isClosed) {
          add(AmplitudeUpdate(amplitude));
        }
      },
      onError: (Object e) {
        _logger.w('DictationBloc: Amplitude stream error: $e');
      },
    );
  }

  /// Subscribe to the chunk processor transcription stream.
  ///
  /// Maps transcription text to [UpdateTranscription] events.
  void _subscribeToTranscriptionStream(String sessionId) {
    _transcriptionSubscription?.cancel();
    _transcriptionSubscription = _chunkProcessor.transcriptionStream.listen(
      (text) {
        if (!isClosed) {
          add(UpdateTranscription(text));
        }
      },
      onError: (Object e) {
        _logger.w('DictationBloc: Transcription stream error: $e');
      },
    );
  }

  /// Subscribe to the chunk processor status stream.
  ///
  /// Maps status changes to [ProcessingStatusUpdate] events.
  void _subscribeToStatusStream() {
    _statusSubscription?.cancel();
    _statusSubscription = _chunkProcessor.statusStream.listen(
      (status) {
        if (!isClosed) {
          final message = _statusToMessage(status);
          add(ProcessingStatusUpdate(message));
        }
      },
      onError: (Object e) {
        _logger.w('DictationBloc: Status stream error: $e');
      },
    );
  }

  /// Convert a [ChunkProcessingStatus] to a human-readable message.
  String _statusToMessage(ChunkProcessingStatus status) {
    switch (status) {
      case ChunkProcessingStatus.idle:
        return 'Ready';
      case ChunkProcessingStatus.running:
        return 'Recording...';
      case ChunkProcessingStatus.transcribing:
        return 'Transcribing...';
      case ChunkProcessingStatus.chunkCompleted:
        return 'Chunk completed';
      case ChunkProcessingStatus.chunkError:
        return 'Chunk error - continuing...';
      case ChunkProcessingStatus.stopping:
        return 'Stopping...';
    }
  }

  /// Cancel all stream subscriptions.
  Future<void> _cancelSubscriptions() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    await _transcriptionSubscription?.cancel();
    _transcriptionSubscription = null;

    await _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  @override
  Future<void> close() async {
    _logger.i('DictationBloc: Closing');
    await _cancelSubscriptions();
    return super.close();
  }
}
