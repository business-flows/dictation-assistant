import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/settings_entity.dart';
import '../repositories/i_settings_repository.dart';

/// Parameters for [UpdateSettings] use case.
class UpdateSettingsParams extends Equatable {
  /// The settings to persist.
  final SettingsEntity settings;

  const UpdateSettingsParams({required this.settings});

  @override
  List<Object?> get props => [settings];
}

/// Use case to update the application settings.
///
/// Persists all settings fields to the local database.
@injectable
class UpdateSettings extends UseCase<Unit, UpdateSettingsParams> {
  final ISettingsRepository _repository;

  const UpdateSettings(this._repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateSettingsParams params) {
    return _repository.updateSettings(params.settings);
  }
}
