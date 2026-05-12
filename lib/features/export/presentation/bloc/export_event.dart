import 'package:equatable/equatable.dart';

import '../../domain/entities/export_options_entity.dart';

/// Base class for all export events.
abstract class ExportEvent extends Equatable {
  const ExportEvent();

  @override
  List<Object?> get props => [];
}

/// Export text to a DOCX file at a specific path.
///
/// Used when the save path is already known (e.g., from a file picker).
class ExportToDocx extends ExportEvent {
  /// The session ID being exported.
  final String sessionId;

  /// The text content to export.
  final String text;

  /// Export configuration options.
  final ExportOptionsEntity options;

  /// Absolute file path where the DOCX should be saved.
  final String savePath;

  const ExportToDocx({
    required this.sessionId,
    required this.text,
    required this.options,
    required this.savePath,
  });

  @override
  List<Object?> get props => [sessionId, text, options, savePath];
}

/// Pick a save location and then export.
///
/// Opens a native file picker for the user to choose where to save,
/// then proceeds with the export if a location was selected.
class PickExportLocation extends ExportEvent {
  /// The session ID being exported.
  final String sessionId;

  /// The text content to export.
  final String text;

  /// Export configuration options.
  final ExportOptionsEntity options;

  /// Default filename suggestion for the picker dialog.
  final String? suggestedName;

  const PickExportLocation({
    required this.sessionId,
    required this.text,
    required this.options,
    this.suggestedName,
  });

  @override
  List<Object?> get props => [sessionId, text, options, suggestedName];
}

/// Export a complete session entity to DOCX.
///
/// Includes all session data (original + refined text, metadata).
class ExportSession extends ExportEvent {
  /// The complete session to export.
  final SessionEntity session;

  /// Absolute file path where the DOCX should be saved.
  final String savePath;

  const ExportSession({
    required this.session,
    required this.savePath,
  });

  @override
  List<Object?> get props => [session, savePath];
}

/// Copy text to the system clipboard.
class CopyToClipboard extends ExportEvent {
  /// The text to copy.
  final String text;

  const CopyToClipboard({required this.text});

  @override
  List<Object?> get props => [text];
}

/// Share text via the platform share sheet.
class ShareText extends ExportEvent {
  /// The text to share.
  final String text;

  /// Optional subject line (for email sharing).
  final String? subject;

  const ShareText({
    required this.text,
    this.subject,
  });

  @override
  List<Object?> get props => [text, subject];
}

/// Reset the export state to initial.
class ResetExport extends ExportEvent {
  const ResetExport();
}
