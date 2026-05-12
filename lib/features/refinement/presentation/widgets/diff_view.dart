import 'package:flutter/material.dart';

/// Shows a visual diff between the original and refined text.
///
/// Highlights:
/// - Removed text: red with strikethrough
/// - Added text: green
/// - Unchanged text: normal style
///
/// Uses a simple word-level diff algorithm that works without
/// external dependencies.
///
/// Usage:
/// ```dart
/// DiffView(
///   originalText: originalText,
///   refinedText: refinedText,
/// )
/// ```
class DiffView extends StatelessWidget {
  /// The original unrefined text.
  final String originalText;

  /// The LLM-refined text.
  final String refinedText;

  /// Optional text style applied to all diff segments.
  final TextStyle? baseStyle;

  /// Creates a [DiffView].
  const DiffView({
    super.key,
    required this.originalText,
    required this.refinedText,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final segments = _computeWordDiff(originalText, refinedText);
    final theme = Theme.of(context);
    final effectiveBaseStyle = baseStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          height: 1.6,
          fontSize: 14,
        );

    if (originalText == refinedText) {
      return _buildNoChanges(context);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(
        TextSpan(
          children: segments
              .map((s) => _buildDiffSpan(s, effectiveBaseStyle, theme))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildNoChanges(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'No changes were made by the LLM.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Computes a word-level diff between original and refined text.
  ///
  /// Uses the LCS (Longest Common Subsequence) algorithm to find
  /// the minimal set of insertions and deletions.
  List<_DiffSegment> _computeWordDiff(String original, String refined) {
    final oldWords = original.split(RegExp(r'(\s+)'));
    final newWords = refined.split(RegExp(r'(\s+)'));

    // Handle empty strings
    if (oldWords.isEmpty && newWords.isEmpty) return [];
    if (oldWords.isEmpty) {
      return [_DiffSegment.insert(refined)];
    }
    if (newWords.isEmpty) {
      return [_DiffSegment.delete(original)];
    }

    // Compute LCS
    final lcs = _computeLCS(oldWords, newWords);

    // Backtrack to build diff
    final segments = <_DiffSegment>[];
    int i = oldWords.length;
    int j = newWords.length;

    while (i > 0 || j > 0) {
      if (i > 0 &&
          j > 0 &&
          lcs[i][j] == lcs[i - 1][j - 1] + 1 &&
          oldWords[i - 1] == newWords[j - 1]) {
        // Match - prepend to keep order
        segments.insert(0, _DiffSegment.equal(oldWords[i - 1]));
        i--;
        j--;
      } else if (j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j])) {
        // Insertion in refined
        segments.insert(0, _DiffSegment.insert(newWords[j - 1]));
        j--;
      } else if (i > 0 && (j == 0 || lcs[i][j - 1] < lcs[i - 1][j])) {
        // Deletion from original
        segments.insert(0, _DiffSegment.delete(oldWords[i - 1]));
        i--;
      } else {
        break;
      }
    }

    // Merge consecutive segments of the same type
    return _mergeSegments(segments);
  }

  /// Computes the LCS DP table.
  List<List<int>> _computeLCS(List<String> a, List<String> b) {
    final dp = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    return dp;
  }

  /// Merges consecutive segments of the same type for cleaner output.
  List<_DiffSegment> _mergeSegments(List<_DiffSegment> segments) {
    if (segments.isEmpty) return segments;

    final merged = <_DiffSegment>[segments[0]];
    for (int i = 1; i < segments.length; i++) {
      final last = merged.last;
      final current = segments[i];
      if (last.type == current.type) {
        merged[merged.length - 1] = _DiffSegment(
          last.type,
          last.text + current.text,
        );
      } else {
        merged.add(current);
      }
    }

    return merged;
  }

  /// Builds a styled [TextSpan] for a single diff segment.
  InlineSpan _buildDiffSpan(
    _DiffSegment segment,
    TextStyle? baseStyle,
    ThemeData theme,
  ) {
    switch (segment.type) {
      case _DiffType.equal:
        return TextSpan(
          text: segment.text,
          style: baseStyle?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        );

      case _DiffType.delete:
        return TextSpan(
          text: segment.text,
          style: baseStyle?.copyWith(
            color: Colors.red.shade700,
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.red.shade700,
            decorationThickness: 2,
            backgroundColor: Colors.red.shade50,
          ),
        );

      case _DiffType.insert:
        return TextSpan(
          text: segment.text,
          style: baseStyle?.copyWith(
            color: Colors.green.shade700,
            fontWeight: FontWeight.w600,
            backgroundColor: Colors.green.shade50,
          ),
        );
    }
  }
}

/// Types of diff operations.
enum _DiffType { equal, delete, insert }

/// A single segment in the diff output.
class _DiffSegment {
  final _DiffType type;
  final String text;

  const _DiffSegment(this.type, this.text);

  const _DiffSegment.equal(String text) : this(_DiffType.equal, text);
  const _DiffSegment.delete(String text) : this(_DiffType.delete, text);
  const _DiffSegment.insert(String text) : this(_DiffType.insert, text);
}

/// A simplified diff view that shows changes as two sections.
///
/// Used as a fallback or alternative display style.
class SimpleDiffView extends StatelessWidget {
  /// The original unrefined text.
  final String originalText;

  /// The LLM-refined text.
  final String refinedText;

  const SimpleDiffView({
    super.key,
    required this.originalText,
    required this.refinedText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (originalText == refinedText) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No changes were made by the LLM.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          context,
          title: 'Removed',
          icon: Icons.remove_circle_outline,
          iconColor: Colors.red,
          child: _buildOriginalOnlyText(context),
        ),
        const SizedBox(height: 12),
        _buildSection(
          context,
          title: 'Added',
          icon: Icons.add_circle_outline,
          iconColor: Colors.green,
          child: _buildRefinedOnlyText(context),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalOnlyText(BuildContext context) {
    final theme = Theme.of(context);
    final originalWords = originalText.split(RegExp(r'\s+'));
    final refinedWords = refinedText.split(RegExp(r'\s+'));
    final removedWords = originalWords.where(
      (w) => !refinedWords.contains(w),
    ).toList();

    if (removedWords.isEmpty) {
      return Text(
        'No text was removed.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Text(
      removedWords.join(' '),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.red.shade700,
        decoration: TextDecoration.lineThrough,
      ),
    );
  }

  Widget _buildRefinedOnlyText(BuildContext context) {
    final theme = Theme.of(context);
    final originalWords = originalText.split(RegExp(r'\s+'));
    final refinedWords = refinedText.split(RegExp(r'\s+'));
    final addedWords = refinedWords.where(
      (w) => !originalWords.contains(w),
    ).toList();

    if (addedWords.isEmpty) {
      return Text(
        'No new text was added.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Text(
      addedWords.join(' '),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.green.shade700,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
