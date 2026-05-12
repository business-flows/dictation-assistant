import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/model_info_entity.dart';

/// Progress information for a model download operation.
class ModelDownloadProgress extends Equatable {
  /// The model ID being downloaded.
  final String modelId;

  /// Download progress as a fraction (0.0 to 1.0).
  final double progress;

  /// Bytes downloaded so far.
  final int bytesDownloaded;

  /// Total bytes to download.
  final int totalBytes;

  /// Whether the download is complete.
  final bool isComplete;

  /// Error message if the download failed.
  final String? error;

  const ModelDownloadProgress({
    required this.modelId,
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.isComplete = false,
    this.error,
  });

  @override
  List<Object?> get props => [modelId, progress, bytesDownloaded, totalBytes, isComplete, error];
}

/// Abstract repository interface for model management operations.
///
/// Handles listing available models, downloading, deleting, and checking
/// the local availability of Whisper models.
abstract class IModelManagerRepository {
  /// Retrieves all models available for download.
  ///
  /// Returns the full registry of Whisper models with their metadata.
  Future<Either<Failure, List<ModelInfoEntity>>> getAvailableModels();

  /// Retrieves all models that are currently downloaded locally.
  Future<Either<Failure, List<ModelInfoEntity>>> getDownloadedModels();

  /// Initiates a download for the specified model.
  ///
  /// Returns a [ModelDownloadProgress] stream via [downloadProgressStream].
  Future<Either<Failure, ModelDownloadProgress>> downloadModel(String modelId);

  /// Deletes a downloaded model from local storage.
  Future<Either<Failure, Unit>> deleteModel(String modelId);

  /// Gets the local file path for a downloaded model.
  ///
  /// Returns null if the model is not downloaded.
  Future<Either<Failure, String?>> getModelLocalPath(String modelId);

  /// Stream of download progress events.
  ///
  /// Listen to this stream to receive real-time download progress updates.
  Stream<ModelDownloadProgress> get downloadProgressStream;
}
