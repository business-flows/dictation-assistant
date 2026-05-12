import 'package:flutter/material.dart';

import '../../domain/entities/model_info_entity.dart';

/// List tile showing model name, size, download status, and action buttons.
///
/// Displays a progress bar when a download is in progress for this model.
class ModelDownloadTile extends StatelessWidget {
  /// The model to display.
  final ModelInfoEntity model;

  /// Whether this model is currently selected as the active model.
  final bool isSelected;

  /// Current download progress (0.0 to 1.0), null if not downloading.
  final double? downloadProgress;

  /// Called when the download button is tapped.
  final VoidCallback? onDownload;

  /// Called when the delete button is tapped.
  final VoidCallback? onDelete;

  /// Called when the select button is tapped.
  final VoidCallback? onSelect;

  /// Creates a [ModelDownloadTile].
  const ModelDownloadTile({
    super.key,
    required this.model,
    this.isSelected = false,
    this.downloadProgress,
    this.onDownload,
    this.onDelete,
    this.onSelect,
  });

  bool get _isDownloading =>
      downloadProgress != null && downloadProgress! > 0 && downloadProgress! < 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              model.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Selected',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${model.sizeDisplay} · ${model.backendType.displayName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                if (_isDownloading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (model.isDownloaded) ...[
                  if (!isSelected)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: 'Select this model',
                      onPressed: onSelect,
                    ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    tooltip: 'Delete model',
                    onPressed: onDelete,
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Download model',
                    onPressed: onDownload,
                  ),
              ],
            ),
            // Download progress bar
            if (_isDownloading && downloadProgress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: downloadProgress,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 4),
              Text(
                'Downloading... ${(downloadProgress! * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
            // Downloaded badge
            if (model.isDownloaded && !_isDownloading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: colorScheme.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Downloaded',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
