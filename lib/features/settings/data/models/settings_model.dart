import '../../../../services/app_database.dart';
import '../../domain/entities/settings_entity.dart';

/// Data model for [SettingsEntity] with Drift database serialization.
class SettingsModel extends SettingsEntity {
  /// Creates a [SettingsModel].
  const SettingsModel({
    super.llmEndpointUrl,
    super.llmApiToken,
    super.llmModelName,
    super.llmSystemPrompt,
    required super.defaultLanguage,
    required super.selectedModelId,
    required super.autoRefine,
    required super.minimizeToTray,
    required super.alwaysOnTop,
  });

  /// Creates a [SettingsModel] from a Drift [AppSetting] data class.
  factory SettingsModel.fromDrift(AppSetting drift) {
    return SettingsModel(
      llmEndpointUrl: drift.llmEndpointUrl,
      llmModelName: drift.llmModelName,
      llmSystemPrompt: drift.llmSystemPrompt,
      defaultLanguage: drift.defaultLanguage,
      selectedModelId: drift.selectedModelId,
      autoRefine: drift.autoRefine,
      minimizeToTray: drift.minimizeToTray,
      alwaysOnTop: drift.alwaysOnTop,
      // llmApiToken is loaded separately from secure storage
    );
  }

  /// Converts this model to a Drift [SettingsCompanion] for persistence.
  ///
  /// Note: [llmApiToken] is NOT included — it is stored in secure storage.
  SettingsCompanion toDriftCompanion() {
    return SettingsCompanion(
      id: const Value(1),
      defaultLanguage: Value(defaultLanguage),
      selectedModelId: Value(selectedModelId),
      llmEndpointUrl: Value(llmEndpointUrl),
      llmModelName: Value(llmModelName),
      llmSystemPrompt: Value(llmSystemPrompt),
      autoRefine: Value(autoRefine),
      minimizeToTray: Value(minimizeToTray),
      alwaysOnTop: Value(alwaysOnTop),
    );
  }

  /// Creates a [SettingsModel] from a [SettingsEntity].
  factory SettingsModel.fromEntity(SettingsEntity entity) {
    return SettingsModel(
      llmEndpointUrl: entity.llmEndpointUrl,
      llmApiToken: entity.llmApiToken,
      llmModelName: entity.llmModelName,
      llmSystemPrompt: entity.llmSystemPrompt,
      defaultLanguage: entity.defaultLanguage,
      selectedModelId: entity.selectedModelId,
      autoRefine: entity.autoRefine,
      minimizeToTray: entity.minimizeToTray,
      alwaysOnTop: entity.alwaysOnTop,
    );
  }
}
