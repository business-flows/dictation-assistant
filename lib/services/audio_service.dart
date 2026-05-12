import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../core/constants/audio_constants.dart';
import '../core/errors/exceptions.dart';
import '../core/utils/pcm_utils.dart';

/// Abstract interface for cross-platform audio recording.
///
/// Provides a unified API for starting, pausing, resuming, and stopping
/// audio recordings with PCM16 output at 16kHz mono - the optimal format
/// for whisper.cpp transcription.
///
/// Implementations handle platform-specific permission management and
/// audio encoder configuration.
abstract class AudioService {
  /// Stream of normalized audio amplitude values in range [0.0, 1.0].
  ///
  /// Emits a new value approximately every 100ms while recording.
  /// Useful for real-time audio visualization (waveforms, level meters).
  Stream<double> get amplitudeStream;

  /// Whether recording is currently active and capturing audio.
  bool get isRecording;

  /// Whether recording is paused (not stopped, can be resumed).
  bool get isPaused;

  /// Path to the currently active recording file, or null if not recording.
  String? get currentOutputPath;

  /// Start recording to the specified file path (WAV format).
  ///
  /// [outputPath] - Absolute path where the WAV file will be saved.
  /// [languageCode] - Optional language hint for future encoder optimizations.
  ///
  /// Throws [PermissionException] if microphone permission is denied.
  /// Throws [AudioRecordingException] if the recorder fails to start.
  Future<void> startRecording({required String outputPath, String? languageCode});

  /// Pause the current recording without finalizing the file.
  ///
  /// The recording can be resumed later without creating a new file.
  /// Throws if not currently recording.
  Future<void> pauseRecording();

  /// Resume a previously paused recording.
  ///
  /// Continues appending to the same output file.
  /// Throws if not currently paused.
  Future<void> resumeRecording();

  /// Stop recording and finalize the audio file.
  ///
  /// Returns the path to the finalized WAV file, or null if no recording
  /// was in progress.
  ///
  /// The WAV file is created by wrapping the raw PCM data with a proper
  /// WAV header using [PcmUtils.pcmToWav].
  Future<String?> stopRecording();

  /// Dispose all resources (streams, timer, recorder).
  ///
  /// Call this when the service is no longer needed (e.g., app shutdown).
  Future<void> dispose();
}

/// Processing status for chunk transcription pipeline.
///
/// Used by [ChunkProcessor] to communicate its internal state.
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

/// Concrete implementation of [AudioService] using the `record` package.
///
/// Records audio at 16kHz, 16-bit, mono PCM - the ideal format for
/// whisper.cpp transcription. The raw PCM data is wrapped in a WAV
/// container on stop for maximum compatibility.
///
/// Amplitude monitoring is implemented via a periodic timer polling
/// [AudioRecorder.getAmplitude()] and normalizing to [0.0, 1.0].
@singleton
class AudioServiceImpl implements AudioService {
  final Logger _logger;
  final AudioRecorder _recorder;

  /// Controller for amplitude stream broadcasting.
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  /// Timer for periodic amplitude polling.
  Timer? _amplitudeTimer;

  /// Internal state tracking.
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentOutputPath;
  String? _pcmOutputPath;

  /// Maximum amplitude value for normalization (empirically determined).
  static const double _maxAmplitudeDb = 0.0;
  static const double _minAmplitudeDb = -50.0;

