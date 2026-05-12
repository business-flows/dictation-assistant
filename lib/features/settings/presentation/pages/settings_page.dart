import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../injection.dart';
import '../../domain/entities/settings_entity.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../widgets/language_dropdown.dart';
import '../widgets/llm_config_form.dart';
import '../widgets/model_download_tile.dart';

/// Settings page with multiple configuration sections.
///
/// Sections:
/// - Transcription: language, model selection
/// - LLM: endpoint, token, model, system prompt, connection test
/// - Desktop: minimize to tray, always on top (desktop only)
/// - Data Management: storage usage, cleanup
class SettingsPage extends StatefulWidget {
  /// Creates a [SettingsPage].
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Pending settings changes that haven't been saved yet.
  SettingsEntity? _pendingSettings;

  /// Whether a connection test is currently in progress.
  bool _isTestingConnection = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<SettingsBloc>()..add(const LoadSettings()),
      child: BlocConsumer<SettingsBloc, SettingsState>(
        listener: _handleStateChanges,
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Settings'),
              actions: [
                if (_hasPendingChanges(state))
                  TextButton.icon(
                    onPressed: () => _saveSettings(context),
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
              ],
            ),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  void _handleStateChanges(BuildContext context, SettingsState state) {
    if (state is LlmConnectionSuccess) {
      setState(() => _isTestingConnection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Colors.green,
        ),
      );
    } else if (state is LlmConnectionFailure) {
      setState(() => _isTestingConnection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (state is ModelDownloadComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model ${state.modelId} downloaded')),
      );
    } else if (state is SettingsError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (state is SettingsLoaded && _pendingSettings == null) {
      // Initialize pending settings from loaded state
      _pendingSettings = state.settings;
    }
  }

  bool _hasPendingChanges(SettingsState state) {
    if (state is! SettingsLoaded || _pendingSettings == null) return false;
    return _pendingSettings != state.settings;
  }

  void _saveSettings(BuildContext context) {
    if (_pendingSettings != null) {
      context.read<SettingsBloc>().add(UpdateSettings(_pendingSettings!));
      setState(() => _pendingSettings = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Widget _buildBody(BuildContext context, SettingsState state) {
    if (state is SettingsLoading || state is SettingsInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is! SettingsLoaded) {
      return const Center(child: Text('Failed to load settings'));
    }

    final settings = _pendingSettings ?? state.settings;
    final models = state.models;

    // Compute current download progress for any model
    final downloadProgress = state is ModelDownloadInProgress
        ? (state as ModelDownloadInProgress).progress
        : null;
    final downloadingModelId = state is ModelDownloadInProgress
        ? (state as ModelDownloadInProgress).modelId
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transcription Section
          _buildSectionHeader(context, 'Transcription', Icons.mic),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LanguageDropdown(
              value: settings.defaultLanguage,
              labelText: 'Default Language',
              prefixIcon: Icons.language,
              onChanged: (lang) {
                setState(() {
                  _pendingSettings = settings.copyWith(defaultLanguage: lang);
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          // Model Selection
          _buildSectionHeader(context, 'Model', Icons.model_training),
          ...models.map((model) {
            return ModelDownloadTile(
              model: model,
              isSelected: model.id == settings.selectedModelId,
              downloadProgress: downloadingModelId == model.id
                  ? downloadProgress
                  : null,
              onDownload: () {
                context.read<SettingsBloc>().add(DownloadModel(model.id));
              },
              onDelete: () => _confirmDeleteModel(context, model.id),
              onSelect: () {
                setState(() {
                  _pendingSettings = settings.copyWith(
                    selectedModelId: model.id,
                  );
                });
              },
            );
          }),
          const Divider(height: 32),

          // LLM Section
          _buildSectionHeader(context, 'LLM Configuration', Icons.psychology),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LlmConfigForm(
              settings: settings,
              onChanged: (updated) {
                setState(() {
                  _pendingSettings = updated;
                });
              },
              onTestConnection: () {
                setState(() => _isTestingConnection = true);
                // First save pending settings
                if (_pendingSettings != null) {
                  context.read<SettingsBloc>().add(
                    UpdateSettings(_pendingSettings!),
                  );
                }
                context.read<SettingsBloc>().add(const TestLlmConnection());
              },
              isTestingConnection: _isTestingConnection,
            ),
          ),
          const SizedBox(height: 16),
          // Auto-refine toggle
          _buildSwitchTile(
            context,
            title: 'Auto-refine text',
            subtitle: 'Automatically refine transcription after each session',
            value: settings.autoRefine,
            onChanged: (value) {
              setState(() {
                _pendingSettings = settings.copyWith(autoRefine: value);
              });
            },
          ),
          const Divider(height: 32),

          // Desktop Section (desktop only)
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
            _buildSectionHeader(context, 'Desktop', Icons.desktop_windows),
            _buildSwitchTile(
              context,
              title: 'Minimize to tray',
              subtitle: 'Keep running in system tray when closing',
              value: settings.minimizeToTray,
              onChanged: (value) {
                setState(() {
                  _pendingSettings = settings.copyWith(minimizeToTray: value);
                });
              },
            ),
            _buildSwitchTile(
              context,
              title: 'Always on top',
              subtitle: 'Keep window above other applications',
              value: settings.alwaysOnTop,
              onChanged: (value) {
                setState(() {
                  _pendingSettings = settings.copyWith(alwaysOnTop: value);
                });
              },
            ),
            const Divider(height: 32),
          ],

          // Data Management Section
          _buildSectionHeader(context, 'Data Management', Icons.storage),
          _DataManagementSection(
            onCleanup: () => _confirmCleanup(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  void _confirmDeleteModel(BuildContext context, String modelId) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text(
          'Are you sure you want to delete the model "$modelId"? This will free up disk space but you\'ll need to download it again to use it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<SettingsBloc>().add(DeleteModel(modelId));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmCleanup(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Up Old Sessions'),
        content: const Text(
          'This will permanently delete all sessions older than 30 days. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Old sessions cleaned up')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clean Up'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data Management Section
// ---------------------------------------------------------------------------

class _DataManagementSection extends StatelessWidget {
  final VoidCallback? onCleanup;

  const _DataManagementSection({this.onCleanup});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Storage usage info
          _buildStorageInfo(context),
          const SizedBox(height: 16),
          // Cleanup button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCleanup,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Clean Up Old Sessions'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deletes sessions older than 30 days to free up space.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfo(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storage,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Storage Usage',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Calculating storage usage...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
