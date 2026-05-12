import 'package:equatable/equatable.dart';

import '../../domain/entities/settings_entity.dart';

/// Base class for all settings events.
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load current settings and available models.
class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

/// Event to update application settings.
class UpdateSettings extends SettingsEvent {
  /// The updated settings to persist.
  final SettingsEntity settings;

  const UpdateSettings(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Event to initiate a model download.
class DownloadModel extends SettingsEvent {
  /// The model ID to download.
  final String modelId;

  const DownloadModel(this.modelId);

  @override
  List<Object?> get props => [modelId];
}

/// Event to delete a downloaded model.
class DeleteModel extends SettingsEvent {
  /// The model ID to delete.
  final String modelId;

  const DeleteModel(this.modelId);

  @override
  List<Object?> get props => [modelId];
}

/// Event to test the LLM connection with current settings.
class TestLlmConnection extends SettingsEvent {
  const TestLlmConnection();
}
