import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/model_info_entity.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/usecases/delete_model.dart';
import '../../domain/usecases/download_model.dart';
import '../../domain/usecases/get_available_models.dart';
import '../../domain/usecases/get_downloaded_models.dart';
import '../../domain/usecases/get_settings.dart';
import '../../domain/usecases/update_settings.dart';
import 'settings_event.dart';
import 'settings_state.dart';

/// BLoC for the settings feature.
///
/// Manages application settings, model management, and LLM configuration.
///
/// Usage:
/// ```dart
/// BlocProvider(
///   create: (context) => getIt<SettingsBloc>()..add(const LoadSettings()),
///   child: const SettingsPage(),
/// )
/// ```
@singleton
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final GetSettings _getSettings;
  final UpdateSettings _updateSettings;
  final GetAvailableModels _getAvailableModels;
  final GetDownloadedModels _getDownloadedModels;
  final DownloadModel _downloadModel;
  final DeleteModel _deleteModel;
  final Logger _logger;

  StreamSubscription? _downloadProgressSub;

  SettingsBloc(
    this._getSettings,
    this._updateSettings,
    this._getAvailableModels,
    this._getDownloadedModels,
    this._downloadModel,
    this._logger,
  ) : super(const SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateSettings>(_onUpdateSettings);
    on<DownloadModel>(_onDownloadModel);
    on<DeleteModel>(_onDeleteModel);
    on<TestLlmConnection>(_onTestLlmConnection);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    // Load settings and models in parallel
    final results = await Future.wait([
      _getSettings(const NoParams()),
      _getAvailableModels(const NoParams()),
    ]);

    final settingsResult = results[0] as dynamic; // Either<Failure, SettingsEntity>
    final modelsResult = results[1] as dynamic; // Either<Failure, List<ModelInfoEntity>>

    await settingsResult.fold(
      (Failure failure) async => emit(SettingsError(failure.message)),
      (SettingsEntity settings) async {
        await modelsResult.fold(
          (Failure failure) async => emit(SettingsLoaded(settings, const [])),
          (List<ModelInfoEntity> models) async {
            emit(SettingsLoaded(settings, models));
          },
        );
      },
    );
  }

  Future<void> _onUpdateSettings(
    UpdateSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final previousState = state;

    final result = await _updateSettings(
      UpdateSettingsParams(settings: event.settings),
    );

    result.fold(
      (failure) => emit(SettingsError('Failed to save settings: ${failure.message}')),
      (_) {
        // Reload models to reflect any changes (like selected model)
        if (previousState is SettingsLoaded) {
          emit(previousState.copyWith(settings: event.settings));
        }
      },
    );
  }

  Future<void> _onDownloadModel(
    DownloadModel event,
    Emitter<SettingsState> emit,
  ) async {
    final previousState = state;

    // Find model info
    if (previousState is SettingsLoaded) {
      final model = previousState.models.firstWhere(
        (m) => m.id == event.modelId,
        orElse: () => throw StateError('Model not found: ${event.modelId}'),
      );

      emit(ModelDownloadInProgress(event.modelId, 0.0));

      final result = await _downloadModel(DownloadModelParams(modelId: event.modelId));

      result.fold(
        (failure) => emit(SettingsError('Download failed: ${failure.message}')),
        (_) => emit(ModelDownloadComplete(event.modelId)),
      );

      // Reload models to reflect download status
      await _refreshModels(emit);
    }
  }

  Future<void> _onDeleteModel(
    DeleteModel event,
    Emitter<SettingsState> emit,
  ) async {
    final result = await _deleteModel(DeleteModelParams(modelId: event.modelId));

    result.fold(
      (failure) => emit(SettingsError('Failed to delete model: ${failure.message}')),
      (_) async {
        // Reload models to reflect deletion
        await _refreshModels(emit);
      },
    );
  }

  Future<void> _onTestLlmConnection(
    TestLlmConnection event,
    Emitter<SettingsState> emit,
  ) async {
    final previousState = state;
    if (previousState is! SettingsLoaded) return;

    final settings = previousState.settings;

    if (settings.llmEndpointUrl == null || settings.llmEndpointUrl!.isEmpty) {
      emit(const LlmConnectionFailure('Please enter an LLM endpoint URL'));
      return;
    }

    // Simple connectivity test — just validate URL format for now
    try {
      final uri = Uri.parse(settings.llmEndpointUrl!);
      if (!uri.isAbsolute) {
        emit(const LlmConnectionFailure('Invalid URL format'));
        return;
      }

      // In a real implementation, you'd make a test request to the LLM
      // For now, we just validate the URL structure
      emit(LlmConnectionSuccess(
        'Endpoint URL looks valid: ${settings.llmEndpointUrl}',
      ));
    } catch (e) {
      emit(LlmConnectionFailure('Invalid URL: $e'));
    }
  }

  /// Refreshes the model list while preserving current settings.
  Future<void> _refreshModels(Emitter<SettingsState> emit) async {
    final settingsResult = await _getSettings(const NoParams());
    final modelsResult = await _getAvailableModels(const NoParams());

    settingsResult.fold(
      (_) {/* keep existing */},
      (SettingsEntity settings) {
        modelsResult.fold(
          (_) => emit(SettingsLoaded(settings, const [])),
          (List<ModelInfoEntity> models) => emit(SettingsLoaded(settings, models)),
        );
      },
    );
  }

  @override
  Future<void> close() {
    _downloadProgressSub?.cancel();
    return super.close();
  }
}
