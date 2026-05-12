import 'package:equatable/equatable.dart';

/// Base class for all export states.
abstract class ExportState extends Equatable {
  const ExportState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no export operation is active.
class ExportInitial extends ExportState {
  const ExportInitial();
}

/// Export is in progress.
///
/// UI should show a loading indicator.
class ExportInProgress extends ExportState {
  const ExportInProgress();
}

/// Export completed successfully.
///
/// [filePath] - The absolute path of the exported file.
class ExportCompleted extends ExportState {
  /// Path to the exported file.
  final String filePath;

  const ExportCompleted({required this.filePath});

  @override
  List<Object?> get props => [filePath];

  @override
  String toString() => 'ExportCompleted(filePath: $filePath)';
}

/// Export was cancelled by the user.
///
/// The user dismissed the file picker without selecting a location.
class ExportCancelled extends ExportState {
  const ExportCancelled();
}

/// Export failed with an error.
///
/// [message] - Human-readable error message.
class ExportError extends ExportState {
  /// Error message describing what went wrong.
  final String message;

  const ExportError({required this.message});

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'ExportError(message: $message)';
}

/// Text has been successfully copied to the clipboard.
class ClipboardCopied extends ExportState {
  const ClipboardCopied();
}

/// Text has been shared via the platform share sheet.
class TextShared extends ExportState {
  const TextShared();
}
