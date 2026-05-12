import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';

/// Abstract repository interface for clipboard operations.
///
/// Provides cross-platform clipboard access for copying text
/// and optionally reading clipboard content.
abstract class IClipboardRepository {
  /// Copy text to the system clipboard.
  ///
  /// The text becomes available for pasting in other applications.
  ///
  /// [text] - The text string to copy.
  ///
  /// Returns [Unit] on success.
  Future<Either<Failure, Unit>> copyText(String text);

  /// Read text from the system clipboard.
  ///
  /// Returns the current clipboard text content, or `null` if
  /// the clipboard is empty or contains non-text data.
  ///
  /// Note: On some platforms (especially mobile), reading the clipboard
  /// may require special permissions or may not be supported.
  Future<Either<Failure, String?>> getClipboardText();
}
