import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import 'ulid_generator.dart';

/// Generates consistent file paths for audio recordings.
class AudioFileNaming {
  AudioFileNaming._();

  static String? _appDir;

  /// Initialize the base application directory.
  static Future<void> initialize() async {
    final docsDir = await getApplicationDocumentsDirectory();
    _appDir = p.join(docsDir.path, 'DictationAssistant');
    final recordingsDir = Directory(p.join(_appDir!, 'recordings'));
    final chunksDir = Directory(p.join(_appDir!, 'chunks'));
    final modelsDir = Directory(p.join(_appDir!, 'models'));

    await recordingsDir.create(recursive: true);
    await chunksDir.create(recursive: true);
    await modelsDir.create(recursive: true);
  }

  /// Get the base application directory.
  static String get appDir {
    if (_appDir == null) {
      throw StateError('AudioFileNaming not initialized. Call initialize() first.');
    }
    return _appDir!;
  }

  /// Generate a path for a session's full audio recording.
  static String sessionAudioPath(String sessionId) {
    return p.join(appDir, 'recordings', '$sessionId${AppConstants.audioExtension}');
  }

  /// Generate a path for a chunk's PCM file.
  static String chunkAudioPath(String sessionId, int chunkIndex) {
    return p.join(appDir, 'chunks', '${sessionId}_$chunkIndex.pcm');
  }

  /// Generate a path for a chunk's WAV file.
  static String chunkWavPath(String sessionId, int chunkIndex) {
    return p.join(appDir, 'chunks', '${sessionId}_$chunkIndex${AppConstants.audioExtension}');
  }

  /// Get the directory for downloaded models.
  static String get modelsDir => p.join(appDir, 'models');

  /// Generate a path for a model file.
  static String modelFilePath(String modelFileName) {
    return p.join(modelsDir, modelFileName);
  }

  /// Generate an export path for a DOCX file.
  static String exportDocxPath(String sessionId, {String? customName}) {
    final name = customName ?? sessionId;
    return p.join(appDir, 'exports', '$name${AppConstants.docxExtension}');
  }

  /// Create a new session ID and its associated audio path.
  static ({String sessionId, String audioPath}) createSession() {
    final id = UlidGenerator.generate();
    final path = sessionAudioPath(id);
    return (sessionId: id, audioPath: path);
  }
}