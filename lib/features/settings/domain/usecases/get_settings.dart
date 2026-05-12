import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/settings_entity.dart';
import '../repositories/i_settings_repository.dart';

/// Use case to retrieve the current application settings.
///
/// Returns default settings if none have been configured yet.
@injectable
class GetSettings extends UseCase<SettingsEntity, NoParams> {
  final ISettingsRepository _repository;

  const GetSettings(this._repository);

  @override
  Future<Either<Failure, SettingsEntity>> call(NoParams params) {
    return _repository.getSettings();
  }
}
