import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_clipboard_repository.dart';

/// Use case for copying text to the system clipboard.
///
/// Simple use case that delegates to the clipboard repository.
/// Commonly used for quick copy actions in the UI.
///
/// Example:
/// ```dart
/// final result = await copyToClipboard(
///   CopyToClipboardParams(text: refinedText),
/// );
/// ```
class CopyToClipboard implements UseCase<Unit, CopyToClipboardParams> {
  final IClipboardRepository _repository;

  const CopyToClipboard(this._repository);

  @override
  Future<Either<Failure, Unit>> call(CopyToClipboardParams params) {
    return _repository.copyText(params.text);
  }
}

/// Parameters for [CopyToClipboard] use case.
class CopyToClipboardParams extends Equatable {
  /// The text to copy to the clipboard.
  final String text;

  const CopyToClipboardParams({required this.text});

  @override
  List<Object?> get props => [text];
}
