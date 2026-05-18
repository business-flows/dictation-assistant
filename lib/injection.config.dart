// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:dio/dio.dart' as _i4;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i3;
import 'package:get_it/get_it.dart' as _i1;
import 'package:injectable/injectable.dart' as _i2;
import 'package:logger/logger.dart' as _i5;

import 'core/utils/audio_file_naming.dart' as _i6;
import 'features/dictation/data/datasources/local/audio_local_datasource.dart' as _adl;
import 'features/dictation/data/datasources/local/session_local_datasource.dart' as _sdl;
import 'features/dictation/data/repositories/session_repository_impl.dart' as _sri;
import 'features/dictation/data/repositories/transcription_repository_impl.dart' as _tri;
import 'features/dictation/domain/repositories/i_session_repository.dart' as _isr;
import 'features/dictation/domain/repositories/i_transcription_repository.dart' as _itr;
import 'features/dictation/domain/usecases/get_current_session.dart' as _gcs;
import 'features/dictation/domain/usecases/pause_dictation.dart' as _pd;
import 'features/dictation/domain/usecases/process_audio_chunk.dart' as _pac;
import 'features/dictation/domain/usecases/resume_dictation.dart' as _rd;
import 'features/dictation/domain/usecases/start_dictation.dart' as _sd;
import 'features/dictation/domain/usecases/stop_dictation.dart' as _std;
import 'features/dictation/domain/usecases/update_session_text.dart' as _ust;
import 'features/dictation/presentation/bloc/dictation_bloc.dart' as _db;
import 'features/export/data/datasources/local/docx_generator.dart' as _dg;
import 'features/export/data/datasources/platform/clipboard_datasource.dart' as _cd;
import 'features/export/data/datasources/platform/file_picker_datasource.dart' as _fpd;
import 'features/export/data/repositories/clipboard_repository_impl.dart' as _cri;
import 'features/export/data/repositories/export_repository_impl.dart' as _eri;
import 'features/export/domain/repositories/i_clipboard_repository.dart' as _icr;
import 'features/export/domain/repositories/i_export_repository.dart' as _ier;
import 'features/export/domain/usecases/copy_to_clipboard.dart' as _ctc;
import 'features/export/domain/usecases/export_to_docx.dart' as _etd;
import 'features/export/domain/usecases/share_text.dart' as _st;
import 'features/export/presentation/bloc/export_bloc.dart' as _eb;
import 'features/history/data/datasources/local/history_local_datasource.dart' as _hld;
import 'features/history/data/repositories/history_repository_impl.dart' as _hri;
import 'features/history/domain/repositories/i_history_repository.dart' as _ihr;
import 'features/history/domain/usecases/copy_session_text.dart' as _cst;
import 'features/history/domain/usecases/delete_session.dart' as _ds;
import 'features/history/domain/usecases/get_all_sessions.dart' as _gas;
import 'features/history/domain/usecases/get_session_by_id.dart' as _gsbi;
import 'features/history/domain/usecases/search_sessions.dart' as _ss;
import 'features/history/presentation/bloc/history_bloc.dart' as _hb;
import 'features/refinement/data/datasources/remote/llm_remote_datasource.dart' as _llds;
import 'features/refinement/data/repositories/llm_repository_impl.dart' as _llri;
import 'features/refinement/domain/repositories/i_llm_repository.dart' as _illm;
import 'features/refinement/domain/usecases/accept_or_discard_refinement.dart' as _aod;
import 'features/refinement/domain/usecases/refine_text.dart' as _rt;
import 'features/refinement/domain/usecases/stream_refinement.dart' as _sref;
import 'features/refinement/presentation/bloc/refinement_bloc.dart' as _rb;
import 'features/settings/data/datasources/local/settings_local_datasource.dart' as _setld;
import 'features/settings/data/datasources/remote/model_download_datasource.dart' as _mdd;
import 'features/settings/data/repositories/model_manager_repository_impl.dart' as _mmri;
import 'features/settings/data/repositories/settings_repository_impl.dart' as _setri;
import 'features/settings/domain/repositories/i_model_manager_repository.dart' as _imm;
import 'features/settings/domain/repositories/i_settings_repository.dart' as _iset;
import 'features/settings/domain/usecases/delete_model.dart' as _dm;
import 'features/settings/domain/usecases/download_model.dart' as _dlm;
import 'features/settings/domain/usecases/get_available_models.dart' as _gam;
import 'features/settings/domain/usecases/get_downloaded_models.dart' as _gdm;
import 'features/settings/domain/usecases/get_settings.dart' as _getset;
import 'features/settings/domain/usecases/update_settings.dart' as _upset;
import 'features/settings/presentation/bloc/settings_bloc.dart' as _sb;
import 'services/app_database.dart' as _i10;
import 'services/audio_service.dart' as _i20;
import 'services/chunk_processor.dart' as _cp;

