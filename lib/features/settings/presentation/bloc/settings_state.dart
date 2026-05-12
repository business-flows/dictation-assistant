import 'package:equatable/equatable.dart';

import '../../domain/entities/model_info_entity.dart';
import '../../domain/entities/settings_entity.dart';

/// Base class for all settings states.
abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before settings are loaded.
class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

/// State while settings are being loaded.
class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// State when settings and models have been loaded successfully.
class SettingsLoaded extends SettingsState {
  /// Current application settings.
  final SettingsEntity settings;

  /// List of available models with download status.
  final List<ModelInfoEntity> models;

  const SettingsLoaded(this.settings, this.models);

  /// Creates a copy with updated fields.
  SettingsLoaded copyWith({
    SettingsEntity? settings,
    List<ModelInfoEntity>? models,
  }) {
    return SettingsLoaded(
      settings ?? this.settings,
      models ?? this.models,
    );
  }

  @override
  List<Object?> get props => [settings, models];
}

/// State when an error occurs.
class SettingsError extends SettingsState {
  /// Error message to display.
  final String message;

  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// State when a model download is in progress.
class ModelDownloadInProgress extends SettingsState {
  /// The model ID being downloaded.
  final String modelId;

  /// Download progress as a fraction (0.0 to 1.0).
  final double progress;

  const ModelDownloadInProgress(this.modelId, this.progress);

  @override
  List<Object?> get props => [modelId, progress];
}

/// State when a model download completes successfully.
class ModelDownloadComplete extends SettingsState {
  /// The model ID that was downloaded.
  final String modelId;

  const ModelDownloadComplete(this.modelId);

  @override
  List<Object?> get props => [modelId];
}

/// State when LLM connection test succeeds.
class LlmConnectionSuccess extends SettingsState {
  /// Response message from the LLM.
  final String message;

  const LlmConnectionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

/// State when LLM connection test fails.
class LlmConnectionFailure extends SettingsState {
  /// Error message.
  final String message;

  const LlmConnectionFailure(this.message);

  @override
  List<Object?> get props => [message];
}
