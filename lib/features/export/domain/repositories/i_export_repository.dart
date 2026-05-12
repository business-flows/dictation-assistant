import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/export_options_entity.dart';

/// Abstract repository interface for document export operations.
///
/// Provides methods to export dictation sessions to various formats,
/// primarily DOCX (Microsoft Word) documents.
abstract class IExportRepository {
  /// Export text to a DOCX file at the specified path.
  ///
  /// Creates a formatted Word document containing the dictation text
  /// and optional metadata. The file is saved directly to [savePath]
  /// without showing a file picker.
  ///
  /// [sessionId] - The session ID for reference in the document.
  /// [text] - The text content to export.
  /// [options] - Export configuration (metadata, refined text preference).
  /// [savePath] - Absolute file path where the DOCX should be saved.
  ///
  /// Returns the saved file path on success.
  Future<Either<Failure, String>> exportToDocx({
    required String sessionId,
    required String text,
    required ExportOptionsEntity options,
    required String savePath,
  });

  /// Export a complete session to DOCX.
  ///
  /// Creates a formatted Word document from a [SessionEntity] with
  /// all available data including both original and refined text,
  /// metadata, and proper formatting.
  ///
  /// [session] - The complete session entity with all data.
  /// [savePath] - Absolute file path where the DOCX should be saved.
  ///
  /// Returns the saved file path on success.
  Future<Either<Failure, String>> exportSessionToDocx({
    required SessionEntity session,
    required String savePath,
  });
}
