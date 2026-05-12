import '../../../../core/constants/llm_constants.dart';

/// Data model for building an OpenAI-compatible chat completion request.
///
/// Converts the raw dictation text and configuration into the JSON
/// body format expected by the LLM API.
class RefinementRequestModel {
  /// The original dictation text to refine.
  final String text;

  /// ISO 639-1 language code (e.g., 'en', 'ar', 'fr').
  final String languageCode;

  /// Optional custom system prompt override.
  final String? customPrompt;

  /// Creates a [RefinementRequestModel].
  const RefinementRequestModel({
    required this.text,
    required this.languageCode,
    this.customPrompt,
  });

  /// Converts this model to an OpenAI-compatible chat completion request body.
  ///
  /// The JSON structure follows the OpenAI chat completions API:
  /// ```json
  /// {
  ///   "model": "gpt-4o-mini",
  ///   "messages": [
  ///     {"role": "system", "content": "..."},
  ///     {"role": "user", "content": "<dictation text>"}
  ///   ],
  ///   "stream": true,
  ///   "temperature": 0.3
  /// }
  /// ```
  Map<String, dynamic> toJson({
    required String modelName,
    required String systemPrompt,
    required bool stream,
    double temperature = LlmConstants.defaultTemperature,
    int maxTokens = LlmConstants.defaultMaxTokens,
  }) {
    final effectiveSystemPrompt = customPrompt ?? systemPrompt;

    // Append language instruction to help the model preserve the original language
    final languageInstruction = _getLanguageInstruction(languageCode);
    final fullSystemPrompt = '$effectiveSystemPrompt\n$languageInstruction';

    return {
      'model': modelName,
      'messages': [
        {
          'role': 'system',
          'content': fullSystemPrompt,
        },
        {
          'role': 'user',
          'content': text,
        },
      ],
      'stream': stream,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };
  }

  /// Gets a language-specific instruction for the system prompt.
  String _getLanguageInstruction(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'ar':
        return 'الم dictateة باللغة العربية. حافظ على اللغة العربية في الإخراج.';
      case 'fr':
        return 'La dictation est en français. Préservez la langue française dans la sortie.';
      case 'en':
      default:
        return 'The dictation is in English. Preserve English in the output.';
    }
  }

  @override
  String toString() =>
      'RefinementRequestModel(text: ${text.length} chars, language: $languageCode, customPrompt: ${customPrompt != null})';
}
