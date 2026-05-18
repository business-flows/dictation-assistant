import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/session_summary_entity.dart';

/// Card widget displaying a session summary in the history list.
///
/// Shows language flag, date, duration, preview text, and action buttons
/// for play, copy, export, and delete.
class SessionListItem extends StatelessWidget {
  /// The session to display.
  final SessionSummaryEntity session;

  /// Called when the play audio button is tapped.
  final VoidCallback? onPlayAudio;

  /// Called when the copy text button is tapped.
  final VoidCallback? onCopyText;

  /// Called when the export button is tapped.
  final VoidCallback? onExport;

  /// Called when the delete button is tapped.
  final VoidCallback? onDelete;

  /// Called when the card is tapped for detail view.
  final VoidCallback? onTap;

  /// Creates a [SessionListItem].
  const SessionListItem({
    super.key,
    required this.session,
    this.onPlayAudio,
    this.onCopyText,
    this.onExport,
    this.onDelete,
    this.onTap,
  });

  /// Language flag emoji mapping.
  static const Map<String, String> _languageFlags = {
    'en': '\u{1F1EC}\u{1F1E7}', // GB flag
    'fr': '\u{1F1EB}\u{1F1F7}', // FR flag
    'ar': '\u{1F1E6}\u{1F1EA}', // AE flag
  };

  String get _languageFlag =>
      _languageFlags[session.languageCode] ?? '\u{1F310}'; // Globe fallback

  String get _languageName =>
      AppConstants.supportedLanguages[session.languageCode] ??
      session.languageCode.toUpperCase();

  String get _formattedDate {
    final localDate = session.createdAt.toLocal();
    return DateFormat(AppConstants.exportDateFormat).format(localDate);
  }

  String get _formattedDuration {
    final duration = Duration(milliseconds: session.durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Flag, date, duration, refined badge
              Row(
                children: [
                  Text(
                    _languageFlag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formattedDate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '$_languageName · $_formattedDuration',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (session.hasRefinedText)
                    Tooltip(
                      message: 'Refined text available',
                      child: Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Preview text
              Text(
                session.previewText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionButton(
                    icon: Icons.play_arrow,
                    tooltip: 'Play audio',
                    onPressed: onPlayAudio,
                  ),
                  _ActionButton(
                    icon: Icons.copy,
                    tooltip: 'Copy text',
                    onPressed: onCopyText,
                  ),
                  _ActionButton(
                    icon: Icons.file_download,
                    tooltip: 'Export',
                    onPressed: onExport,
                  ),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: colorScheme.error,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small icon button for session list item actions.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: color,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: const EdgeInsets.all(8),
    );
  }
}
