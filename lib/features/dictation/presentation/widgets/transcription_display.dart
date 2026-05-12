import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A scrollable transcription text display widget.
///
/// Supports RTL for Arabic text, refined text toggling, and text selection.
/// Uses [SelectionArea] on desktop for native text selection.
class TranscriptionDisplay extends StatelessWidget {
  /// Current transcription text to display.
  final String text;

  /// Whether the text should be displayed right-to-left (for Arabic).
  final bool isRtl;

  /// Whether refined text is available to toggle.
  final bool isRefinedAvailable;

  /// The refined/structured text (if available).
  final String? refinedText;

  /// Called when the user toggles between raw and refined text.
  final ValueChanged<bool> onShowRefinedChanged;

  /// Whether refined text is currently being shown.
  final bool showRefined;

  /// Placeholder hint text shown when the text area is empty.
  final String? hintText;

  const TranscriptionDisplay({
    super.key,
    required this.text,
    this.isRtl = false,
    this.isRefinedAvailable = false,
    this.refinedText,
    required this.onShowRefinedChanged,
    this.showRefined = false,
    this.hintText,
  });

  /// Determine if the given text is likely Arabic/RTL.
  static bool detectRtl(String text) {
    if (text.isEmpty) return false;
    // Check for Arabic script characters (U+0600 to U+06FF)
    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegex.hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final displayText = (showRefined && refinedText != null) ? refinedText! : text;
    final effectiveHint = hintText ?? 'Your transcription will appear here...';
    final textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;
    final textAlign = isRtl ? TextAlign.right : TextAlign.left;

    Widget content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(76),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Raw / Refined toggle tabs (if refined is available)
          if (isRefinedAvailable) ...[
            _buildToggleTabs(theme),
            const SizedBox(height: 12),
          ],
          // Text content
          Expanded(
            child: displayText.isEmpty
                ? Center(
                    child: Text(
                      effectiveHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : _buildTextContent(
                    displayText,
                    textDirection,
                    textAlign,
                    theme,
                    isDesktop,
                  ),
          ),
          // Character count
          if (displayText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: isRtl ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
              child: Text(
                '${displayText.length} characters',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // Wrap in SelectionArea on desktop for native text selection
    if (isDesktop) {
      content = SelectionArea(child: content);
    }

    return content;
  }

  /// Build raw/refined toggle tabs.
  Widget _buildToggleTabs(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleTab(
            label: 'Raw',
            isSelected: !showRefined,
            onTap: () => onShowRefinedChanged(false),
          ),
          _ToggleTab(
            label: 'Refined',
            isSelected: showRefined,
            onTap: () => onShowRefinedChanged(true),
          ),
        ],
      ),
    );
  }

  /// Build the scrollable text content.
  Widget _buildTextContent(
    String displayText,
    TextDirection textDirection,
    TextAlign textAlign,
    ThemeData theme,
    bool isDesktop,
  ) {
    final textWidget = Text(
      displayText,
      textDirection: textDirection,
      textAlign: textAlign,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontSize: 18,
        height: 1.6,
        color: theme.colorScheme.onSurface,
      ),
    );

    if (isDesktop) {
      // SelectionArea is already wrapping the entire widget on desktop
      return SingleChildScrollView(
        child: textWidget,
      );
    }

    // On mobile, use SelectableText for text selection
    return SingleChildScrollView(
      child: SelectableText(
        displayText,
        textDirection: textDirection,
        textAlign: textAlign,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 18,
          height: 1.6,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Individual toggle tab for raw/refined switching.
class _ToggleTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withAlpha(26),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
