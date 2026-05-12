import 'package:docx_dart/docx_dart.dart';
import 'package:logger/logger.dart';

/// Wrapper around the docx_dart package for generating formatted
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
      // Create a new document
      final doc = DocxDocument();

      // Add title as heading
      doc.addHeading(title, level: 1);

      // Add subtitle if provided
      if (subtitle != null && subtitle.isNotEmpty) {
        final subtitleRun = Run(
          text: subtitle,
          properties: RunProperties(
            color: '666666',
            fontSize: 20, // 10pt
            italics: true,
          ),
        );
        doc.addParagraph('');
        final subtitlePara = Paragraph(runs: [subtitleRun]);
        doc.document.body.addParagraph(subtitlePara);
      }

      // Add separator line
      doc.addParagraph('');
      doc.addParagraph('');

      // Add body text with paragraph preservation
      _addTextWithParagraphs(doc, bodyText, isRtl);

      // Add refined text section if available
      if (refinedText != null && refinedText.isNotEmpty) {
        doc.addPageBreak();
        doc.addHeading('Refined Version', level: 1);
        doc.addParagraph('');
        _addTextWithParagraphs(doc, refinedText, isRtl);
      }

      // Save the document
      doc.saveAs(outputPath);

      _logger.i('DOCX generated successfully: $outputPath');
    } catch (e) {
      _logger.e('DOCX generation failed: $e');
      throw Exception('Failed to generate DOCX: $e');
    }
  }

  /// Adds text to the document, preserving paragraph breaks.
  ///
  /// Splits text on double newlines to create separate paragraphs,
  /// and on single newlines for line breaks within paragraphs.
  void _addTextWithParagraphs(DocxDocument doc, String text, bool isRtl) {
    // Split into paragraphs (separated by double newlines)
    final paragraphs = text.split(RegExp(r'\n{2,}'));

    for (int i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i].trim();
      if (para.isEmpty) continue;

      // Handle single newlines within a paragraph as line breaks
      final lines = para.split('\n');

      if (lines.length == 1) {
        // Simple single-line paragraph
        final run = Run(
          text: para,
          properties: RunProperties(
            fontSize: 22, // 11pt
            rtlText: isRtl,
          ),
        );
        final paragraph = Paragraph(
          runs: [run],
          properties: ParagraphProperties(
            justification: isRtl ? Justification.right : Justification.left,
            spacing: ParagraphSpacing(line: 276), // 1.15 line spacing
          ),
        );
        doc.document.body.addParagraph(paragraph);
      } else {
        // Multi-line paragraph with line breaks
        final runs = <Run>[];
        for (int j = 0; j < lines.length; j++) {
          runs.add(
            Run(
              text: lines[j],
              properties: RunProperties(
                fontSize: 22,
                rtlText: isRtl,
              ),
            ),
          );
          if (j < lines.length - 1) {
            runs.add(Run(text: '', properties: RunProperties(breakLine: true)));
          }
        }
        final paragraph = Paragraph(
          runs: runs,
          properties: ParagraphProperties(
            justification: isRtl ? Justification.right : Justification.left,
            spacing: ParagraphSpacing(line: 276),
          ),
        );
        doc.document.body.addParagraph(paragraph);
      }
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
      final doc = DocxDocument();

      // Add title
      doc.addHeading(title, level: 1);
      doc.addParagraph('');

      // Add metadata section
      doc.addHeading('Session Information', level: 2);

      final metadataItems = <String, String?>{
        'Date': createdAt?.toLocal().toString().substring(0, 16),
        'Language': language,
        'Duration': duration,
        'Model': modelUsed,
      };

      for (final entry in metadataItems.entries) {
        if (entry.value != null && entry.value!.isNotEmpty) {
          final labelRun = Run(
            text: '${entry.key}: ',
            properties: RunProperties(
              bold: true,
              fontSize: 20,
              color: '333333',
            ),
          );
          final valueRun = Run(
            text: entry.value!,
            properties: RunProperties(
              fontSize: 20,
              color: '666666',
            ),
          );
          final paragraph = Paragraph(runs: [labelRun, valueRun]);
          doc.document.body.addParagraph(paragraph);
        }
      }

      // Add separator
      doc.addParagraph('');
      doc.addParagraph('');

      // Add body text
      doc.addHeading('Transcription', level: 2);
      doc.addParagraph('');
      _addTextWithParagraphs(doc, bodyText, isRtl);

      // Add refined text section if available
      if (refinedText != null && refinedText.isNotEmpty) {
        doc.addPageBreak();
        doc.addHeading('Refined Version', level: 2);
        doc.addParagraph('');
        _addTextWithParagraphs(doc, refinedText, isRtl);
      }

      doc.saveAs(outputPath);
      _logger.i('DOCX with metadata generated: $outputPath');
    } catch (e) {
      _logger.e('DOCX with metadata generation failed: $e');
      throw Exception('Failed to generate DOCX with metadata: $e');
    }
  }
}
