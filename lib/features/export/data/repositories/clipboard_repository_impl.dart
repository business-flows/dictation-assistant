import 'package:clipboard/clipboard.dart';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/repositories/i_clipboard_repository.dart';

/// Implementation of [IClipboardRepository] using super_clipboard
/// with a fallback to the clipboard package.
///
/// super_clipboard provides better cross-platform support including
/// desktop platforms, while the clipboard package serves as a
/// reliable fallback.
class ClipboardRepositoryImpl implements IClipboardRepository {
  final Logger _logger;

  ClipboardRepositoryImpl({Logger? logger}) : _logger = logger ?? Logger();

  @override
  Future<Either<Failure, Unit>> copyText(String text) async {
    try {
      // Try super_clipboard first (better desktop support)
      final clipboard = SystemClipboard?.instance;
      if (clipboard != null) {
        final item = DataWriterItem();
        item.add(Formats.plainText(text));
        await clipboard.write([item]);
        _logger.d('Copied text using super_clipboard (${text.length} chars)');
        return const Right(unit);
      }

      // Fallback to clipboard package
      await FlutterClipboard.copy(text);
      _logger.d('Copied text using clipboard package (${text.length} chars)');
      return const Right(unit);
    } catch (e) {
      _logger.e('Failed to copy text: $e');

      // Last resort fallback
      try {
        await FlutterClipboard.copy(text);
        return const Right(unit);
      } catch (e2) {
        return Left(UnexpectedFailure('Failed to copy to clipboard: $e2'));
      }
    }
  }

  @override
  Future<Either<Failure, String?>> getClipboardText() async {
    try {
      // Try super_clipboard first
      final clipboard = SystemClipboard?.instance;
      if (clipboard != null) {
        final reader = await clipboard.read();
        if (reader.canProvide(Formats.plainText)) {
          final text = await reader.readValue(Formats.plainText);
          return Right(text);
        }
        return const Right(null);
      }

      // Fallback to clipboard package
      final text = await FlutterClipboard.paste();
      return Right(text.isEmpty ? null : text);
    } catch (e) {
      _logger.e('Failed to read clipboard: $e');
      return Left(UnexpectedFailure('Failed to read clipboard: $e'));
    }
  }
}
