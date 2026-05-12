import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/usecases/accept_or_discard_refinement.dart';
import '../../domain/usecases/stream_refinement.dart';
import 'refinement_event.dart';
import 'refinement_state.dart';

/// BLoC that manages the text refinement lifecycle.
///
/// Coordinates between the UI and the domain layer to:
/// - Start streaming refinement from the LLM
/// - Accumulate partial tokens and emit updated state
/// - Handle accept/discard actions and persist results
///
/// Usage:
/// ```dart
/// BlocProvider(
///   create: (context) => RefinementBloc(
///     streamRefinement: getIt<StreamRefinement>(),
///     acceptRefinement: getIt<AcceptRefinement>(),
///     discardRefinement: getIt<DiscardRefinement>(),
///   ),
///   child: RefinementPreviewPage(...),
/// )
/// ```
class RefinementBloc extends Bloc<RefinementEvent, RefinementState> {
  final StreamRefinement _streamRefinement;
  final AcceptRefinement _acceptRefinement;
  final DiscardRefinement _discardRefinement;
  final Logger _logger;

  /// Subscription to the active token stream.
  StreamSubscription<Either<Failure, String>>? _streamSubscription;

  /// Current accumulated refined text during streaming.
  final StringBuffer _accumulatedBuffer = StringBuffer();

  RefinementBloc({
    required StreamRefinement streamRefinement,
    required AcceptRefinement acceptRefinement,
    required DiscardRefinement discardRefinement,
    Logger? logger,
  })  : _streamRefinement = streamRefinement,
        _acceptRefinement = acceptRefinement,
        _discardRefinement = discardRefinement,
        _logger = logger ?? Logger(),
        super(const RefinementIdle()) {
    on<StartRefinement>(_onStartRefinement);
    on<CancelRefinement>(_onCancelRefinement);
    on<AcceptRefinement>(_onAcceptRefinement);
    on<DiscardRefinement>(_onDiscardRefinement);
    on<RegenerateRefinement>(_onRegenerateRefinement);

    // Internal events for stream handling
    on<_StreamTokenEvent>(_onStreamToken);
    on<_StreamCompleteEvent>(_onStreamComplete);
    on<_StreamErrorEvent>(_onStreamError);
  }

  /// Handles [StartRefinement] event by initiating the LLM stream.
  Future<void> _onStartRefinement(
    StartRefinement event,
    Emitter<RefinementState> emit,
  ) async {
    // Cancel any existing stream
    await _cancelActiveStream();
    _accumulatedBuffer.clear();

    _logger.i('Starting refinement for session ${event.sessionId}');

    emit(RefinementInProgress(
      originalText: event.text,
      accumulatedText: '',
      sessionId: event.sessionId,
      isStreaming: true,
    ));

    final streamResult = await _streamRefinement(StreamRefinementParams(
      text: event.text,
      languageCode: event.languageCode,
      customPrompt: event.customPrompt,
    ));

    await streamResult.fold(
      (failure) async {
        _logger.w('Failed to start refinement stream: ${failure.message}');
        emit(RefinementError(
          originalText: event.text,
          errorMessage: failure.message,
          errorCode: failure.code,
        ));
      },
      (tokenStream) async {
        _streamSubscription = tokenStream.listen(
          (result) {
            result.fold(
              (failure) => add(_StreamErrorEvent(failure, event.text)),
              (token) => add(_StreamTokenEvent(token)),
            );
          },
          onDone: () {
            add(_StreamCompleteEvent(event.sessionId, event.text));
          },
          onError: (error) {
            add(_StreamErrorEvent(
              UnexpectedFailure('Stream error: $error'),
              event.text,
            ));
          },
        );
      },
    );
  }

  /// Handles token arrivals from the stream.
  Future<void> _onStreamToken(
    _StreamTokenEvent event,
    Emitter<RefinementState> emit,
  ) async {
    _accumulatedBuffer.write(event.token);

    if (state is RefinementInProgress) {
      final current = state as RefinementInProgress;
      emit(current.copyWith(
        accumulatedText: _accumulatedBuffer.toString(),
      ));
    }
  }

