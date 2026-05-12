import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_history_repository.dart';

/// Parameters for [DeleteSession] use case.
class DeleteSessionParams extends Equatable {
  /// The session ID to delete.
  final String id;

  const DeleteSessionParams({required this.id});

  @override
  List<Object?> get props => [id];
}

/// Use case to delete a session and its associated audio file.
///
/// Removes the session from the database (cascading to audio chunks)
/// and deletes the audio file from the filesystem.
@injectable
class DeleteSession extends UseCase<Unit, DeleteSessionParams> {
  final IHistoryRepository _repository;

  const DeleteSession(this._repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteSessionParams params) {
    return _repository.deleteSession(params.id);
  }
}
