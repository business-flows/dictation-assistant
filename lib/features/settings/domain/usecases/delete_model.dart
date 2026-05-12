import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_model_manager_repository.dart';

/// Parameters for [DeleteModel] use case.
class DeleteModelParams extends Equatable {
  /// The model ID to delete.
  final String modelId;

  const DeleteModelParams({required this.modelId});

  @override
  List<Object?> get props => [modelId];
}

/// Use case to delete a downloaded model from local storage.
///
/// Removes the model file from the filesystem to free up space.
@injectable
class DeleteModel extends UseCase<Unit, DeleteModelParams> {
  final IModelManagerRepository _repository;

  const DeleteModel(this._repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteModelParams params) {
    return _repository.deleteModel(params.modelId);
  }
}
