import 'app_constants.dart';

/// Audio recording and processing constants.
class AudioConstants {
  AudioConstants._();

  // PCM format
  static const int sampleRate = AppConstants.sampleRate;
  static const int channelCount = AppConstants.channels;
  static const int bitsPerSample = AppConstants.bitsPerSample;
  static const int bytesPerSample = bitsPerSample ~/ 8;
  static const int byteRate = sampleRate * channelCount * bytesPerSample;
  static const int blockAlign = channelCount * bytesPerSample;

  // Chunking parameters
  static const int chunkDurationMs = AppConstants.chunkDurationMs;
  static const int chunkMaxDurationMs = AppConstants.chunkMaxDurationMs;
  static const int chunkOverlapMs = AppConstants.chunkOverlapMs;

  static int get chunkSampleCount => sampleRate * chunkDurationMs ~/ 1000;
  static int get overlapSampleCount => sampleRate * chunkOverlapMs ~/ 1000;
  static int get chunkBytes => chunkSampleCount * bytesPerSample;
  static int get overlapBytes => overlapSampleCount * bytesPerSample;

  // WAVE header constants
  static const String riffHeader = 'RIFF';
  static const String waveHeader = 'WAVE';
  static const String fmtChunk = 'fmt ';
  static const String dataChunk = 'data';
  static const int pcmFormat = 1;
  static const int fmtChunkSize = 16;

  // Recording
  static const int minRecordingDurationMs = 500;
  static const int amplitudeUpdateIntervalMs = 100;

  // Audio levels
  static const double silenceThresholdDb = -50.0;
  static const double minSpeechDurationMs = 200;
}