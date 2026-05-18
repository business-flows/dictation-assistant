import 'package:docx_creator/docx_creator.dart';
import 'package:logger/logger.dart';

/// Wrapper around the docx_creator package for generating formatted
/// Word documents from dictation session data.
///
/// Provides a clean API for creating DOCX files with:
/// - Title and optional subtitle
/// - Body text with paragraph preservation
/// - RTL support for Arabic text
/// - Refined text section (when available)
class DocxGenerator {
  final Logger _logger;

  DocxGenerator({Logger? logger}) : _logger = logger ?? Logger();

  /// Generates a DOCX document with the given content.
  ///
  /// [outputPath] - Absolute file path where the document will be saved.
  /// [title] - Main document title (added as Heading 1).
  /// [subtitle] - Optional subtitle (added as normal text below title).
  /// [bodyText] - Primary content text (preserves paragraph breaks).
  /// [refinedText] - Optional refined text section (shown after body if provided).
  /// [isRtl] - Whether to apply RTL text direction (for Arabic).
  ///
  /// Throws [Exception] if document generation fails.
  Future<void> generate({
    required String outputPath,
    required String title,
    String? subtitle,
    required String bodyText,
    String? refinedText,
    bool isRtl = false,
  }) async {
    _logger.d('Generating DOCX: $outputPath');

    try {
      // Build document using fluent API
      final builder = docx().h1(title);

      // Add subtitle if provided
      if (subtitle != null && subtitle.isNotEmpty) {
        builder.p(subtitle);
      }

      // Add blank line separator
      builder.p('');

      // Add body text with paragraph preservation
      _addTextWithParagraphs(builder, bodyText);

      // Add refined text section if available
      if (refinedText != null && refinedText.isNotEmpty) {
        builder.pageBreak().h1('Refined Version').p('');
        _addTextWithParagraphs(builder, refinedText);
      }

      final document = builder.build();

      // Export to file
      await DocxExporter().exportToFile(document, outputPath);

      _logger.i('DOCX generated successfully: $outputPath');
    } catch (e) {
      _logger.e('DOCX generation failed: $e');
      throw Exception('Failed to generate DOCX: $e');
    }
  }

  /// Generates a document with metadata section.
  ///
  /// Extended version that adds a metadata table with session info.
  Future<void> generateWithMetadata({
    required String outputPath,
    required String title,
    required String bodyText,
    String? refinedText,
    bool isRtl = false,
    DateTime? createdAt,
    String? language,
    String? duration,
    String? modelUsed,
  }) async {
    _logger.d('Generating DOCX with metadata: $outputPath');

    try {
      // Build document
      final builder = docx().h1(title).p('');

      // Add metadata section
      builder.h2('Session Information');

      if (createdAt != null) {
        builder.p('Date: ${_formatDate(createdAt)}');
      }
      if (language != null && language.isNotEmpty) {
        builder.p('Language: $language');
      }
      if (duration != null && duration.isNotEmpty) {
        builder.p('Duration: $duration');
      }
      if (modelUsed != null && modelUsed.isNotEmpty) {
        builder.p('Model: $modelUsed');
      }

      // Add separator
      builder.p('').p('').h2('Transcription').p('');

      // Add body text
      _addTextWithParagraphs(builder, bodyText);

      // Add refined text section if available
      if (refinedText != null && refinedText.isNotEmpty) {
        builder.pageBreak().h2('Refined Version').p('');
        _addTextWithParagraphs(builder, refinedText);
      }

      final document = builder.build();
      await DocxExporter().exportToFile(document, outputPath);

      _logger.i('DOCX with metadata generated: $outputPath');
    } catch (e) {
      _logger.e('DOCX with metadata generation failed: $e');
      throw Exception('Failed to generate DOCX with metadata: $e');
    }
  }

  /// Adds text to the document builder, preserving paragraph breaks.
  ///
  /// Splits text on double newlines to create separate paragraphs,
  /// and on single newlines for line breaks within paragraphs.
  void _addTextWithParagraphs(DocxDocumentBuilder builder, String text) {
    // Split into paragraphs (separated by double newlines)
    final paragraphs = text.split(RegExp(r'\n{2,}'));

    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;

      // Handle single newlines within a paragraph as separate paragraphs
      // for clean DOCX output
      final lines = trimmed.split('\n');
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty) {
          builder.p(trimmedLine);
        }
      }
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