import 'services/whisper_service.dart' as _ws;

/// Injectable module providing third-party dependencies.
@_i2.module
abstract class RegisterModule {
  /// Provides a singleton [FlutterSecureStorage] instance.
  @_i2.singleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();

  /// Provides a singleton [Dio] HTTP client with timeouts.
  @_i2.singleton
  Dio get dio => Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(minutes: 2),
  ));

  /// Provides a singleton [Logger] instance.
  @_i2.singleton
  Logger get logger => Logger();
}

/// Configures dependency injection for the Dictation Assistant app.
extension GetItInjectableX on _i1.GetIt {
  /// Initializes all registered dependencies.
  Future<_i1.GetIt> init() async {
    final gh = _i2.GetItHelper(this, 'production');
    final registerModule = _$RegisterModule();

    // ================================================================
    // THIRD-PARTY DEPENDENCIES
    // ================================================================
    gh.singleton<_i3.FlutterSecureStorage>(registerModule.secureStorage);
    gh.singleton<_i4.Dio>(registerModule.dio);
    gh.singleton<_i5.Logger>(registerModule.logger);

    // ================================================================
    // CORE SERVICES
    // ================================================================
    gh.singleton<_i10.AppDatabase>(() => _i10.AppDatabase());

    gh.singleton<_i20.AudioService>(
      () => _i20.AudioServiceImpl(logger: gh<_i5.Logger>()),
    );

    gh.singleton<_ws.WhisperService>(
      () => _ws.WhisperServiceImpl(logger: gh<_i5.Logger>()),
    );

    gh.singleton<_cp.ChunkProcessor>(
      () => _cp.ChunkProcessor(
        audioService: gh<_i20.AudioService>(),
        whisperService: gh<_ws.WhisperService>(),
        database: gh<_i10.AppDatabase>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    // ================================================================
    // DATA SOURCES
    // ================================================================
    gh.singleton<_sdl.SessionLocalDataSource>(
      () => _sdl.SessionLocalDataSource(
        database: gh<_i10.AppDatabase>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_adl.AudioLocalDataSource>(
      () => _adl.AudioLocalDataSource(logger: gh<_i5.Logger>()),
    );

    gh.singleton<_hld.HistoryLocalDatasource>(
      () => _hld.HistoryLocalDatasource(gh<_i10.AppDatabase>()),
    );

    gh.singleton<_setld.SettingsLocalDatasource>(
      () => _setld.SettingsLocalDatasource(
        gh<_i10.AppDatabase>(),
        gh<_i3.FlutterSecureStorage>(),
      ),
    );

    gh.singleton<_mdd.ModelDownloadDatasource>(
      () => _mdd.ModelDownloadDatasource(
        gh<_i4.Dio>(),
        gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_llds.LlmRemoteDataSource>(
      () => _llds.LlmRemoteDataSource(
        dio: gh<_i4.Dio>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_dg.DocxGenerator>(
      () => _dg.DocxGenerator(),
    );

    gh.singleton<_cd.ClipboardDataSource>(
      () => _cd.ClipboardDataSource(),
    );

    gh.singleton<_fpd.FilePickerDataSource>(
      () => _fpd.FilePickerDataSource(),
    );

    // ================================================================
    // REPOSITORIES
    // ================================================================
    gh.singleton<_isr.ISessionRepository>(
      () => _sri.SessionRepositoryImpl(
        dataSource: gh<_sdl.SessionLocalDataSource>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_itr.ITranscriptionRepository>(
      () => _tri.TranscriptionRepositoryImpl(
        whisperService: gh<_ws.WhisperService>(),
        audioDataSource: gh<_adl.AudioLocalDataSource>(),
        sessionDataSource: gh<_sdl.SessionLocalDataSource>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_ihr.IHistoryRepository>(
      () => _hri.HistoryRepositoryImpl(
        gh<_hld.HistoryLocalDatasource>(),
        gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_iset.ISettingsRepository>(
      () => _setri.SettingsRepositoryImpl(
        gh<_setld.SettingsLocalDatasource>(),
        gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_imm.IModelManagerRepository>(
      () => _mmri.ModelManagerRepositoryImpl(
        gh<_mdd.ModelDownloadDatasource>(),
        gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_illm.ILLMRepository>(
      () => _llri.LlmRepositoryImpl(
        remoteDataSource: gh<_llds.LlmRemoteDataSource>(),
        database: gh<_i10.AppDatabase>(),
        dio: gh<_i4.Dio>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_ier.IExportRepository>(
      () => _eri.ExportRepositoryImpl(
        docxGenerator: gh<_dg.DocxGenerator>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_icr.IClipboardRepository>(
      () => _cri.ClipboardRepositoryImpl(
        logger: gh<_i5.Logger>(),
      ),
    );

    // ================================================================
    // USE CASES — Dictation
    // ================================================================
    gh.factory<_sd.StartDictation>(
      () => _sd.StartDictation(
        sessionRepository: gh<_isr.ISessionRepository>(),
        audioService: gh<_i20.AudioService>(),
        chunkProcessor: gh<_cp.ChunkProcessor>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.factory<_std.StopDictation>(
      () => _std.StopDictation(
        sessionRepository: gh<_isr.ISessionRepository>(),
        audioService: gh<_i20.AudioService>(),
        chunkProcessor: gh<_cp.ChunkProcessor>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.factory<_pd.PauseDictation>(
      () => _pd.PauseDictation(
        sessionRepository: gh<_isr.ISessionRepository>(),
        audioService: gh<_i20.AudioService>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.factory<_rd.ResumeDictation>(
      () => _rd.ResumeDictation(
        sessionRepository: gh<_isr.ISessionRepository>(),
        audioService: gh<_i20.AudioService>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.factory<_pac.ProcessAudioChunk>(
      () => _pac.ProcessAudioChunk(
        transcriptionRepository: gh<_itr.ITranscriptionRepository>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.factory<_gcs.GetCurrentSession>(
      () => _gcs.GetCurrentSession(
        sessionRepository: gh<_isr.ISessionRepository>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.factory<_ust.UpdateSessionText>(
      () => _ust.UpdateSessionText(
        sessionRepository: gh<_isr.ISessionRepository>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    // ================================================================
    // USE CASES — History
    // ================================================================
    gh.factory<_gas.GetAllSessions>(
      () => _gas.GetAllSessions(gh<_ihr.IHistoryRepository>()),
    );

    gh.factory<_gsbi.GetSessionById>(
      () => _gsbi.GetSessionById(gh<_ihr.IHistoryRepository>()),
    );

    gh.factory<_ds.DeleteSession>(
      () => _ds.DeleteSession(gh<_ihr.IHistoryRepository>()),
    );

    gh.factory<_ss.SearchSessions>(
      () => _ss.SearchSessions(gh<_ihr.IHistoryRepository>()),
    );

    gh.factory<_cst.CopySessionText>(
      () => _cst.CopySessionText(gh<_ihr.IHistoryRepository>()),
    );

    // ================================================================
    // USE CASES — Settings
    // ================================================================
    gh.factory<_getset.GetSettings>(
      () => _getset.GetSettings(gh<_iset.ISettingsRepository>()),
    );

    gh.factory<_upset.UpdateSettings>(
      () => _upset.UpdateSettings(gh<_iset.ISettingsRepository>()),
    );

    gh.factory<_gam.GetAvailableModels>(
      () => _gam.GetAvailableModels(gh<_imm.IModelManagerRepository>()),
    );

    gh.factory<_gdm.GetDownloadedModels>(
      () => _gdm.GetDownloadedModels(gh<_imm.IModelManagerRepository>()),
    );

    gh.factory<_dlm.DownloadModel>(
      () => _dlm.DownloadModel(gh<_imm.IModelManagerRepository>()),
    );

    gh.factory<_dm.DeleteModel>(
      () => _dm.DeleteModel(gh<_imm.IModelManagerRepository>()),
    );

    // ================================================================
    // USE CASES — Refinement
    // ================================================================
    gh.factory<_rt.RefineText>(
      () => _rt.RefineText(gh<_illm.ILLMRepository>()),
    );

    gh.factory<_sref.StreamRefinement>(
      () => _sref.StreamRefinement(gh<_illm.ILLMRepository>()),
    );

    gh.factory<_aod.AcceptRefinement>(
      () => _aod.AcceptRefinement(gh<_isr.ISessionRepository>()),
    );

    gh.factory<_aod.DiscardRefinement>(
      () => _aod.DiscardRefinement(gh<_isr.ISessionRepository>()),
    );

    // ================================================================
    // USE CASES — Export
    // ================================================================
    gh.factory<_etd.ExportToDocx>(
      () => _etd.ExportToDocx(gh<_ier.IExportRepository>()),
    );

    gh.factory<_ctc.CopyToClipboard>(
      () => _ctc.CopyToClipboard(gh<_icr.IClipboardRepository>()),
    );

    gh.factory<_st.ShareText>(
      () => _st.ShareText(),
    );

    // ================================================================
    // BLoCs
    // ================================================================
    gh.singleton<_db.DictationBloc>(
      () => _db.DictationBloc(
        startDictation: gh<_sd.StartDictation>(),
        stopDictation: gh<_std.StopDictation>(),
        audioService: gh<_i20.AudioService>(),
        chunkProcessor: gh<_cp.ChunkProcessor>(),
        whisperService: gh<_ws.WhisperService>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.singleton<_hb.HistoryBloc>(
      () => _hb.HistoryBloc(
        gh<_gas.GetAllSessions>(),
        gh<_ss.SearchSessions>(),
        gh<_ds.DeleteSession>(),
      ),
    );

    gh.singleton<_sb.SettingsBloc>(
      () => _sb.SettingsBloc(
        gh<_getset.GetSettings>(),
        gh<_upset.UpdateSettings>(),
        gh<_gam.GetAvailableModels>(),
        gh<_gdm.GetDownloadedModels>(),
        gh<_dlm.DownloadModel>(),
        gh<_dm.DeleteModel>(),
        gh<_i5.Logger>(),
      ),
    );

    gh.factory<_rb.RefinementBloc>(
      () => _rb.RefinementBloc(
        streamRefinement: gh<_sref.StreamRefinement>(),
        acceptRefinement: gh<_aod.AcceptRefinement>(),
        discardRefinement: gh<_aod.DiscardRefinement>(),
        logger: gh<_i5.Logger>(),
      ),
    );

    gh.factory<_eb.ExportBloc>(
      () => _eb.ExportBloc(
        exportToDocx: gh<_etd.ExportToDocx>(),
        copyToClipboard: gh<_ctc.CopyToClipboard>(),
        shareText: gh<_st.ShareText>(),
        filePicker: gh<_fpd.FilePickerDataSource>(),
      ),
    );

    return this;
  }
}

class _$RegisterModul