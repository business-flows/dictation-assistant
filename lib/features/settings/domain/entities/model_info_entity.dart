import 'package:equatable/equatable.dart';

/// Backend acceleration type for Whisper model inference.
enum BackendType {
  /// CPU inference (fallback, works everywhere).
  cpu,

  /// Apple Metal GPU acceleration (macOS/iOS).
  metal,

  /// Apple CoreML acceleration (macOS/iOS).
  coreml,

  /// Android NNAPI acceleration.
  nnapi,
}

/// Extension for [BackendType] string conversion.
extension BackendTypeExtension on BackendType {
  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case BackendType.cpu:
        return 'CPU';
      case BackendType.metal:
        return 'Metal';
      case BackendType.coreml:
        return 'CoreML';
      case BackendType.nnapi:
        return 'NNAPI';
    }
  }
}

/// Entity representing a downloadable Whisper model.
///
/// Contains metadata about the model, its download status, and
/// local file information if already downloaded.
class ModelInfoEntity extends Equatable {
  /// Unique model identifier (e.g., 'large-v3-turbo').
  final String id;

  /// Human-readable model name (e.g., 'Large v3 Turbo').
  final String name;

  /// Model file size in bytes.
  final int sizeBytes;

  /// URL to download the model file.
  final String downloadUrl;

  /// Local file path if the model is downloaded, null otherwise.
  final String? localPath;

  /// Whether the model is currently downloaded and available locally.
  final bool isDownloaded;

  /// Backend acceleration type for this model.
  final BackendType backendType;

  /// Creates a [ModelInfoEntity].
  const ModelInfoEntity({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.downloadUrl,
    this.localPath,
    required this.isDownloaded,
    required this.backendType,
  });

  /// Creates a copy with updated fields.
  ModelInfoEntity copyWith({
    String? id,
    String? name,
    int? sizeBytes,
    String? downloadUrl,
    String? localPath,
    bool? isDownloaded,
    BackendType? backendType,
  }) {
    return ModelInfoEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      localPath: localPath ?? this.localPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      backendType: backendType ?? this.backendType,
    );
  }

  /// Human-readable file size string (e.g., "1.5 GB").
  String get sizeDisplay {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (sizeBytes >= gb) {
      return '${(sizeBytes / gb).toStringAsFixed(1)} GB';
    } else if (sizeBytes >= mb) {
      return '${(sizeBytes / mb).toStringAsFixed(0)} MB';
    } else if (sizeBytes >= kb) {
      return '${(sizeBytes / kb).toStringAsFixed(0)} KB';
    }
    return '$sizeBytes B';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        sizeBytes,
        downloadUrl,
        localPath,
        isDownloaded,
        backendType,
      ];
}
