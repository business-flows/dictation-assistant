import 'package:get_it/get_it.dart';

import 'injection.config.dart';

/// Global GetIt instance for dependency injection.
final GetIt getIt = GetIt.instance;

/// Configures all dependencies for the application.
///
/// This function is called once at app startup. It registers all services,
/// repositories, use cases, and BLoCs through the generated [GetItInjectableX]
/// extension method.
///
/// To regenerate after adding new @injectable/@singleton/@lazySingleton:
///   dart run build_runner build --delete-conflicting-outputs
///
/// Dependencies are organized as follows:
/// - **Singletons**: AppDatabase, AudioService, WhisperService, ChunkProcessor
/// - **LazySingletons**: All repository implementations
/// - **Factories**: Use cases (created fresh per call)
/// - **Singletons**: BLoCs that need to persist across the app lifetime
Future<void> configureDependencies() async {
  await getIt.init();
}
