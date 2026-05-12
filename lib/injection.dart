import 'package:get_it/get_it.dart';

import 'features/dictation/domain/usecases/get_current_session.dart';
import 'features/dictation/domain/usecases/start_dictation.dart';
import 'features/dictation/domain/usecases/stop_dictation.dart';
import 'features/dictation/domain/usecases/update_session_text.dart';
import 'features/dictation/presentation/bloc/dictation_bloc.dart';
import 'features/history/presentation/bloc/history_bloc.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';

final GetIt getIt = GetIt.instance;

/// Configures dependency injection for the application.
///
/// This is a manual setup that will be replaced with injectable code generation
/// once all use case implementations are in place.
Future<void> configureDependencies() async {
  // Use cases (throw UnimplementedError until implemented by another developer)
  getIt.registerLazySingleton<StartDictation>(() => StartDictation());
  getIt.registerLazySingleton<StopDictation>(() => StopDictation());
  getIt.registerLazySingleton<GetCurrentSession>(() => GetCurrentSession());
  getIt.registerLazySingleton<UpdateSessionText>(() => UpdateSessionText());

  // BLoCs
  getIt.registerFactory<DictationBloc>(
    () => DictationBloc(
      startDictation: getIt<StartDictation>(),
      stopDictation: getIt<StopDictation>(),
      getCurrentSession: getIt<GetCurrentSession>(),
      updateSessionText: getIt<UpdateSessionText>(),
    ),
  );

  getIt.registerFactory<HistoryBloc>(() => HistoryBloc());
  getIt.registerFactory<SettingsBloc>(() => SettingsBloc());
}
