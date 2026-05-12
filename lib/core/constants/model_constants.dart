import 'app_constants.dart';

/// Whisper model registry and download configuration.
class ModelConstants {
  ModelConstants._();

  // Model registry
  static const List<Map<String, dynamic>> modelRegistry = [
    {
      'id': 'large-v3-turbo',
      'name': 'Large v3 Turbo',
      'sizeBytes': 1629000000, // ~1.5GB
      'downloadUrl': 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin',
      'description': 'Best quality, fastest inference. Recommended for desktop.',
      'recommendedFor': ['desktop'],
    },
    {
      'id': 'large-v3',
      'name': 'Large v3',
      'sizeBytes': 3095000000, // ~2.9GB
      'downloadUrl': 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin',
      'description': 'Highest accuracy. Requires powerful hardware.',
      'recommendedFor': ['desktop-high-end'],
    },
    {
      'id': 'small',
      'name': 'Small',
      'sizeBytes': 484000000, // ~466MB
      'downloadUrl': 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
      'description': 'Good balance of speed and accuracy.',
      'recommendedFor': ['desktop', 'mobile'],
    },
    {
      'id': 'base',
      'name': 'Base',
      'sizeBytes': 148000000, // ~148MB
      'downloadUrl': 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
      'description': 'Fast inference. Moderate accuracy.',
      'recommendedFor': ['mobile'],
    },
    {
      'id': 'tiny',
      'name': 'Tiny',
      'sizeBytes': 78000000, // ~78MB
      'downloadUrl': 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
      'description': 'Fastest inference. Emergency fallback only.',
      'recommendedFor': ['emergency'],
    },
  ];

  static String get defaultModelId => AppConstants.defaultModelId;
  static String get fallbackModelId => AppConstants.fallbackModelId;
  static String get emergencyModelId => AppConstants.emergencyModelId;

  // Model file naming
  static String modelFileName(String modelId) => 'ggml-$modelId.bin';

  // Backend selection per platform
  static const Map<String, String> platformBackends = {
    'macos': 'metal',
    'ios': 'coreml',
    'android': 'nnapi',
    'windows': 'cpu',
    'linux': 'cpu',
  };
}