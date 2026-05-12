import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../core/constants/app_constants.dart';
import '../core/constants/audio_constants.dart';
import '../core/utils/audio_file_naming.dart';
import '../core/utils/pcm_utils.dart';
import '../core/utils/ulid_generator.dart';
import 'app_database.dart';
import 'audio_service.dart';
import 'whisper_service.dart';

/// Processing status for the chunk transcription pipeline.
///
/// Emitted via [ChunkProcessor.statusStream] to provide visibility
/// into the pipeline's internal state.
enum ChunkProcessingStatus {
  /// Pipeline is idle, no active processing.
  idle,

  /// Pipeline is actively recording and chunking audio.
  running,

  /// Transcription of a chunk is in progress.
  transcribing,

  /// A chunk was successfully transcribed.
  chunkCompleted,

  /// A chunk transcription failed but pipeline continues.
  chunkError,

  /// Pipeline is stopping (draining queue).
  stopping,
}

/// A single transcription task in the processing queue.
///
/// Contains all metadata needed to transcribe a chunk and persist
/// the result to the database.
class _TranscriptionTask {
  final String chunkId;
  final String sessionId;
  final int chunkIndex;
  final Uint8List audioData;
  final int startTimeMs;
  final int endTimeMs;
  final String? language;

  _TranscriptionTask({
    required this.chunkId,
    required this.sessionId,
    required this.chunkIndex,
    required this.audioData,
    required this.startTimeMs,
    required this.endTimeMs,
    this.language,
  });
}

/// Result of a completed transcription task.
class _TranscriptionResult {
  final String chunkId;
  final String sessionId;
  final int chunkIndex;
  final String transcription;
  final bool success;
  final String? error;

  _TranscriptionResult({
    required this.chunkId,
    required this.sessionId,
    required this.chunkIndex,
    required this.transcription,
    required this.success,
    this.error,
  });
}

/// Core engine that manages the real-time audio chunking and transcription pipeline.
///
/// The [ChunkProcessor] orchestrates the flow from raw audio recording to
/// transcribed text chunks. It maintains a circular buffer of audio samples,
/// extracts chunks every ~3 seconds with overlap, and queues them for
/// transcription via [WhisperService].
///
/// ## Pipeline Flow
/// 1. Audio is recorded continuously via [AudioService].
/// 2. Raw PCM data is accumulated in a circular buffer.
/// 3. Every [chunkSampleCount] samples, a chunk is extracted.
/// 4. Each new chunk includes [overlapSampleCount] samples from the previous chunk.
/// 5. Chunks are queued for transcription with max [maxConcurrentTranscriptions].
/// 6. Results are persisted to the database and emitted as text updates.
///
/// ## Overlap Strategy
/// The 0.5s overlap ensures no words are lost at chunk boundaries. When
/// reconstructing the full transcription, overlapping regions should be
/// deduplicated.
///
/// Usage:
/// ```dart
/// final processor = ChunkProcessor(
///   audioService: audioService,
///   whisperService: whisperService,
///   database: database,
/// );
/// await processor.startPipeline('session-id', 'en');
/// processor.transcriptionStream.listen((text) => print(text));
/// await processor.stopPipeline();
/// ```
@singleton
class ChunkProcessor {
  ChunkProcessor({
    required AudioService audioService,
    required WhisperService whisperService,
    required AppDatabase database,
    Logger? logger,
  })  : _audioService = audioService,
        _whisperService = whisperService,
        _database = database,
        _logger = logger ?? Logger();

  // -- Dependencies --
  final AudioService _audioService;
  final WhisperService _whisperService;
  final AppDatabase _database;
  final Logger _logger;

  // -- Stream controllers --
  final StreamController<String> _transcriptionController =
      StreamController<String>.broadcast();
  final StreamController<ChunkProcessingStatus> _statusController =
      StreamController<ChunkProcessingStatus>.broadcast();

  /// Controller for buffering incoming PCM audio bytes.
  final StreamController<Uint8List> _audioBufferController =
      StreamController<Uint8List>.broadcast();

  // -- Pipeline state --
  bool _isRunning = false;
  String? _sessionId;
  String? _languageCode;
  int _currentChunkIndex = 0;
  int _elapsedTimeMs = 0;

