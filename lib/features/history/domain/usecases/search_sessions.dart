import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/session_summary_entity.dart';
import '../repositories/i_history_repository.dart';

/// Parameters for [SearchSessions] use case.
class SearchSessionsParams extends Equatable {
  /// The search query string.
  final String query;

  const SearchSessionsParams({required this.query});

  @override
  List<Object?> get props => [query];
}

/// Use case to search sessions by query string.
///
/// Performs case-insensitive search on transcription content.
/// Returns matching sessions ordered by creation time (newest first).
@injectable
class SearchSessions extends UseCase<List<SessionSummaryEntity>, SearchSessionsParams> {
  final IHistoryRepository _repository;

  const SearchSessions(this._repository);

  @override
  Future<Either<Failure, List<SessionSummaryEntity>>> call(SearchSessionsParams params) {
    return _repository.searchSessions(params.query);
  }
}
