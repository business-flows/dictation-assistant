import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/export_options_entity.dart';
import '../repositories/i_export_repository.dart';

/// Use case for exporting text to a DOCX file.
///
/// Creates a formatted Word document from the given text and options.
/// The save path must be provided by the caller (typically from a
/// file picker).
///
/// Example:
/// ```dart
/// final result = await exportToDocx(ExportToDocxParams(
///   sessionId: session.id,
///   text: session.transcribedText,
///   options: ExportOptionsEntity(),
///   savePath: '/path/to/output.docx',
/// ));
/// ```
class ExportToDocx implements UseCase<String, ExportToDocxParams> {
  final IExportRepository _repository;

  const ExportToDocx(this._repository);

  @override
  Future<Either<Failure, String>> call(ExportToDocxParams params) {
    return _repository.exportToDocx(
      sessionId: params.sessionId,
      text: params.text,
      options: params.options,
      savePath: params.savePath,
    );
  }
}

/// Parameters for [ExportToDocx] use case.
class ExportToDocxParams extends Equatable {
  /// The session ID for reference.
  final String sessionId;

  /// The text content to export.
  final String text;

  /// Export configuration options.
  final ExportOptionsEntity options;

  /// Absolute file path where the DOCX should be saved.
  final String savePath;

  const ExportToDocxParams({
    required this.sessionId,
    required this.text,
    required this.options,
    required this.savePath,
  });

  @override
  List<Object?> get props => [sessionId, text, options, savePath];
}
