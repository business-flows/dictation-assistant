import 'package:flutter/material.dart';

/// Bottom action buttons for the refinement preview.
///
/// Provides three actions:
/// - **Cancel**: Dismisses the refinement preview (text button)
/// - **Discard**: Rejects the refined text (red outlined button)
/// - **Accept**: Accepts and saves the refined text (green filled button)
///
/// Usage:
/// ```dart
/// AcceptDiscardButtons(
///   onAccept: () => saveRefinedText(),
///   onDiscard: () => discardRefinedText(),
///   onCancel: () => Navigator.pop(context),
///   isLoading: false,
/// )
/// ```
class AcceptDiscardButtons extends StatelessWidget {
  /// Called when the user accepts the refined text.
  final VoidCallback? onAccept;

  /// Called when the user discards the refined text.
  final VoidCallback? onDiscard;

  /// Called when the user cancels/dismisses the preview.
  final VoidCallback? onCancel;

  /// Whether an action is currently in progress (disables buttons).
  final bool isLoading;

  /// Creates [AcceptDiscardButtons].
  const AcceptDiscardButtons({
    super.key,
    this.onAccept,
    this.onDiscard,
    this.onCancel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            // Cancel button (text style)
            TextButton(
              onPressed: isLoading ? null : onCancel,
              child: const Text('Cancel'),
            ),

            // Discard button (red outline)
            OutlinedButton(
              onPressed: isLoading ? null : onDiscard,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: isLoading
                      ? theme.colorScheme.error.withOpacity(0.3)
                      : theme.colorScheme.error,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: 6),
                  Text('Discard'),
                ],
              ),
            ),

            // Accept button (green filled)
            FilledButton(
              onPressed: isLoading ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 18),
                        SizedBox(width: 6),
                        Text('Accept'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal divider with action buttons for refinement controls.
///
/// Includes an additional "Regenerate" button for requesting a new
/// refinement attempt.
class RefinementActionBar extends StatelessWidget {
  /// Called when the user accepts the refined text.
  final VoidCallback? onAccept;

  /// Called when the user discards the refined text.
  final VoidCallback? onDiscard;

  /// Called when the user cancels/dismisses the preview.
  final VoidCallback? onCancel;

  /// Called when the user requests a regeneration.
  final VoidCallback? onRegenerate;

  /// Whether an action is currently in progress.
  final bool isLoading;

  /// Whether the regenerate button should be shown.
  final bool showRegenerate;

  /// Creates [RefinementActionBar].
  const RefinementActionBar({
    super.key,
    this.onAccept,
    this.onDiscard,
    this.onCancel,
    this.onRegenerate,
    this.isLoading = false,
    this.showRegenerate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cancel button
            TextButton(
              onPressed: isLoading ? null : onCancel,
              child: const Text('Cancel'),
            ),

            const Spacer(),

            // Regenerate button (optional)
            if (showRegenerate) ...[
              OutlinedButton.icon(
                onPressed: isLoading ? null : onRegenerate,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerate'),
              ),
              const SizedBox(width: 12),
            ],

            // Discard button
            OutlinedButton.icon(
              onPressed: isLoading ? null : onDiscard,
              icon: Icon(Icons.delete_outline,
                  size: 18, color: theme.colorScheme.error),
              label: Text(
                'Discard',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
              ),
            ),

            const SizedBox(width: 12),

            // Accept button
            FilledButton.icon(
              onPressed: isLoading ? null : onAccept,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Accept'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
