/// Global application constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Dictation Assistant';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'dictation_app.db';
  static const int databaseVersion = 1;

  // Audio
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitsPerSample = 16;

  // Chunking
  static const int chunkDurationMs = 3000;       // 3 seconds primary chunk
  static const int chunkMaxDurationMs = 5000;    // 5 seconds max
  static const int chunkOverlapMs = 500;         // 0.5 second overlap
  static const int chunkSamples = sampleRate * chunkDurationMs ~/ 1000; // 48000
  static const int overlapSamples = sampleRate * chunkOverlapMs ~/ 1000; // 8000

  // Transcription performance
  static const int targetLatencyMs = 2000;       // Target < 2s per chunk
  static const int maxConcurrentTranscriptions = 2;

  // Models
  static const String defaultModelId = 'large-v3-turbo';
  static const String fallbackModelId = 'small';
  static const String emergencyModelId = 'tiny';

  // LLM defaults
  static const String defaultLlmSystemPrompt =
      'Structure this dictation into clean markdown. Preserve the original language. ';

  // File extensions
  static const String audioExtension = '.wav';
  static const String docxExtension = '.docx';

  // Export
  static const String exportDateFormat = 'yyyy-MM-dd HH:mm';

  // Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'fr': 'French',
    'ar': 'Arabic',
  };

  // UI
  static const double maxContentWidth = 1200;
  static const double desktopBreakpoint = 900;
  static const double tabletBreakpoint = 600;
}