  /// Recording configuration optimized for whisper.cpp.
  ///
  /// PCM 16-bit at 16kHz mono is the recommended format for whisper.cpp
  /// as it matches the model's training data format exactly.
  static final RecordConfig _recordConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: AudioConstants.sampleRate,
    numChannels: AudioConstants.channelCount,
    bitRate: AudioConstants.byteRate * 8,
  );

  /// Creates the audio service with injected dependencies.
  AudioServiceImpl({
    required Logger logger,
    AudioRecorder? recorder,
  })  : _logger = logger,
        _recorder = recorder ?? AudioRecorder();

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isPaused => _isPaused;

  @override
  String? get currentOutputPath => _currentOutputPath;

  @override
  Future<void> startRecording({
    required String outputPath,
    String? languageCode,
  }) async {
    try {
      if (_isRecording) {
        _logger.w('AudioService: Recording already in progress');
        return;
      }

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _logger.e('AudioService: Microphone permission denied');
        throw const PermissionException(
          'Microphone permission is required for recording. '
          'Please grant microphone access in your system settings.',
          code: 'MIC_PERMISSION_DENIED',
        );
      }

      // Ensure output directory exists
      final dir = Directory(p.dirname(outputPath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // We write raw PCM first, then wrap to WAV on stop
      _pcmOutputPath = '$outputPath.pcm';
      _currentOutputPath = outputPath;

      // Delete existing temp PCM file if it exists
      final pcmFile = File(_pcmOutputPath!);
      if (await pcmFile.exists()) {
        await pcmFile.delete();
      }

      await _recorder.start(_recordConfig, path: _pcmOutputPath!);
      _isRecording = true;
      _isPaused = false;

      _logger.i('AudioService: Started recording to $_pcmOutputPath');

      // Start amplitude polling
      _startAmplitudePolling();
    } catch (e, stackTrace) {
      _logger.e('AudioService: Failed to start recording', error: e, stackTrace: stackTrace);
      if (e is PermissionException) rethrow;
      throw AudioRecordingException(
        'Failed to start audio recording: ${e.toString()}',
        code: 'RECORD_START_FAILED',
      );
    }
  }

  @override
  Future<void> pauseRecording() async {
    try {
      if (!_isRecording || _isPaused) {
        _logger.w('AudioService: Cannot pause - not recording or already paused');
        return;
      }

      await _recorder.pause();
      _isPaused = true;
      _stopAmplitudePolling();

      _logger.i('AudioService: Recording paused');
    } catch (e, stackTrace) {
      _logger.e('AudioService: Failed to pause recording', error: e, stackTrace: stackTrace);
      throw AudioRecordingException(
        'Failed to pause recording: ${e.toString()}',
        code: 'RECORD_PAUSE_FAILED',
      );
    }
  }

  @override
  Future<void> resumeRecording() async {
    try {
      if (!_isPaused) {
        _logger.w('AudioService: Cannot resume - not paused');
        return;
      }

      await _recorder.resume();
      _isPaused = false;
      _startAmplitudePolling();

      _logger.i('AudioService: Recording resumed');
    } catch (e, stackTrace) {
      _logger.e('AudioService: Failed to resume recording', error: e, stackTrace: stackTrace);
      throw AudioRecordingException(
        'Failed to resume recording: ${e.toString()}',
        code: 'RECORD_RESUME_FAILED',
      );
    }
  }

  @override
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        _logger.w('AudioService: Cannot stop - not recording');
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;
      _isPaused = false;
      _stopAmplitudePolling();

      // Emit final zero amplitude
      if (!_amplitudeController.isClosed) {
        _amplitudeController.add(0.0);
      }

      _logger.i('AudioService: Recording stopped, raw PCM at $path');

      // Convert PCM to WAV
      if (_pcmOutputPath != null) {
        final pcmFile = File(_pcmOutputPath!);
        if (await pcmFile.exists()) {
          final pcmData = await pcmFile.readAsBytes();
          final wavData = PcmUtils.pcmToWav(pcmData);
          await File(_currentOutputPath!).writeAsBytes(wavData);
          await pcmFile.delete();
          _logger.i('AudioService: WAV file written to $_currentOutputPath');
          return _currentOutputPath;
        }
      }

      return path;
    } catch (e, stackTrace) {
      _logger.e('AudioService: Failed to stop recording', error: e, stackTrace: stackTrace);
      throw AudioRecordingException(
        'Failed to stop recording: ${e.toString()}',
        code: 'RECORD_STOP_FAILED',
      );
    } finally {
      _pcmOutputPath = null;
    }
  }

  @override
  Future<void> dispose() async {
    _logger.i('AudioService: Disposing resources');
    _stopAmplitudePolling();
    if (_amplitudeController.isClosed == false) {
      await _amplitudeController.close();
    }
    await _recorder.dispose();
  }

  /// Start the amplitude polling timer.
  ///
  /// Polls the recorder's current amplitude every 100ms and normalizes
  /// the dB value to [0.0, 1.0] for visualization purposes.
  void _startAmplitudePolling() {
    _stopAmplitudePolling();
    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: AudioConstants.amplitudeUpdateIntervalMs),
      (_) async {
        try {
          if (!_isRecording || _isPaused) return;

          final amp = await _recorder.getAmplitude();
          // Normalize dB to [0.0, 1.0]
          final normalized = _normalizeAmplitude(amp.current);
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(normalized);
          }
        } catch (e) {
          // Silently handle amplitude read errors
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(0.0);
          }
        }
      },
    );
  }

  /// Stop the amplitude polling timer.
  void _stopAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }

  /// Normalize a decibel amplitude value to [0.0, 1.0].
  ///
  /// Maps the range [-50dB, 0dB] linearly to [0.0, 1.0].
  /// Values outside this range are clamped.
  double _normalizeAmplitude(double db) {
    if (db <= _minAmplitudeDb) return 0.0;
    if (db >= _maxAmplitudeDb) return 1.0;
    return (db - _minAmplitudeDb) / (_maxAmplitudeDb - _minAmplitudeDb);
  }
}