  /// Handles stream completion.
  Future<void> _onStreamComplete(
    _StreamCompleteEvent event,
    Emitter<RefinementState> emit,
  ) async {
    _logger.i('Refinement stream completed');

    emit(RefinementCompleted(
      originalText: event.originalText,
      refinedText: _accumulatedBuffer.toString(),
      sessionId: event.sessionId,
    ));
  }

  /// Handles stream errors.
  Future<void> _onStreamError(
    _StreamErrorEvent event,
    Emitter<RefinementState> emit,
  ) async {
    _logger.e('Refinement stream error: ${event.failure.message}');

    emit(RefinementError(
      originalText: event.originalText,
      errorMessage: event.failure.message,
      errorCode: event.failure.code,
    ));
  }

  /// Handles [CancelRefinement] event.
  Future<void> _onCancelRefinement(
    CancelRefinement event,
    Emitter<RefinementState> emit,
  ) async {
    await _cancelActiveStream();
    _accumulatedBuffer.clear();
    emit(const RefinementIdle());
    _logger.i('Refinement cancelled');
  }

  /// Handles [AcceptRefinement] event.
  Future<void> _onAcceptRefinement(
    AcceptRefinement event,
    Emitter<RefinementState> emit,
  ) async {
    emit(RefinementAccepted(
      sessionId: event.sessionId,
      refinedText: event.refinedText,
    ));

    final result = await _acceptRefinement(AcceptRefinementParams(
      sessionId: event.sessionId,
      refinedText: event.refinedText,
    ));

    result.fold(
      (failure) {
        _logger.e('Failed to accept refinement: ${failure.message}');
        // Stay in accepted state; the save failure is logged but not shown to user
        // The refined text is already in the UI state
      },
      (_) {
        _logger.i('Refinement accepted for session ${event.sessionId}');
      },
    );
  }

  /// Handles [DiscardRefinement] event.
  Future<void> _onDiscardRefinement(
    DiscardRefinement event,
    Emitter<RefinementState> emit,
  ) async {
    emit(RefinementDiscarded(sessionId: event.sessionId));

    final result = await _discardRefinement(DiscardRefinementParams(
      sessionId: event.sessionId,
    ));

    result.fold(
      (failure) {
        _logger.e('Failed to discard refinement: ${failure.message}');
      },
      (_) {
        _logger.i('Refinement discarded for session ${event.sessionId}');
      },
    );
  }

  /// Handles [RegenerateRefinement] by restarting the stream.
  Future<void> _onRegenerateRefinement(
    RegenerateRefinement event,
    Emitter<RefinementState> emit,
  ) async {
    await _cancelActiveStream();
    _accumulatedBuffer.clear();

    // Re-emit as StartRefinement to reuse the same logic
    add(StartRefinement(
      sessionId: event.sessionId,
      text: event.text,
      languageCode: event.languageCode,
    ));
  }

  /// Cancels the active stream subscription if any.
  Future<void> _cancelActiveStream() async {
    if (_streamSubscription != null) {
      await _streamSubscription!.cancel();
      _streamSubscription = null;
    }
  }

  @override
  Future<void> close() async {
    await _cancelActiveStream();
    return super.close();
  }
}

// ---- Internal events for stream handling ----

/// Internal event: new token arrived from stream.
class _StreamTokenEvent extends RefinementEvent {
  final String token;
  const _StreamTokenEvent(this.token);
  @override
  List<Object?> get props => [token];
}

/// Internal event: stream completed.
class _StreamCompleteEvent extends RefinementEvent {
  final String sessionId;
  final String originalText;
  const _StreamCompleteEvent(this.sessionId, this.originalText);
  @override
  List<Object?> get props => [sessionId, originalText];
}

/// Internal event: stream error occurred.
class _StreamErrorEvent extends RefinementEvent {
  final Failure failure;
  final String originalText;
  const _StreamErrorEvent(this.failure, this.originalText);
  @override
  List<Object?> get props => [failure, originalText];
}
