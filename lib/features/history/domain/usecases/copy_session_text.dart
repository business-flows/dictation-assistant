import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_history_repository.dart';

/// Parameters for [CopySessionText] use case.
class CopySessionTextParams extends Equatable {
  /// The text to copy to clipboard.
  final String text;

  const CopySessionTextParams({required this.text});

  @override
  List<Object?> get props => [text];
}

/// Use case to copy session text to the system clipboard.
///
/// Can copy either transcribed or refined text depending on what
/// the user selects.
@injectable
class CopySessionText extends UseCase<Unit, CopySessionTextParams> {
  final IHistoryRepository _repository;

  const CopySessionText(this._repository);

  @override
  Future<Either<Failure, Unit>> call(CopySessionTextParams params) {
    return _repository.copyTextToClipboard(params.text);
  }
}
