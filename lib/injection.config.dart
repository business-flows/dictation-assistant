import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import 'core/utils/audio_file_naming.dart';
import 'core/utils/ulid_generator.dart';
import 'features/dictation/data/datasources/local/audio_local_datasource.dart';
import 'features/dictation/data/datasources/local/session_local_datasource.dart';
import 'features/dictation/data/repositories/session_repository_impl.dart';
import 'features/dictation/data/repositories/transcription_repository_impl.dart';
import 'features/dictation/domain/repositories/i_session_repository.dart';
import 'features/dictation/domain/repositories/i_transcription_repository.dart';
import 'features/dictation/domain/usecases/get_current_session.dart';
import 'features/dictation/domain/usecases/pause_dictation.dart';
import 'features/dictation/domain/usecases/process_audio_chunk.dart';
import 'features/dictation/domain/usecases/resume_dictation.dart';
import 'features/dictation/domain/usecases/start_dictation.dart';
import 'features/dictation/domain/usecases/stop_dictation.dart';
import 'features/dictation/domain/usecases/update_session_text.dart';
import 'features/dictation/presentation/bloc/dictation_bloc.dart';
import 'services/app_database.dart';
import 'services/audio_service.dart';
import 'services/chunk_processor.dart';
import 'services/whisper_service.dart';

/// Configures dependency injection for the Dictation Assistant app.
///
/// This extension method registers all services, repositories, use cases,
/// and BLoCs with GetIt. It is called during app initialization.
///
/// ```dart
/// await configureDependencies();
/// ```
extension GetItInjectableX on GetIt {
  /// Initializes dependencies and registers all types.
  @InjectableInit(
    initializerName: 'init',
    preferRelativeImports: true,
    asExtension: true,
  )
  Future<void> init() async {
    // ---- Core Services ----

    /// Logger instance for the entire application.
    registerLazySingleton<Logger>(
      () => Logger(),
    );

    /// Drift database instance.
    registerLazySingleton<AppDatabase>(
      () => AppDatabase(),
    );

    // ---- Audio & Transcription Services (@singleton) ----

    /// Audio recording service (singleton).
    ///
    /// Manages microphone recording via the `record` package.
    registerSingleton<AudioService>(
      AudioServiceImpl(
        logger: get<Logger>(),
      ),
    );

    /// Whisper.cpp transcription service (singleton).
    ///
    /// Manages model loading and transcription via whisper_ggml_plus.
    registerSingleton<WhisperService>(
      WhisperServiceImpl(
        logger: get<Logger>(),
      ),
    );

    /// Chunk processing orchestrator (singleton).
    ///
    /// Manages the real-time audio chunking and transcription pipeline.
    registerSingleton<ChunkProcessor>(
      ChunkProcessor(
        audioService: get<AudioService>(),
        whisperService: get<WhisperService>(),
        database: get<AppDatabase>(),
        logger: get<Logger>(),
      ),
    );

    // ---- Data Sources (@injectable) ----

    /// Local data source for session CRUD operations.
    registerFactory<SessionLocalDataSource>(
      () => SessionLocalDataSource(
        database: get<AppDatabase>(),
        logger: get<Logger>(),
      ),
    );

    /// Local data source for audio file I/O operations.
    registerFactory<AudioLocalDataSource>(
      () => AudioLocalDataSource(
        logger: get<Logger>(),
      ),
    );

    // ---- Repositories (@lazySingleton, as: IRepository) ----

    /// Session repository implementation.
    registerLazySingleton<ISessionRepository>(
      () => SessionRepositoryImpl(
        dataSource: get<SessionLocalDataSource>(),
        logger: get<Logger>(),
      ),
    );

    /// Transcription repository implementation.
    registerLazySingleton<ITranscriptionRepository>(
      () => TranscriptionRepositoryImpl(
        whisperService: get<WhisperService>(),
        audioDataSource: get<AudioLocalDataSource>(),
        sessionDataSource: get<SessionLocalDataSource>(),
        logger: get<Logger>(),
      ),
    );

    // ---- Use Cases (@injectable) ----

    /// Use case: Start a new dictation session.
    registerFactory<StartDictation>(
      () => StartDictation(
        sessionRepository: get<ISessionRepository>(),
        audioService: get<AudioService>(),
        chunkProcessor: get<ChunkProcessor>(),
        logger: get<Logger>(),
      ),
    );

    /// Use case: Stop the current dictation session.
    registerFactory<StopDictation>(
      () => StopDictation(
        sessionRepository: get<ISessionRepository>(),
        audioService: get<AudioService>(),
        chunkProcessor: get<ChunkProcessor>(),
        logger: get<Logger>(),
      ),
    );

    /// Use case: Pause the current dictation session.
    registerFactory<PauseDictation>(
      () => PauseDictation(
        sessionRepository: get<ISessionRepository>(),
        audioService: get<AudioService>(),
        logger: get<Logger>(),
      ),
    );

    /// Use case: Resume a paused dictation session.
    registerFactory<ResumeDictation>(
      () => ResumeDictation(
        sessionRepository: get<ISessionRepository>(),
        audioService: get<AudioService>(),
        logger: get<Logger>(),
      ),
    );

    /// Use case: Process a single audio chunk.
    registerFactory<ProcessAudioChunk>(
      () => ProcessAudioChunk(
        transcriptionRepository: get<ITranscriptionRepository>(),
        logger: get<Logger>(),
      ),
    );

    /// Use case: Get the current active session.
    registerFactory<GetCurrentSession>(
      () => GetCurrentSession(
        sessionRepository: get<ISessionRepository>(),
        logger: get<Logger>(),
      ),
    );

    /// Use case: Update session transcription text.
    registerFactory<UpdateSessionText>(
      () => UpdateSessionText(
        sessionRepository: get<ISessionRepository>(),
        logger: get<Logger>(),
      ),
    );

    // ---- BLoC (@injectable) ----

    /// Dictation feature BLoC.
    registerFactory<DictationBloc>(
      () => DictationBloc(
        startDictation: get<StartDictation>(),
        stopDictation: get<StopDictation>(),
        audioService: get<AudioService>(),
        chunkProcessor: get<ChunkProcessor>(),
        whisperService: get<WhisperService>(),
        logger: get<Logger>(),
      ),
    );
  }
}
