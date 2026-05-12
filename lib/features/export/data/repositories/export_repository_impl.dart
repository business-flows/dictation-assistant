import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/export_options_entity.dart';
import '../../domain/repositories/i_export_repository.dart';
import '../datasources/local/docx_generator.dart';

/// Implementation of [IExportRepository] using the docx_dart package.
///
/// Generates formatted Microsoft Word (.docx) documents from
/// dictation session data. Handles both simple text export and
/// full session export with metadata.
class ExportRepositoryImpl implements IExportRepository {
  final DocxGenerator _docxGenerator;
  final Logger _logger;

  ExportRepositoryImpl({
    required DocxGenerator docxGenerator,
    Logger? logger,
  })  : _docxGenerator = docxGenerator,
        _logger = logger ?? Logger();

  @override
  Future<Either<Failure, String>> exportToDocx({
    required String sessionId,
    required String text,
    required ExportOptionsEntity options,
    required String savePath,
  }) async {
    try {
      _logger.i('Exporting text to DOCX: $savePath');

      // Ensure directory exists
      final dir = Directory(p.dirname(savePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fileName = options.customFilename ?? sessionId;
      final title = 'Dictation - ${_formatDate(DateTime.now().toUtc())}';

      await _docxGenerator.generate(
        outputPath: savePath,
        title: title,
        subtitle: options.includeMetadata ? 'Session: $sessionId' : null,
        bodyText: text,
      );

      _logger.i('DOCX export completed: $savePath');
      return Right(savePath);
    } catch (e, stackTrace) {
      _logger.e('DOCX export failed: $e', error: e, stackTrace: stackTrace);
      return Left(ExportFailure('Failed to export DOCX: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> exportSessionToDocx({
    required SessionEntity session,
    required String savePath,
  }) async {
    try {
      _logger.i('Exporting session ${session.id} to DOCX: $savePath');

      // Ensure directory exists
      final dir = Directory(p.dirname(savePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final title = 'Dictation - ${_formatDate(session.createdAt)}';
      final effectiveText = session.getEffectiveText(preferRefined: true);

      await _docxGenerator.generate(
        outputPath: savePath,
        title: title,
        subtitle: 'Session: ${session.id}',
        bodyText: effectiveText,
        refinedText: session.hasRefinedText ? session.refinedText : null,
        isRtl: session.isRtl,
      );

      _logger.i('Session DOCX export completed: $savePath');
      return Right(savePath);
    } catch (e, stackTrace) {
      _logger.e('Session DOCX export failed: $e', error: e, stackTrace: stackTrace);
      return Left(ExportFailure('Failed to export session DOCX: $e'));
    }
  }

  /// Formats a DateTime for document display.
  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
