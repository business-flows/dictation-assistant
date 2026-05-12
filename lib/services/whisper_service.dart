import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

import '../core/errors/exceptions.dart';

/// Abstract interface for whisper.cpp transcription services.
///
/// Provides model loading/unloading and audio transcription capabilities
/// using the whisper_ggml_plus FFI bindings. All heavy operations are
/// offloaded to background isolates to prevent UI thread blocking.
///
/// Usage:
/// ```dart
/// await whisperService.loadModel('/path/to/ggml-model.bin');
/// final text = await whisperService.transcribe(audioData, language: 'en');
/// await whisperService.unloadModel();
/// ```
abstract class WhisperService {
  /// Whether a model is loaded and ready for transcription.
  bool get isModelLoaded;

  /// The currently loaded model ID, or null if no model is loaded.
  String? get loadedModelId;

  /// Load a GGML model from the given file path.
  ///
  /// [modelPath] - Absolute path to the .bin model file.
  /// [modelId] - Optional identifier for the model (e.g., 'large-v3-turbo').
  ///
  /// Throws [ModelLoadException] if the model file doesn't exist or is invalid.
  /// Throws [ModelLoadException] if model is already loaded (call unload first).
  Future<void> loadModel(String modelPath, {String? modelId});

  /// Transcribe PCM16 audio data to text.
  ///
  /// [audioData] - Raw audio bytes (PCM16 or WAV). If WAV, the header
  ///   is automatically stripped before processing.
  /// [language] - Language code ('auto', 'en', 'fr', 'ar') or null for auto-detect.
  ///
  /// Returns the transcribed text string.
  ///
  /// Throws [TranscriptionException] if no model is loaded.
  /// Throws [TranscriptionException] if transcription fails.
  Future<String> transcribe(Uint8List audioData, {String? language});

  /// Unload the current model to free memory.
  ///
  /// Safe to call even if no model is loaded. After unloading,
  /// [isModelLoaded] will be false.
  Future<void> unloadModel();

  /// Dispose all resources (unload model, close streams).
  ///
  /// Call this when the service is no longer needed.
  Future<void> dispose();
}

/// Data class for isolate-based transcription requests.
///
/// Required because [SendPort] can only send simple data types.
class _TranscriptionRequest {
  final String modelPath;
  final Uint8List audioData;
  final String? language;
  final String? modelId;

  _TranscriptionRequest({
    required this.modelPath,
    required this.audioData,
    this.language,
    this.modelId,
  });
}

/// Data class for isolate-based transcription responses.
class _TranscriptionResponse {
  final String? text;
  final String? error;

  _TranscriptionResponse({this.text, this.error});
}

/// Concrete implementation of [WhisperService] using whisper_ggml_plus.
///
/// All transcription work happens in a background isolate via [Isolate.run]
/// to ensure the UI thread remains responsive. Model loading happens on the
/// main isolate but is typically fast (just memory mapping).
///
/// The service supports multiple languages: English ('en'), French ('fr'),
/// and Arabic ('ar'), with automatic language detection as the default.
@singleton
class WhisperServiceImpl implements WhisperService {
  final Logger _logger;

  /// The whisper model instance (loaded on main isolate).
  WhisperModel? _model;

  /// The whisper transcription instance.
  Whisper? _whisper;

  /// Path to the loaded model file.
  String? _modelPath;

  /// ID of the loaded model.
  String? _modelId;

  /// Supported language codes mapped to whisper language tokens.
  static const Map<String, String> _languageTokens = {
    'auto': 'auto',
    'en': 'en',
    'fr': 'fr',
    'ar': 'ar',
  };

  /// Creates the whisper service with a logger.
  WhisperServiceImpl({required Logger logger}) : _logger = logger;

  @override
  bool get isModelLoaded => _model != null && _whisper != null;

  @override
  String? get loadedModelId => _modelId;

  @override
  Future<void> loadModel(String modelPath, {String? modelId}) async {
    try {
      if (isModelLoaded) {
        if (_modelPath == modelPath) {
          _logger.i('WhisperService: Model already loaded from $modelPath');
          return;
        }
        _logger.w('WhisperService: Unloading previous model before loading new one');
        await unloadModel();
      }

      // Verify model file exists
      final file = File(modelPath);
      if (!await file.exists()) {
        throw ModelLoadException(
          'Model file not found at: $modelPath',
          code: 'MODEL_FILE_NOT_FOUND',
        );
      }

      _logger.i('WhisperService: Loading model from $modelPath');

      // Load the model using whisper_ggml_plus
      _model = WhisperModel(modelPath);
      _whisper = Whisper(_model!);
      _modelPath = modelPath;
      _modelId = modelId ?? modelPath.split(Platform.pathSeparator).last;

      _logger.i('WhisperService: Model loaded successfully (id: $_modelId)');
    } catch (e, stackTrace) {
      _logger.e('WhisperService: Failed to load model', error: e, stackTrace: stackTrace);
      await _cleanup();
      if (e is ModelLoadException) rethrow;
      throw ModelLoadException(
        'Failed to load whisper model: ${e.toString()}',
        code: 'MODEL_LOAD_FAILED',
      );
    }
  }

