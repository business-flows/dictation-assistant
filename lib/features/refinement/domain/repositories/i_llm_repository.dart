import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/refinement_result_entity.dart';

/// Configuration value object for LLM API settings.
///
/// Immutable configuration that defines how to connect to the
/// OpenAI-compatible LLM endpoint.
class LlmConfig extends Equatable {
  /// The base URL of the LLM API endpoint.
  /// e.g., 'https://api.openai.com' or 'http://localhost:11434'
  final String endpointUrl;

  /// The API authentication token (Bearer token).
  /// Nullable for local endpoints that don't require authentication.
  final String? apiToken;

  /// The model name to use for chat completions.
  /// e.g., 'gpt-4o-mini', 'llama3.1', 'qwen2.5'
  final String modelName;

  /// The system prompt sent with every refinement request.
  final String systemPrompt;

  /// Sampling temperature (0.0 = deterministic, 2.0 = very random).
  final double temperature;

  /// Maximum number of tokens to generate.
  final int maxTokens;

  /// Creates an [LlmConfig].
  const LlmConfig({
    required this.endpointUrl,
    this.apiToken,
    required this.modelName,
    required this.systemPrompt,
    this.temperature = 0.3,
    this.maxTokens = 4096,
  });

  /// Creates a copy with optionally updated fields.
  LlmConfig copyWith({
    String? endpointUrl,
    String? apiToken,
    String? modelName,
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
  }) {
    return LlmConfig(
      endpointUrl: endpointUrl ?? this.endpointUrl,
      apiToken: apiToken ?? this.apiToken,
      modelName: modelName ?? this.modelName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  @override
  List<Object?> get props => [
        endpointUrl,
        apiToken,
        modelName,
        systemPrompt,
        temperature,
        maxTokens,
      ];

  @override
  String toString() =>
      'LlmConfig(endpointUrl: $endpointUrl, modelName: $modelName, '
      'temperature: $temperature, maxTokens: $maxTokens)';
}

/// Abstract repository interface for LLM refinement operations.
///
/// Defines the contract for streaming and single-shot text refinement
/// using an OpenAI-compatible chat completions API.
abstract class ILLMRepository {
  /// Stream refined text from LLM endpoint.
  ///
  /// Returns a stream of partial text tokens as they arrive from the
  /// LLM's server-sent events (SSE) response.
  ///
  /// [text] - The original dictation text to refine.
  /// [languageCode] - ISO 639-1 language code (e.g., 'en', 'ar', 'fr').
  /// [customPrompt] - Optional override for the system prompt.
  Stream<Either<Failure, String>> refineTextStream({
    required String text,
    required String languageCode,
    String? customPrompt,
  });

  /// Single-shot refinement (non-streaming).
  ///
  /// Sends the text to the LLM and waits for the complete response.
  /// Returns a [RefinementResultEntity] with full metadata.
  ///
  /// [text] - The original dictation text to refine.
  /// [languageCode] - ISO 639-1 language code.
  /// [customPrompt] - Optional override for the system prompt.
  Future<Either<Failure, RefinementResultEntity>> refineText({
    required String text,
    required String languageCode,
    String? customPrompt,
  });

  /// Validate LLM configuration by sending a test request.
  ///
  /// Sends a minimal chat completion request to verify that the
  /// endpoint URL, API token, and model name are correctly configured.
  ///
  /// Returns `true` if the configuration is valid, `false` otherwise.
  Future<Either<Failure, bool>> validateConfiguration();

  /// Get current LLM configuration.
  ///
  /// Retrieves the active configuration from persistent storage.
  Future<Either<Failure, LlmConfig>> getConfiguration();
}
