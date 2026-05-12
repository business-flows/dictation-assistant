import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/session_summary_entity.dart';
import '../repositories/i_history_repository.dart';

/// Use case to retrieve all sessions as a list of summaries.
///
/// Returns sessions ordered by creation time (newest first).
/// Use this for the history list screen.
@injectable
class GetAllSessions extends UseCase<List<SessionSummaryEntity>, NoParams> {
  final IHistoryRepository _repository;

  const GetAllSessions(this._repository);

  @override
  Future<Either<Failure, List<SessionSummaryEntity>>> call(NoParams params) {
    return _repository.getAllSessions();
  }
}
