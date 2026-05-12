import 'dart:io';

import '../../../../core/constants/model_constants.dart';
import '../../domain/entities/model_info_entity.dart';

/// Data model for [ModelInfoEntity] with serialization from
/// the model registry and filesystem.
class ModelInfoModel extends ModelInfoEntity {
  /// Creates a [ModelInfoModel].
  const ModelInfoModel({
    required super.id,
    required super.name,
    required super.sizeBytes,
    required super.downloadUrl,
    super.localPath,
    required super.isDownloaded,
    required super.backendType,
  });

  /// Creates a [ModelInfoModel] from a model registry entry.
  factory ModelInfoModel.fromRegistry(Map<String, dynamic> registryEntry) {
    final id = registryEntry['id'] as String;
    final rawBackend = registryEntry['backend'] as String? ?? 'cpu';

    return ModelInfoModel(
      id: id,
      name: registryEntry['name'] as String,
      sizeBytes: registryEntry['sizeBytes'] as int,
      downloadUrl: registryEntry['downloadUrl'] as String,
      isDownloaded: false,
      backendType: _parseBackendType(rawBackend),
    );
  }

  /// Creates a [ModelInfoModel] from filesystem discovery.
  ///
  /// Used when scanning the models directory for already-downloaded files.
  factory ModelInfoModel.fromFileSystem(
    String modelId,
    String localPath,
    int size,
  ) {
    // Find the registry entry to get metadata
    final registryEntry = ModelConstants.modelRegistry.firstWhere(
      (r) => r['id'] == modelId,
      orElse: () => {
        'id': modelId,
        'name': modelId,
        'sizeBytes': size,
        'downloadUrl': '',
      },
    );

    final rawBackend = registryEntry['backend'] as String? ?? 'cpu';

    return ModelInfoModel(
      id: modelId,
      name: registryEntry['name'] as String? ?? modelId,
      sizeBytes: size,
      downloadUrl: registryEntry['downloadUrl'] as String? ?? '',
      localPath: localPath,
      isDownloaded: true,
      backendType: _parseBackendType(rawBackend),
    );
  }

  /// Creates a copy with updated download status.
  ModelInfoModel copyWithDownloaded({
    required String localPath,
    required bool isDownloaded,
  }) {
    return ModelInfoModel(
      id: id,
      name: name,
      sizeBytes: sizeBytes,
      downloadUrl: downloadUrl,
      localPath: localPath,
      isDownloaded: isDownloaded,
      backendType: backendType,
    );
  }

  static BackendType _parseBackendType(String raw) {
    switch (raw.toLowerCase()) {
      case 'metal':
        return BackendType.metal;
      case 'coreml':
        return BackendType.coreml;
      case 'nnapi':
        return BackendType.nnapi;
      case 'cpu':
      default:
        return BackendType.cpu;
    }
  }
}