  @override
  Future<String> transcribe(Uint8List audioData, {String? language}) async {
    if (!isModelLoaded) {
      throw const TranscriptionException(
        'No model loaded. Call loadModel() before transcribing.',
        code: 'MODEL_NOT_LOADED',
      );
    }

    try {
      _logger.d('WhisperService: Starting transcription (${audioData.length} bytes)');

      // Strip WAV header if present
      final pcmData = _stripWavHeaderIfNeeded(audioData);

      // Validate: must have even number of bytes for PCM16
      if (pcmData.length % 2 != 0) {
        throw const TranscriptionException(
          'Invalid audio data: odd number of bytes (not valid PCM16)',
          code: 'INVALID_AUDIO_DATA',
        );
      }

      // Resolve language
      final resolvedLanguage = _languageTokens[language] ?? 'auto';

      // Run transcription in isolate to avoid blocking UI
      final request = _TranscriptionRequest(
        modelPath: _modelPath!,
        audioData: pcmData,
        language: resolvedLanguage == 'auto' ? null : resolvedLanguage,
        modelId: _modelId,
      );

      final result = await Isolate.run<_TranscriptionResponse>(
        () => _transcribeInIsolate(request),
      );

      if (result.error != null) {
        throw TranscriptionException(
          'Transcription failed: ${result.error}',
          code: 'TRANSCRIPTION_FAILED',
        );
      }

      final text = result.text?.trim() ?? '';
      _logger.d('WhisperService: Transcription result: "$text"');
      return text;
    } on TranscriptionException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('WhisperService: Transcription error', error: e, stackTrace: stackTrace);
      throw TranscriptionException(
        'Transcription error: ${e.toString()}',
        isRecoverable: true,
        code: 'TRANSCRIPTION_ERROR',
      );
    }
  }

  @override
  Future<void> unloadModel() async {
    _logger.i('WhisperService: Unloading model');
    await _cleanup();
  }

  @override
  Future<void> dispose() async {
    _logger.i('WhisperService: Disposing');
    await _cleanup();
  }

  /// Clean up model resources.
  Future<void> _cleanup() async {
    try {
      _whisper?.dispose();
    } catch (e) {
      _logger.w('WhisperService: Error disposing whisper: $e');
    }
    _whisper = null;
    _model = null;
    _modelPath = null;
    _modelId = null;
  }

  /// Static isolate entry point for transcription.
  ///
  /// Creates a new whisper instance in the isolate, runs transcription,
  /// and disposes before returning. This ensures no cross-isolate
  /// object sharing issues.
  static _TranscriptionResponse _transcribeInIsolate(
    _TranscriptionRequest request,
  ) {
    WhisperModel? model;
    Whisper? whisper;

    try {
      // Load model in isolate
      model = WhisperModel(request.modelPath);
      whisper = Whisper(model);

      // Convert Uint8List to Int16List (what whisper expects)
      final int16Samples = Int16List.sublistView(request.audioData);

      // Build transcription parameters
      final params = WhisperTranscribeParams(
        samples: int16Samples,
        language: request.language,
      );

      // Run transcription
      final result = whisper.transcribe(params);

      // Extract text from result
      final text = result.text ?? '';

      return _TranscriptionResponse(text: text);
    } catch (e) {
      return _TranscriptionResponse(
        error: '${e.runtimeType}: ${e.toString()}',
      );
    } finally {
      whisper?.dispose();
    }
  }

  /// Strip WAV header from audio data if present.
  ///
  /// Checks for "RIFF" and "WAVE" magic bytes at the start of the data.
  /// If found, skips the 44-byte WAV header and returns just the PCM payload.
  Uint8List _stripWavHeaderIfNeeded(Uint8List data) {
    if (data.length < 44) return data;

    // Check for RIFF magic
    final isWav = data[0] == 0x52 && // R
        data[1] == 0x49 && // I
        data[2] == 0x46 && // F
        data[3] == 0x46; // F

    final isWave = data[8] == 0x57 && // W
        data[9] == 0x41 && // A
        data[10] == 0x56 && // V
        data[11] == 0x45; // E

    if (isWav && isWave) {
      _logger.d('WhisperService: Stripping WAV header from audio data');
      // Find 'data' chunk to get actual PCM start
      final pcmStart = _findDataChunkOffset(data);
      return Uint8List.sublistView(data, pcmStart);
    }

    return data;
  }

  /// Find the offset of the PCM data within a WAV file.
  ///
  /// Searches for the 'data' subchunk and returns its payload offset.
  /// Defaults to 44 (standard WAV header size) if not found.
  int _findDataChunkOffset(Uint8List wavData) {
    // Start searching after the fmt chunk (typically around byte 36)
    for (var i = 36; i < wavData.length - 8; i++) {
      if (wavData[i] == 0x64 && // d
          wavData[i + 1] == 0x61 && // a
          wavData[i + 2] == 0x74 && // t
          wavData[i + 3] == 0x61) {
        // a
        // Found 'data' chunk, skip 4 bytes for ID + 4 bytes for size
        return i + 8;
      }
    }
    // Fallback to standard header size
    return 44;
  }
}
