import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../../../../core/constants/model_constants.dart';
import '../../../../../core/utils/audio_file_naming.dart';
import '../../../domain/repositories/i_model_manager_repository.dart';

/// Handles HTTP downloads for Whisper model files.
///
/// Uses Dio for efficient downloading with progress streaming.
/// Downloaded files are saved to the app's models directory.
@singleton
class ModelDownloadDatasource {
  final Dio _dio;
  final Logger _logger;
  final _progressController = StreamController<ModelDownloadProgress>.broadcast();

  ModelDownloadDatasource(this._dio, this._logger);

  /// Stream of download progress events.
  Stream<ModelDownloadProgress> get progressStream => _progressController.stream;

  /// Downloads a model file by ID.
  ///
  /// Looks up the model in [ModelConstants.modelRegistry], downloads the
  /// file, and saves it to the local models directory.
  Future<void> downloadModel(String modelId) async {
    // Find model in registry
    final registryEntry = ModelConstants.modelRegistry.firstWhere(
      (r) => r['id'] == modelId,
      orElse: () => throw Exception('Model not found in registry: $modelId'),
    );

    final url = registryEntry['downloadUrl'] as String;
    final fileName = ModelConstants.modelFileName(modelId);
    final savePath = AudioFileNaming.modelFilePath(fileName);

    // Ensure models directory exists
    final modelsDir = Directory(AudioFileNaming.modelsDir);
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final totalBytes = registryEntry['sizeBytes'] as int;

    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          final effectiveTotal = total > 0 ? total : totalBytes;
          final progress = effectiveTotal > 0 ? received / effectiveTotal : 0.0;

          _progressController.add(ModelDownloadProgress(
            modelId: modelId,
            progress: progress.clamp(0.0, 1.0),
            bytesDownloaded: received,
            totalBytes: effectiveTotal,
          ));
        },
        deleteOnError: true,
      );

      // Verify the download
      final file = File(savePath);
      if (!await file.exists()) {
        throw Exception('Downloaded file not found at $savePath');
      }

      _progressController.add(ModelDownloadProgress(
        modelId: modelId,
        progress: 1.0,
        bytesDownloaded: totalBytes,
        totalBytes: totalBytes,
        isComplete: true,
      ));

      _logger.i('Model downloaded successfully: $modelId');
    } catch (e, st) {
      _logger.e('Model download failed: $modelId', error: e, stackTrace: st);
      _progressController.add(ModelDownloadProgress(
        modelId: modelId,
        progress: 0.0,
        bytesDownloaded: 0,
        totalBytes: totalBytes,
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// Cancels any active download and cleans up resources.
  Future<void> dispose() async {
    await _progressController.close();
  }
}
