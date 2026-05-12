import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../../services/app_database.dart';

/// Thin wrapper around [AppDatabase] and [FlutterSecureStorage] for
/// settings-related data access.
///
/// Separates settings persistence from the repository implementation,
/// making it easier to test and swap storage mechanisms.
@singleton
class SettingsLocalDatasource {
  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;

  /// Storage key for the LLM API token.
  static const String _apiTokenKey = 'llm_api_token';

  const SettingsLocalDatasource(this._db, this._secureStorage);

  // ---- Database Settings ----

  /// Retrieves the settings row from the database.
  Future<AppSetting?> getSettings() => _db.getSettings();

  /// Persists settings to the database.
  Future<int> updateSettings(SettingsCompanion data) => _db.updateSettings(data);

  // ---- Secure Storage (API Token) ----

  /// Retrieves the API token from secure storage.
  Future<String?> getApiToken() => _secureStorage.read(key: _apiTokenKey);

  /// Saves the API token to secure storage.
  Future<void> saveApiToken(String token) =>
      _secureStorage.write(key: _apiTokenKey, value: token);

  /// Deletes the API token from secure storage.
  Future<void> deleteApiToken() =>
      _secureStorage.delete(key: _apiTokenKey);
}