  /// Accumulated full transcription text.
  final StringBuffer _accumulatedText = StringBuffer();

  /// Previous chunk's raw PCM data for overlap.
  Uint8List? _previousChunkData;

  /// Subscription to audio buffer stream.
  StreamSubscription<Uint8List>? _audioSubscription;

  /// Active transcription workers (max 2).
  final List<Future<void>> _activeTranscriptions = [];

  /// Pending transcription queue.
  final Queue<_TranscriptionTask> _pendingQueue = Queue<_TranscriptionTask>();

  /// Whether the pipeline is shutting down.
  bool _isShuttingDown = false;

  /// Number of samples accumulated since last chunk extraction.
  final BytesBuilder _sampleAccumulator = BytesBuilder();

  // -- Configuration --
  /// Number of bytes per chunk (48000 samples * 2 bytes = 96000 bytes).
  static int get _chunkBytes => AudioConstants.chunkBytes;

  /// Number of bytes for overlap (8000 samples * 2 bytes = 16000 bytes).
  static int get _overlapBytes => AudioConstants.overlapBytes;

  /// Maximum concurrent transcription jobs.
  static const int _maxConcurrentTranscriptions = AppConstants.maxConcurrentTranscriptions;

  // -- Public API --

  /// Stream of accumulated transcription text updates.
  ///
  /// Emits the full accumulated text each time a new chunk is transcribed.
  /// Consumers should listen to this stream to display real-time transcription.
  Stream<String> get transcriptionStream => _transcriptionController.stream;

  /// Stream of pipeline status updates.
  ///
  /// Emits [ChunkProcessingStatus] values to track the pipeline lifecycle.
  Stream<ChunkProcessingStatus> get statusStream => _statusController.stream;

  /// Whether the pipeline is currently running.
  bool get isRunning => _isRunning;

  /// The active session ID, or null if the pipeline is not running.
  String? get sessionId => _sessionId;

  /// Feed raw PCM audio data into the chunk processor.
  ///
  /// Call this from the audio recording callback to push PCM data
  /// into the processing pipeline. The data will be buffered and
  /// chunked according to the configured parameters.
  void feedAudioData(Uint8List pcmData) {
    if (!_isRunning || _isShuttingDown) return;
    if (pcmData.isEmpty) return;

    _audioBufferController.add(pcmData);
  }

  /// Start the chunk processing pipeline for a session.
  ///
  /// Initializes all state, subscribes to the audio buffer stream,
  /// and begins accumulating samples for chunk extraction.
  ///
  /// [sessionId] - The ULID of the active dictation session.
  /// [languageCode] - The language code for transcription ('en', 'fr', 'ar').
  ///
  /// Throws if the pipeline is already running.
  Future<void> startPipeline(String sessionId, String languageCode) async {
    if (_isRunning) {
      _logger.w('ChunkProcessor: Pipeline already running for session $_sessionId');
      return;
    }

    _logger.i('ChunkProcessor: Starting pipeline for session $sessionId, language: $languageCode');

    _isRunning = true;
    _isShuttingDown = false;
    _sessionId = sessionId;
    _languageCode = languageCode;
    _currentChunkIndex = 0;
    _elapsedTimeMs = 0;
    _accumulatedText.clear();
    _previousChunkData = null;
    _sampleAccumulator.clear();
    _pendingQueue.clear();
    _activeTranscriptions.clear();

    _emitStatus(ChunkProcessingStatus.running);

    // Subscribe to audio buffer stream
    _audioSubscription = _audioBufferController.stream.listen(
      _onAudioData,
      onError: (Object e, StackTrace st) {
        _logger.e('ChunkProcessor: Audio stream error', error: e, stackTrace: st);
      },
    );

    // Subscribe to amplitude stream for potential VAD integration
    _audioService.amplitudeStream.listen(
      (amplitude) {
        // Future: implement voice activity detection
      },
      onError: (Object e) {
        _logger.w('ChunkProcessor: Amplitude stream error: $e');
      },
    );
  }

