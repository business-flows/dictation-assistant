import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';

/// Data source for opening native file pickers to select save locations.
///
/// Uses the file_picker package to show native save dialogs across
/// all supported platforms (desktop, mobile, web).
class FilePickerDataSource {
  final Logger _logger;

  FilePickerDataSource({Logger? logger}) : _logger = logger ?? Logger();

  /// Opens a native save-file dialog for the user to choose where
  /// to save an exported file.
  ///
  /// [suggestedName] - The default filename shown in the dialog.
  /// [allowedExtensions] - List of allowed file extensions (e.g., ['docx']).
  ///
  /// Returns the selected absolute file path, or `null` if the user
  /// cancelled the dialog.
  ///
  /// Example:
  /// ```dart
  /// final path = await filePicker.pickSaveLocation(
  ///   suggestedName: 'dictation_2024.docx',
  ///   allowedExtensions: ['docx'],
  /// );
  /// ```
  Future<String?> pickSaveLocation({
    required String suggestedName,
    required List<String> allowedExtensions,
  }) async {
    try {
      _logger.d(
        'Opening save dialog with suggested name: $suggestedName',
      );

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Dictation',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (result != null) {
        _logger.i('User selected save location: $result');
      } else {
        _logger.d('User cancelled save dialog');
      }

      return result;
    } catch (e) {
      _logger.e('File picker error: $e');
      return null;
    }
  }

  /// Opens a directory picker to select a folder for saving files.
  ///
  /// Returns the selected directory path, or `null` if cancelled.
  Future<String?> pickDirectory() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Folder',
      );

      if (result != null) {
        _logger.i('User selected directory: $result');
      }

      return result;
    } catch (e) {
      _logger.e('Directory picker error: $e');
      return null;
    }
  }
}
