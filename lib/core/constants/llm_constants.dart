import 'app_constants.dart';

/// LLM API configuration defaults.
class LlmConstants {
  LlmConstants._();

  // Default values
  static const String defaultEndpointUrl = '';
  static const String defaultModelName = 'gpt-4o-mini';
  static const String defaultSystemPrompt = AppConstants.defaultLlmSystemPrompt;

  // API
  static const String chatCompletionsPath = '/v1/chat/completions';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(minutes: 2);

  // Streaming
  static const String sseDataPrefix = 'data: ';
  static const String sseDoneMarker = '[DONE]';

  // Retry
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Request body defaults
  static const double defaultTemperature = 0.3;
  static const int defaultMaxTokens = 4096;
  static const bool defaultStream = true;

  // UI
  static const int streamDebounceMs = 50;
}