  /// Stop the pipeline gracefully.
  ///
  /// Waits for pending transcriptions to complete, emits the final status,
  /// and cleans up subscriptions. Any remaining audio in the accumulator
  /// is processed as a final chunk if it meets the minimum size threshold.
  Future<void> stopPipeline() async {
    if (!_isRunning) return;

    _logger.i('ChunkProcessor: Stopping pipeline');
    _isShuttingDown = true;
    _emitStatus(ChunkProcessingStatus.stopping);

    // Cancel audio subscription
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    // Process any remaining audio in accumulator (if enough data)
    final remaining = _sampleAccumulator.toBytes();
    if (remaining.length >= _overlapBytes * 2) {
      _logger.d('ChunkProcessor: Processing final partial chunk (${remaining.length} bytes)');
      _extractAndQueueChunk(remaining, isFinal: true);
    }

    // Wait for all active transcriptions to complete
    await Future.wait(_activeTranscriptions);

    // Process any remaining queue items
    await _drainQueue();

    _isRunning = false;
    _sessionId = null;
    _emitStatus(ChunkProcessingStatus.idle);

    _logger.i('ChunkProcessor: Pipeline stopped');
  }

  /// Dispose all resources.
  ///
  /// Stops the pipeline if running and closes all stream controllers.
  Future<void> dispose() async {
    await stopPipeline();

    if (!_transcriptionController.isClosed) {
      await _transcriptionController.close();
    }
    if (!_statusController.isClosed) {
      await _statusController.close();
    }
    if (!_audioBufferController.isClosed) {
      await _audioBufferController.close();
    }
  }

  // -- Private handlers --

  /// Handle incoming audio data from the buffer stream.
  void _onAudioData(Uint8List pcmData) {
    try {
      _sampleAccumulator.add(pcmData);

      // Extract chunks whenever we have enough data
      while (_sampleAccumulator.length >= _chunkBytes && !_isShuttingDown) {
        final allData = _sampleAccumulator.toBytes();
        final chunkData = Uint8List.sublistView(allData, 0, _chunkBytes);
        final remainder = Uint8List.sublistView(allData, _chunkBytes);

        _sampleAccumulator.clear();
        if (remainder.isNotEmpty) {
          _sampleAccumulator.add(remainder);
        }

        _extractAndQueueChunk(chunkData);
      }

      // Update elapsed time
      _elapsedTimeMs += (pcmData.length ~/ AudioConstants.blockAlign) *
          1000 ~/
          AudioConstants.sampleRate;
    } catch (e, stackTrace) {
      _logger.e('ChunkProcessor: Error processing audio data', error: e, stackTrace: stackTrace);
      _emitStatus(ChunkProcessingStatus.chunkError);
    }
  }

  /// Extract a chunk with overlap and queue it for transcription.
  void _extractAndQueueChunk(Uint8List chunkData, {bool isFinal = false}) {
    try {
      final sessionId = _sessionId!;
      final chunkIndex = _currentChunkIndex++;

      // Apply overlap: prepend last 8000 samples from previous chunk
      Uint8List finalChunkData;
      if (_previousChunkData != null && !isFinal) {
        final overlap = Uint8List.sublistView(
          _previousChunkData!,
          (_previousChunkData!.length - _overlapBytes).clamp(0, _previousChunkData!.length),
        );
        final combined = Uint8List(overlap.length + chunkData.length);
        combined.setRange(0, overlap.length, overlap);
        combined.setRange(overlap.length, combined.length, chunkData);
        finalChunkData = combined;
      } else {
        finalChunkData = chunkData;
      }

      // Store current chunk data for next overlap
      _previousChunkData = Uint8List.fromList(chunkData);

      // Calculate timing
      final startTimeMs = _elapsedTimeMs -
          ((chunkData.length ~/ AudioConstants.blockAlign) * 1000 ~/
              AudioConstants.sampleRate);
      final endTimeMs = _elapsedTimeMs;

      // Save chunk audio to file
      final chunkFilePath = AudioFileNaming.chunkWavPath(sessionId, chunkIndex);
      final chunkId = UlidGenerator.generate();

      _saveChunkAudio(chunkFilePath, finalChunkData);

      // Insert chunk record into database
      _database.insertChunk(
        AudioChunksCompanion.insert(
          id: Value(chunkId),
          sessionId: Value(sessionId),
          chunkIndex: Value(chunkIndex),
          filePath: Value(chunkFilePath),
          startTimeMs: Value(startTimeMs),
          endTimeMs: Value(endTimeMs),
          status: const Value(1), // processing
        ),
      );

      // Create transcription task
      final task = _TranscriptionTask(
        chunkId: chunkId,
        sessionId: sessionId,
        chunkIndex: chunkIndex,
        audioData: finalChunkData,
        startTimeMs: startTimeMs,
        endTimeMs: endTimeMs,
        language: _languageCode,
      );

      _pendingQueue.add(task);
      _processQueue();

      _logger.d('ChunkProcessor: Queued chunk $chunkIndex (${finalChunkData.length} bytes)');
    } catch (e, stackTrace) {
      _logger.e('ChunkProcessor: Error extracting chunk', error: e, stackTrace: stackTrace);
      _emitStatus(ChunkProcessingStatus.chunkError);
    }
  }

