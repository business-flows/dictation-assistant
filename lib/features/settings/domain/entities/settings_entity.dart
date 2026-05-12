import 'package:equatable/equatable.dart';

/// Entity representing the application's user-configurable settings.
///
/// Contains all settings fields. Note that [llmApiToken] is NOT stored
/// in the database — it is kept in secure storage separately.
class SettingsEntity extends Equatable {
  /// LLM API endpoint URL (e.g., OpenAI-compatible endpoint).
  final String? llmEndpointUrl;

  /// LLM API authentication token.
  ///
  /// **Security note:** This is stored in [FlutterSecureStorage], NOT
  /// in the SQLite database. Never persist this in plain text.
  final String? llmApiToken;

  /// LLM model name to use for refinement.
  final String? llmModelName;

  /// System prompt sent to the LLM for text refinement.
  final String? llmSystemPrompt;

  /// Default dictation language code (ISO 639-1).
  final String defaultLanguage;

  /// Currently selected Whisper model ID.
  final String selectedModelId;

  /// Whether to automatically refine text after each session.
  final bool autoRefine;

  /// Whether to minimize to system tray on close (desktop only).
  final bool minimizeToTray;

  /// Whether the window should stay always on top (desktop only).
  final bool alwaysOnTop;

  /// Creates a [SettingsEntity].
  const SettingsEntity({
    this.llmEndpointUrl,
    this.llmApiToken,
    this.llmModelName,
    this.llmSystemPrompt,
    required this.defaultLanguage,
    required this.selectedModelId,
    required this.autoRefine,
    required this.minimizeToTray,
    required this.alwaysOnTop,
  });

  /// Creates a copy with updated fields.
  SettingsEntity copyWith({
    String? llmEndpointUrl,
    String? llmApiToken,
    String? llmModelName,
    String? llmSystemPrompt,
    String? defaultLanguage,
    String? selectedModelId,
    bool? autoRefine,
    bool? minimizeToTray,
    bool? alwaysOnTop,
  }) {
    return SettingsEntity(
      llmEndpointUrl: llmEndpointUrl ?? this.llmEndpointUrl,
      llmApiToken: llmApiToken ?? this.llmApiToken,
      llmModelName: llmModelName ?? this.llmModelName,
      llmSystemPrompt: llmSystemPrompt ?? this.llmSystemPrompt,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      autoRefine: autoRefine ?? this.autoRefine,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    );
  }

  @override
  List<Object?> get props => [
        llmEndpointUrl,
        llmApiToken,
        llmModelName,
        llmSystemPrompt,
        defaultLanguage,
        selectedModelId,
        autoRefine,
        minimizeToTray,
        alwaysOnTop,
      ];
}
