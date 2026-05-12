import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/model_info_entity.dart';
import '../repositories/i_model_manager_repository.dart';

/// Use case to list all models available for download.
///
/// Returns the full model registry from the app's configuration,
/// including download URLs and metadata.
@injectable
class GetAvailableModels extends UseCase<List<ModelInfoEntity>, NoParams> {
  final IModelManagerRepository _repository;

  const GetAvailableModels(this._repository);

  @override
  Future<Either<Failure, List<ModelInfoEntity>>> call(NoParams params) {
    return _repository.getAvailableModels();
  }
}
