// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i4;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i3;
import 'package:get_it/get_it.dart' as _i1;
import 'package:injectable/injectable.dart' as _i2;
import 'package:logger/logger.dart' as _i5;

import 'core/utils/audio_file_naming.dart' as _i6;
import 'features/history/data/datasources/local/history_local_datasource.dart'
    as _i11;
import 'features/history/data/repositories/history_repository_impl.dart'
    as _i13;
import 'features/history/domain/repositories/i_history_repository.dart'
    as _i12;
import 'features/history/domain/usecases/copy_session_text.dart' as _i20;
import 'features/history/domain/usecases/delete_session.dart' as _i16;
import 'features/history/domain/usecases/get_all_sessions.dart' as _i14;
import 'features/history/domain/usecases/get_session_by_id.dart' as _i15;
import 'features/history/domain/usecases/search_sessions.dart' as _i19;
import 'features/history/presentation/bloc/history_bloc.dart' as _i23;
import 'features/settings/data/datasources/local/settings_local_datasource.dart'
    as _i9;
import 'features/settings/data/datasources/remote/model_download_datasource.dart'
    as _i7;
import 'features/settings/data/repositories/model_manager_repository_impl.dart'
    as _i18;
import 'features/settings/data/repositories/settings_repository_impl.dart'
    as _i22;
import 'features/settings/domain/repositories/i_model_manager_repository.dart'
    as _i17;
import 'features/settings/domain/repositories/i_settings_repository.dart'
    as _i21;
import 'features/settings/domain/usecases/delete_model.dart' as _i29;
import 'features/settings/domain/usecases/download_model.dart' as _i26;
import 'features/settings/domain/usecases/get_available_models.dart' as _i24;
import 'features/settings/domain/usecases/get_downloaded_models.dart' as _i27;
import 'features/settings/domain/usecases/get_settings.dart' as _i25;
import 'features/settings/domain/usecases/update_settings.dart' as _i28;
import 'features/settings/presentation/bloc/settings_bloc.dart' as _i30;
import 'services/app_database.dart' as _i10;
import 'services/app_database.dart' as _i8;

/// Injectable module providing third-party dependencies.
@_i2.module
abstract class RegisterModule {
  /// Provides a singleton [FlutterSecureStorage] instance.
  @_i2.singleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();

  /// Provides a singleton [Dio] HTTP client.
  @_i2.singleton
  Dio get dio => Dio();

  /// Provides a singleton [Logger] instance.
  @_i2.singleton
  Logger get logger => Logger();
}

/// Configures dependency injection for the application.
extension GetItInjectableX on _i1.GetIt {
  /// Initializes all registered dependencies.
  ///
  /// This method should be called during app startup before any
  /// feature BLoCs or repositories are accessed.
  Future<_i1.GetIt> init() async {
    final gh = _i2.GetItHelper(this, 'production');
    final registerModule = _$RegisterModule();

    // Third-party dependencies
    gh.singleton<_i3.FlutterSecureStorage>(registerModule.secureStorage);
    gh.singleton<_i4.Dio>(registerModule.dio);
    gh.singleton<_i5.Logger>(registerModule.logger);

    // Database
    gh.singleton<_i8.AppDatabase>(() => _i8.AppDatabase());

    // Audio file naming (static utility, registered for DI)
    gh.singleton<_i6.AudioFileNaming>(() => _i6.AudioFileNaming());

    // ---- Settings Feature Data Layer ----
    gh.singleton<_i9.SettingsLocalDatasource>(
      () => _i9.SettingsLocalDatasource(
        gh<_i8.AppDatabase>(),
        gh<_i3.FlutterSecureStorage>(),
      ),
    );

    gh.singleton<_i7.ModelDownloadDatasource>(
      () => _i7.ModelDownloadDatasource(
        gh<_i4.Dio>(),
        gh<_i5.Logger>(),
      ),
    );

    // ---- Settings Feature Repositories ----
    gh.singleton<_i21.ISettingsRepository>(
      () => _i22.SettingsRepositoryImpl(
        gh<_i9.SettingsLocalDatasource>(),
        gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_i17.IModelManagerRepository>(
      () => _i18.ModelManagerRepositoryImpl(
        gh<_i7.ModelDownloadDatasource>(),
        gh<_i5.Logger>(),
      ),
    );

    // ---- History Feature Data Layer ----
    gh.singleton<_i11.HistoryLocalDatasource>(
      () => _i11.HistoryLocalDatasource(gh<_i8.AppDatabase>()),
    );

    gh.singleton<_i12.IHistoryRepository>(
      () => _i13.HistoryRepositoryImpl(
        gh<_i11.HistoryLocalDatasource>(),
        gh<_i5.Logger>(),
      ),
    );

    // ---- History Feature Use Cases ----
    gh.factory<_i14.GetAllSessions>(
      () => _i14.GetAllSessions(gh<_i12.IHistoryRepository>()),
    );
    gh.factory<_i15.GetSessionById>(
      () => _i15.GetSessionById(gh<_i12.IHistoryRepository>()),
    );
    gh.factory<_i16.DeleteSession>(
      () => _i16.DeleteSession(gh<_i12.IHistoryRepository>()),
    );
    gh.factory<_i19.SearchSessions>(
      () => _i19.SearchSessions(gh<_i12.IHistoryRepository>()),
    );
    gh.factory<_i20.CopySessionText>(
      () => _i20.CopySessionText(gh<_i12.IHistoryRepository>()),
    );

    // ---- Settings Feature Use Cases ----
    gh.factory<_i25.GetSettings>(
      () => _i25.GetSettings(gh<_i21.ISettingsRepository>()),
    );
    gh.factory<_i28.UpdateSettings>(
      () => _i28.UpdateSettings(gh<_i21.ISettingsRepository>()),
    );
    gh.factory<_i24.GetAvailableModels>(
      () => _i24.GetAvailableModels(gh<_i17.IModelManagerRepository>()),
    );
    gh.factory<_i27.GetDownloadedModels>(
      () => _i27.GetDownloadedModels(gh<_i17.IModelManagerRepository>()),
    );
    gh.factory<_i26.DownloadModel>(
      () => _i26.DownloadModel(gh<_i17.IModelManagerRepository>()),
    );
    gh.factory<_i29.DeleteModel>(
      () => _i29.DeleteModel(gh<_i17.IModelManagerRepository>()),
    );

    // ---- BLoCs ----
    gh.singleton<_i23.HistoryBloc>(
      () => _i23.HistoryBloc(
        gh<_i14.GetAllSessions>(),
        gh<_i19.SearchSessions>(),
        gh<_i16.DeleteSession>(),
      ),
    );

    gh.singleton<_i30.SettingsBloc>(
      () => _i30.SettingsBloc(
        gh<_i25.GetSettings>(),
        gh<_i28.UpdateSettings>(),
        gh<_i24.GetAvailableModels>(),
        gh<_i27.GetDownloadedModels>(),
        gh<_i26.DownloadModel>(),
        gh<_i5.Logger>(),
      ),
    );

    return this;
  }
}

class _$RegisterModule extends _i2.RegisterModule {}