  /// Save chunk audio data to a WAV file.
  Future<void> _saveChunkAudio(String filePath, Uint8List pcmData) async {
    try {
      final file = File(filePath);
      final dir = Directory(p.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final wavData = PcmUtils.pcmToWav(pcmData);
      await file.writeAsBytes(wavData);
    } catch (e, stackTrace) {
      _logger.e('ChunkProcessor: Failed to save chunk audio', error: e, stackTrace: stackTrace);
    }
  }

  /// Process the transcription queue, respecting concurrency limits.
  void _processQueue() {
    while (_activeTranscriptions.length < _maxConcurrentTranscriptions &&
        _pendingQueue.isNotEmpty &&
        !_isShuttingDown) {
      final task = _pendingQueue.removeFirst();
      final future = _transcribeChunk(task);
      _activeTranscriptions.add(future);

      // Remove from active list when done
      future.whenComplete(() {
        _activeTranscriptions.remove(future);
        // Continue processing queue
        _processQueue();
      });
    }
  }

  /// Transcribe a single chunk and handle the result.
  Future<void> _transcribeChunk(_TranscriptionTask task) async {
    try {
      _emitStatus(ChunkProcessingStatus.transcribing);

      // Ensure whisper model is loaded
      if (!_whisperService.isModelLoaded) {
        throw Exception('Whisper model not loaded');
      }

      _logger.d('ChunkProcessor: Transcribing chunk ${task.chunkIndex}');

      final text = await _whisperService.transcribe(
        task.audioData,
        language: task.language,
      );

      // Update chunk in database
      await _database.updateChunkTranscription(
        task.chunkId,
        text,
        null, // confidence - could be computed from whisper
      );

      // Append to accumulated text
      if (text.trim().isNotEmpty) {
        if (_accumulatedText.isNotEmpty) {
          _accumulatedText.write(' ');
        }
        _accumulatedText.write(text.trim());

        // Update session transcription text
        await _database.updateSessionText(
          task.sessionId,
          _accumulatedText.toString(),
        );

        // Emit update
        if (!_transcriptionController.isClosed) {
          _transcriptionController.add(_accumulatedText.toString());
        }
      }

      _logger.d('ChunkProcessor: Chunk ${task.chunkIndex} done: "$text"');
      _emitStatus(ChunkProcessingStatus.chunkCompleted);
    } catch (e, stackTrace) {
      _logger.e(
        'ChunkProcessor: Chunk ${task.chunkIndex} transcription failed',
        error: e,
        stackTrace: stackTrace,
      );

      // Update chunk status to error
      await _database.updateChunkStatus(task.chunkId, ChunkStatus.error);

      _emitStatus(ChunkProcessingStatus.chunkError);
    }
  }

  /// Drain the pending transcription queue, processing all remaining items.
  Future<void> _drainQueue() async {
    while (_pendingQueue.isNotEmpty) {
      final task = _pendingQueue.removeFirst();
      await _transcribeChunk(task);
    }
  }

  /// Emit a status update to the status stream.
  void _emitStatus(ChunkProcessingStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
}
