import 'package:flutter/material.dart';

/// Row of action buttons for the session detail page.
///
/// Provides Copy, Export, Refine, and Delete actions with
/// appropriate icons and labels.
class SessionDetailActions extends StatelessWidget {
  /// Called when the copy button is tapped.
  final VoidCallback? onCopy;

  /// Called when the export button is tapped.
  final VoidCallback? onExport;

  /// Called when the refine button is tapped.
  final VoidCallback? onRefine;

  /// Called when the delete button is tapped.
  final VoidCallback? onDelete;

  /// Whether the refine button should be shown.
  final bool showRefine;

  /// Whether a refine operation is in progress.
  final bool isRefining;

  /// Creates a [SessionDetailActions].
  const SessionDetailActions({
    super.key,
    this.onCopy,
    this.onExport,
    this.onRefine,
    this.onDelete,
    this.showRefine = false,
    this.isRefining = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _ActionChipButton(
          icon: Icons.copy,
          label: 'Copy',
          onPressed: onCopy,
        ),
        _ActionChipButton(
          icon: Icons.file_download,
          label: 'Export',
          onPressed: onExport,
        ),
        if (showRefine)
          _ActionChipButton(
            icon: isRefining ? Icons.hourglass_top : Icons.auto_awesome,
            label: isRefining ? 'Refining...' : 'Refine',
            onPressed: isRefining ? null : onRefine,
          ),
        _ActionChipButton(
          icon: Icons.delete_outline,
          label: 'Delete',
          color: colorScheme.error,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// Individual action button styled as a chip.
class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: color ?? colorScheme.primary,
      ),
      label: Text(label),
      onPressed: onPressed,
      side: BorderSide(
        color: color?.withOpacity(0.3) ?? colorScheme.outlineVariant,
      ),
    );
  }
}
