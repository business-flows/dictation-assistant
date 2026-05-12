import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/session_entity.dart';
import '../repositories/i_history_repository.dart';

/// Parameters for [GetSessionById] use case.
class GetSessionByIdParams extends Equatable {
  /// The session ID to retrieve.
  final String id;

  const GetSessionByIdParams({required this.id});

  @override
  List<Object?> get props => [id];
}

/// Use case to retrieve a full session by its ID.
///
/// Returns a [SessionEntity] with complete transcription text and metadata.
/// Use this for the session detail screen.
@injectable
class GetSessionById extends UseCase<SessionEntity, GetSessionByIdParams> {
  final IHistoryRepository _repository;

  const GetSessionById(this._repository);

  @override
  Future<Either<Failure, SessionEntity>> call(GetSessionByIdParams params) {
    return _repository.getSessionDetail(params.id);
  }
}
