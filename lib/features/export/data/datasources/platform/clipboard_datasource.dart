import 'package:clipboard/clipboard.dart';
import 'package:logger/logger.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Low-level data source for system clipboard operations.
///
/// Provides basic clipboard read/write functionality using
/// super_clipboard with a fallback to the clipboard package.
class ClipboardDataSource {
  final Logger _logger;

  ClipboardDataSource({Logger? logger}) : _logger = logger ?? Logger();

  /// Copies text to the system clipboard.
  ///
  /// The text becomes available for pasting in other applications.
  /// Uses super_clipboard when available, falls back to the
  /// clipboard package on unsupported platforms.
  ///
  /// [text] - The text string to copy.
  Future<void> copyText(String text) async {
    try {
      // Try super_clipboard first
      final clipboard = SystemClipboard?.instance;
      if (clipboard != null) {
        final item = DataWriterItem();
        item.add(Formats.plainText(text));
        await clipboard.write([item]);
        _logger.d('Copied text via super_clipboard');
        return;
      }

      // Fallback to clipboard package
      await FlutterClipboard.copy(text);
      _logger.d('Copied text via clipboard package');
    } catch (e) {
      _logger.e('Failed to copy text: $e');

      // Last resort fallback
      await FlutterClipboard.copy(text);
    }
  }

  /// Reads text from the system clipboard.
  ///
  /// Returns the current clipboard text content, or `null` if
  /// the clipboard is empty or contains non-text data.
  ///
  /// Note: On some platforms, reading the clipboard may require
  /// special permissions.
  Future<String?> getText() async {
    try {
      // Try super_clipboard first
      final clipboard = SystemClipboard?.instance;
      if (clipboard != null) {
        final reader = await clipboard.read();
        if (reader.canProvide(Formats.plainText)) {
          final text = await reader.readValue(Formats.plainText);
          return text;
        }
        return null;
      }

      // Fallback to clipboard package
      final text = await FlutterClipboard.paste();
      return text.isEmpty ? null : text;
    } catch (e) {
      _logger.e('Failed to read clipboard: $e');
      return null;
    }
  }

  /// Clears the clipboard content.
  Future<void> clear() async {
    try {
      final clipboard = SystemClipboard?.instance;
      if (clipboard != null) {
        final item = DataWriterItem();
        item.add(Formats.plainText(''));
        await clipboard.write([item]);
        return;
      }
      await FlutterClipboard.copy('');
    } catch (e) {
      _logger.e('Failed to clear clipboard: $e');
    }
  }
}
