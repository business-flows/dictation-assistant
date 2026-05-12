import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../datasources/local/settings_local_datasource.dart';
import '../models/settings_model.dart';

/// Implementation of [ISettingsRepository] using Drift database and
/// FlutterSecureStorage.
///
/// Settings are persisted in the local Drift [AppDatabase].
/// The API token is stored separately in [FlutterSecureStorage] for security.
@Singleton(as: ISettingsRepository)
class SettingsRepositoryImpl implements ISettingsRepository {
  final SettingsLocalDatasource _datasource;
  final Logger _logger;

  const SettingsRepositoryImpl(
    this._datasource,
    this._logger,
  );

  @override
  Future<Either<Failure, SettingsEntity>> getSettings() async {
    try {
      final driftSetting = await _datasource.getSettings();

      if (driftSetting == null) {
        // Return defaults
        _logger.w('No settings found, returning defaults');
        return Right(_defaultSettings());
      }

      // Load API token from secure storage
      final apiToken = await _datasource.getApiToken();

      final settings = SettingsModel.fromDrift(driftSetting).copyWith(
        llmApiToken: apiToken,
      );

      return Right(settings);
    } catch (e, st) {
      _logger.e('Failed to load settings', error: e, stackTrace: st);
      return Left(CacheFailure('Failed to load settings: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateSettings(SettingsEntity settings) async {
    try {
      // Persist to database (without API token)
      final model = SettingsModel.fromEntity(settings);
      await _datasource.updateSettings(model.toDriftCompanion());

      // Persist API token to secure storage if provided
      if (settings.llmApiToken != null && settings.llmApiToken!.isNotEmpty) {
        await _datasource.saveApiToken(settings.llmApiToken!);
      }

      return const Right(unit);
    } catch (e, st) {
      _logger.e('Failed to update settings', error: e, stackTrace: st);
      return Left(CacheFailure('Failed to save settings: $e'));
    }
  }

  @override
  Future<Either<Failure, String?>> getApiToken() async {
    try {
      final token = await _datasource.getApiToken();
      return Right(token);
    } catch (e, st) {
      _logger.e('Failed to read API token', error: e, stackTrace: st);
      return Left(CacheFailure('Failed to read API token: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveApiToken(String? token) async {
    try {
      if (token == null || token.isEmpty) {
        await _datasource.deleteApiToken();
      } else {
        await _datasource.saveApiToken(token);
      }
      return const Right(unit);
    } catch (e, st) {
      _logger.e('Failed to save API token', error: e, stackTrace: st);
      return Left(CacheFailure('Failed to save API token: $e'));
    }
  }

  /// Returns default settings when none are persisted.
  SettingsEntity _defaultSettings() {
    return const SettingsEntity(
      defaultLanguage: 'en',
      selectedModelId: AppConstants.defaultModelId,
      llmEndpointUrl: null,
      llmApiToken: null,
      llmModelName: null,
      llmSystemPrompt: AppConstants.defaultLlmSystemPrompt,
      autoRefine: false,
      minimizeToTray: true,
      alwaysOnTop: false,
    );
  }
}
