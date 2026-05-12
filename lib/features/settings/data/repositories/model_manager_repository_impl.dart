import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/model_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/audio_file_naming.dart';
import '../../domain/entities/model_info_entity.dart';
import '../../domain/repositories/i_model_manager_repository.dart';
import '../datasources/remote/model_download_datasource.dart';
import '../models/model_info_model.dart';

/// Implementation of [IModelManagerRepository] using the model registry,
/// filesystem checks, and HTTP downloads via Dio.
///
/// Handles:
/// - Listing available models from the built-in registry
/// - Checking which models are downloaded locally
/// - Downloading models with progress streaming
/// - Deleting downloaded models
@Singleton(as: IModelManagerRepository)
class ModelManagerRepositoryImpl implements IModelManagerRepository {
  final ModelDownloadDatasource _downloadDatasource;
  final Logger _logger;

  /// Internal stream controller that proxies from the download datasource
  /// and adds local model status updates.
  final _localProgressController = StreamController<ModelDownloadProgress>.broadcast();

  ModelManagerRepositoryImpl(
    this._downloadDatasource,
    this._logger,
  ) {
    // Proxy download progress from datasource to our controller
    _downloadDatasource.progressStream.listen(
      (progress) => _localProgressController.add(progress),
      onError: (Object e) => _logger.e('Download progress stream error', error: e),
    );
  }

  @override
  Stream<ModelDownloadProgress> get downloadProgressStream =>
      _localProgressController.stream;

  @override
  Future<Either<Failure, List<ModelInfoEntity>>> getAvailableModels() async {
    try {
      final models = ModelConstants.modelRegistry.map((entry) {
        final modelId = entry['id'] as String;
        final localPath = _getLocalPathIfExists(modelId);

        return ModelInfoModel.fromRegistry(entry).copyWith(
          localPath: localPath,
          isDownloaded: localPath != null,
        );
      }).toList();

      return Right(models);
    } catch (e, st) {
      _logger.e('Failed to get available models', error: e, stackTrace: st);
      return Left(ModelFailure('Failed to list models: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ModelInfoEntity>>> getDownloadedModels() async {
    try {
      final modelsDir = Directory(AudioFileNaming.modelsDir);
      if (!await modelsDir.exists()) {
        return const Right([]);
      }

      final downloadedModels = <ModelInfoEntity>[];
      final entries = ModelConstants.modelRegistry;

      for (final entry in entries) {
        final modelId = entry['id'] as String;
        final localPath = _getLocalPathIfExists(modelId);

        if (localPath != null) {
          final file = File(localPath);
          final size = await file.length();
          downloadedModels.add(
            ModelInfoModel.fromFileSystem(modelId, localPath, size),
          );
        }
      }

      return Right(downloadedModels);
    } catch (e, st) {
      _logger.e('Failed to get downloaded models', error: e, stackTrace: st);
      return Left(ModelFailure('Failed to list downloaded models: $e'));
    }
  }

  @override
  Future<Either<Failure, ModelDownloadProgress>> downloadModel(String modelId) async {
    try {
      // Verify model exists in registry
      final registryEntry = ModelConstants.modelRegistry.firstWhere(
        (r) => r['id'] == modelId,
        orElse: () => throw Exception('Model not found: $modelId'),
      );

      // Check if already downloaded
      if (_getLocalPathIfExists(modelId) != null) {
        _logger.i('Model already downloaded: $modelId');
        return Right(ModelDownloadProgress(
          modelId: modelId,
          progress: 1.0,
          bytesDownloaded: registryEntry['sizeBytes'] as int,
          totalBytes: registryEntry['sizeBytes'] as int,
          isComplete: true,
        ));
      }

      // Start download
      await _downloadDatasource.downloadModel(modelId);

      return Right(ModelDownloadProgress(
        modelId: modelId,
        progress: 1.0,
        bytesDownloaded: registryEntry['sizeBytes'] as int,
        totalBytes: registryEntry['sizeBytes'] as int,
        isComplete: true,
      ));
    } catch (e, st) {
      _logger.e('Failed to download model: $modelId', error: e, stackTrace: st);
      return Left(ModelFailure('Failed to download model: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteModel(String modelId) async {
    try {
      final fileName = ModelConstants.modelFileName(modelId);
      final filePath = AudioFileNaming.modelFilePath(fileName);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        _logger.i('Deleted model file: $filePath');
      } else {
        _logger.w('Model file not found for deletion: $filePath');
      }

      return const Right(unit);
    } catch (e, st) {
      _logger.e('Failed to delete model: $modelId', error: e, stackTrace: st);
      return Left(ModelFailure('Failed to delete model: $e'));
    }
  }

  @override
  Future<Either<Failure, String?>> getModelLocalPath(String modelId) async {
    try {
      final path = _getLocalPathIfExists(modelId);
      return Right(path);
    } catch (e, st) {
      _logger.e('Failed to get model path: $modelId', error: e, stackTrace: st);
      return Left(ModelFailure('Failed to get model path: $e'));
    }
  }

  /// Returns the local file path if the model file exists, null otherwise.
  String? _getLocalPathIfExists(String modelId) {
    final fileName = ModelConstants.modelFileName(modelId);
    final filePath = AudioFileNaming.modelFilePath(fileName);
    final file = File(filePath);
    return file.existsSync() ? filePath : null;
  }

  /// Disposes resources.
  Future<void> dispose() async {
    await _localProgressController.close();
    await _downloadDatasource.dispose();
  }
}
