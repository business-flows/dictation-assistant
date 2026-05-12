import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_model_manager_repository.dart';

/// Parameters for [DownloadModel] use case.
class DownloadModelParams extends Equatable {
  /// The model ID to download.
  final String modelId;

  const DownloadModelParams({required this.modelId});

  @override
  List<Object?> get props => [modelId];
}

/// Use case to download a Whisper model.
///
/// Initiates the download and returns initial progress.
/// Listen to the repository's [downloadProgressStream] for
/// real-time progress updates.
@injectable
class DownloadModel extends UseCase<Unit, DownloadModelParams> {
  final IModelManagerRepository _repository;

  const DownloadModel(this._repository);

  @override
  Future<Either<Failure, Unit>> call(DownloadModelParams params) {
    return _repository.downloadModel(params.modelId).then(
          (result) => result.fold(
            Left.new,
            (_) => const Right(unit),
          ),
        );
  }
}
