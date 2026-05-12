import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A row of quick action buttons that appear when transcription text is available.
///
/// Provides: Copy to clipboard, Export, and optional Refine (if LLM configured).
class QuickActionsBar extends StatelessWidget {
  /// Current transcription text.
  final String text;

  /// Refined text (if available).
  final String? refinedText;

  /// Called when the copy button is pressed.
  final VoidCallback onCopy;

  /// Called when the export button is pressed.
  final VoidCallback onExport;

  /// Called when the refine button is pressed. Null if LLM is not configured.
  final VoidCallback? onRefine;

  const QuickActionsBar({
    super.key,
    required this.text,
    this.refinedText,
    required this.onCopy,
    required this.onExport,
    this.onRefine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy button
          _ActionButton(
            icon: Icons.copy_outlined,
            tooltip: 'Copy to clipboard',
            onPressed: text.isNotEmpty ? onCopy : null,
          ),
          // Export button
          _ActionButton(
            icon: Icons.download_outlined,
            tooltip: 'Export text',
            onPressed: text.isNotEmpty ? onExport : null,
          ),
          // Refine button (only shown when LLM is configured)
          if (onRefine != null)
            _ActionButton(
              icon: Icons.auto_fix_high_outlined,
              tooltip: 'Refine with AI',
              onPressed: text.isNotEmpty ? onRefine : null,
            ),
        ],
      ),
    );
  }
}

/// Individual action button with tooltip and hover effect.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isEnabled
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurfaceVariant.withAlpha(77),
            ),
          ),
        ),
      ),
    );
  }
}

/// Utility extension for copying text to clipboard with feedback.
class ClipboardHelper {
  ClipboardHelper._();

  /// Copy text to clipboard and show a snackbar feedback.
  static Future<void> copyWithFeedback(
    BuildContext context,
    String text, {
    String message = 'Copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
