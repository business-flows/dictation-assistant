import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../services/app_database.dart';

/// Use case for accepting a refined text and persisting it to the database.
///
/// Updates the session's [refinedText] field with the accepted text.
/// The session can then be exported with the refined version.
class AcceptRefinement implements UseCase<Unit, AcceptRefinementParams> {
  final AppDatabase _database;

  const AcceptRefinement(this._database);

  @override
  Future<Either<Failure, Unit>> call(AcceptRefinementParams params) async {
    try {
      await _database.updateRefinedText(params.sessionId, params.refinedText);
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Failed to save refined text: $e'));
    }
  }
}

/// Parameters for [AcceptRefinement] use case.
class AcceptRefinementParams extends Equatable {
  /// The session ID to update.
  final String sessionId;

  /// The refined text to save.
  final String refinedText;

  const AcceptRefinementParams({
    required this.sessionId,
    required this.refinedText,
  });

  @override
  List<Object?> get props => [sessionId, refinedText];
}

/// Use case for discarding a refined text.
///
/// Clears the session's [refinedText] field, reverting to the
/// original transcription only.
class DiscardRefinement implements UseCase<Unit, DiscardRefinementParams> {
  final AppDatabase _database;

  const DiscardRefinement(this._database);

  @override
  Future<Either<Failure, Unit>> call(DiscardRefinementParams params) async {
    try {
      await _database.updateRefinedText(params.sessionId, null);
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Failed to discard refined text: $e'));
    }
  }
}

/// Parameters for [DiscardRefinement] use case.
class DiscardRefinementParams extends Equatable {
  /// The session ID to update.
  final String sessionId;

  const DiscardRefinementParams({
    required this.sessionId,
  });

  @override
  List<Object?> get props => [sessionId];
}
