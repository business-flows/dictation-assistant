import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/settings_entity.dart';

/// Abstract repository interface for application settings.
///
/// Handles CRUD operations for user preferences. Settings are stored
/// in the local Drift database. The API token is stored separately
/// in [FlutterSecureStorage].
abstract class ISettingsRepository {
  /// Retrieves the current application settings.
  ///
  /// Returns default settings if none have been saved yet.
  Future<Either<Failure, SettingsEntity>> getSettings();

  /// Updates the application settings.
  ///
  /// Persists the given settings to the database.
  Future<Either<Failure, Unit>> updateSettings(SettingsEntity settings);

  /// Retrieves the stored API token from secure storage.
  ///
  /// Returns null if no token has been saved.
  Future<Either<Failure, String?>> getApiToken();

  /// Saves or clears the API token in secure storage.
  ///
  /// Pass null to remove the token.
  Future<Either<Failure, Unit>> saveApiToken(String? token);
}
