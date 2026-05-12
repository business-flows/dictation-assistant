import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/model_info_entity.dart';
import '../repositories/i_model_manager_repository.dart';

/// Use case to list all locally downloaded models.
///
/// Checks the filesystem for model files and returns those
/// that are available for local inference.
@injectable
class GetDownloadedModels extends UseCase<List<ModelInfoEntity>, NoParams> {
  final IModelManagerRepository _repository;

  const GetDownloadedModels(this._repository);

  @override
  Future<Either<Failure, List<ModelInfoEntity>>> call(NoParams params) {
    return _repository.getDownloadedModels();
  }
}
