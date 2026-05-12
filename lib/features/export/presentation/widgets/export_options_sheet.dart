import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/export_options_entity.dart';
import '../bloc/export_bloc.dart';
import '../bloc/export_event.dart';
import '../bloc/export_state.dart';

/// Bottom sheet that displays export options before initiating export.
///
/// Allows the user to configure:
/// - Whether to use refined text (if available)
/// - Whether to include metadata in the export
/// - Custom filename override
///
/// Shows a "Choose Location & Export" button that opens a file picker.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => ExportOptionsSheet(
///     sessionId: session.id,
///     text: session.transcribedText,
///     hasRefinedText: session.refinedText != null,
///   ),
/// );
/// ```
class ExportOptionsSheet extends StatefulWidget {
  /// The session ID being exported.
  final String sessionId;

  /// The text content to export.
  final String text;

  /// Whether refined text is available for this session.
  final bool hasRefinedText;

  /// The refined text (if available).
  final String? refinedText;

  /// ISO 639-1 language code.
  final String languageCode;

  /// Creates [ExportOptionsSheet].
  const ExportOptionsSheet({
    super.key,
    required this.sessionId,
    required this.text,
    this.hasRefinedText = false,
    this.refinedText,
    this.languageCode = 'en',
  });

  @override
  State<ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<ExportOptionsSheet> {
  late bool _useRefinedText;
  late bool _includeMetadata;
  final _filenameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _useRefinedText = widget.hasRefinedText;
    _includeMetadata = true;
    _filenameController.text = 'dictation_${_formatDate(DateTime.now())}';
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<ExportBloc, ExportState>(
      listener: (context, state) {
        if (state is ExportCompleted) {
          Navigator.pop(context);
          _showSuccessSnackbar(context, state.filePath);
        } else if (state is ExportError) {
          _showErrorSnackbar(context, state.message);
        } else if (state is ExportCancelled) {
          // Stay open - user cancelled the picker
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.file_download_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Export Options',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Options list
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 8),

                      // Use refined text toggle
                      if (widget.hasRefinedText)
                        _buildToggleTile(
                          title: 'Use Refined Text',
                          subtitle: 'Export the LLM-refined version instead of the original',
                          icon: Icons.auto_awesome,
                          value: _useRefinedText,
                          onChanged: (value) {
                            setState(() => _useRefinedText = value);
                          },
                        )
                      else
                        _buildInfoTile(
                          icon: Icons.info_outline,
                          message: 'No refined text available. Exporting original transcription.',
                        ),

                      const SizedBox(height: 8),

                      // Include metadata toggle
                      _buildToggleTile(
                        title: 'Include Metadata',
                        subtitle: 'Add session date, language, and duration to the document',
                        icon: Icons.info_outline,
                        value: _includeMetadata,
                        onChanged: (value) {
                          setState(() => _includeMetadata = value);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Custom filename
                      Text(
                        'Filename',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _filenameController,
                        decoration: InputDecoration(
                          hintText: 'Enter custom filename',
                          suffixText: AppConstants.docxExtension,
                          prefixIcon: const Icon(Icons.edit),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Preview
                      _buildPreviewSection(theme),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Action button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: BlocBuilder<ExportBloc, ExportState>(
                      builder: (context, state) {
                        final isLoading = state is ExportInProgress;

                        return FilledButton.icon(
                          onPressed: isLoading ? null : _onExport,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.folder_open),
                          label: Text(
                            isLoading ? 'Exporting...' : 'Choose Location & Export',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String message,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 22),
        title: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection(ThemeData theme) {
    final textToExport = _useRefinedText && widget.refinedText != null
        ? widget.refinedText!
        : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${textToExport.length} characters',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                textToExport.substring(
                  0,
                  textToExport.length > 150 ? 150 : textToExport.length,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (textToExport.length > 150)
                Text(
                  '...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _onExport() {
    final textToExport = _useRefinedText && widget.refinedText != null
        ? widget.refinedText!
        : widget.text;

    final filename = _filenameController.text.trim().isEmpty
        ? null
        : _filenameController.text.trim();

    final options = ExportOptionsEntity(
      useRefinedText: _useRefinedText,
      includeMetadata: _includeMetadata,
      customFilename: filename,
    );

    context.read<ExportBloc>().add(PickExportLocation(
          sessionId: widget.sessionId,
          text: textToExport,
          options: options,
          suggestedName: filename != null
              ? '$filename${AppConstants.docxExtension}'
              : null,
        ));
  }

  void _showSuccessSnackbar(BuildContext context, String filePath) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Exported to ${p.basename(filePath)}'),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.errorContainer,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.year}${_pad(d.month)}${_pad(d.day)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
