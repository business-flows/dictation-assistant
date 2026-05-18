import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../injection.dart';
import '../../domain/entities/session_summary_entity.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';
import '../bloc/history_state.dart';
import '../widgets/session_list_item.dart';
import '../widgets/session_search_bar.dart';
import 'session_detail_page.dart';

/// History list page displaying all recorded sessions.
///
/// Features:
/// - AppBar with search field (debounced 300ms)
/// - List of session cards with metadata and action buttons
/// - Pull-to-refresh support
/// - Empty state illustration
/// - Responsive master-detail layout on desktop (>900px)
class HistoryListPage extends StatefulWidget {
  /// Creates a [HistoryListPage].
  const HistoryListPage({super.key});

  @override
  State<HistoryListPage> createState() => _HistoryListPageState();
}

class _HistoryListPageState extends State<HistoryListPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  String? _selectedSessionId;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String audioPath) async {
    try {
      await _audioPlayer.play(DeviceFileSource(audioPath));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: $e')),
        );
      }
    }
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth > AppConstants.desktopBreakpoint;

    return BlocProvider(
      create: (context) => getIt<HistoryBloc>()..add(const LoadHistory()),
      child: Builder(
        builder: (context) {
          if (isDesktop) {
            return _DesktopLayout(
              audioPlayer: _audioPlayer,
              currentlyPlayingId: _currentlyPlayingId,
              selectedSessionId: _selectedSessionId,
              onPlayAudio: _playAudio,
              onCopyText: _copyText,
              onSessionSelected: (id) => setState(() => _selectedSessionId = id),
            );
          }
          return _MobileLayout(
            audioPlayer: _audioPlayer,
            currentlyPlayingId: _currentlyPlayingId,
            onPlayAudio: _playAudio,
            onCopyText: _copyText,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile Layout
// ---------------------------------------------------------------------------

class _MobileLayout extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final String? currentlyPlayingId;
  final Future<void> Function(String) onPlayAudio;
  final void Function(String) onCopyText;

  const _MobileLayout({
    required this.audioPlayer,
    required this.currentlyPlayingId,
    required this.onPlayAudio,
    required this.onCopyText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SessionSearchBar(
              onChanged: (query) {
                context.read<HistoryBloc>().add(SearchSessions(query));
              },
            ),
          ),
        ),
      ),
      body: BlocConsumer<HistoryBloc, HistoryState>(
        listener: _handleStateChanges,
        builder: (context, state) {
          if (state is HistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HistoryEmpty) {
            return _EmptyState(searchQuery: state.searchQuery);
          }
          if (state is HistoryLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<HistoryBloc>().add(const RefreshHistory());
              },
              child: ListView.builder(
                itemCount: state.sessions.length,
                itemBuilder: (context, index) {
                  final session = state.sessions[index];
                  return SessionListItem(
                    session: session,
                    onTap: () => _navigateToDetail(context, session),
                    onPlayAudio: () => onPlayAudio(session.audioFilePath),
                    onCopyText: () => onCopyText(session.previewText),
                    onExport: () => _exportSession(context, session),
                    onDelete: () => _confirmDelete(context, session),
                  );
                },
              ),
            );
          }
          if (state is HistoryError) {
            return _ErrorState(
              message: state.message,
              onRetry: () {
                context.read<HistoryBloc>().add(const LoadHistory());
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _handleStateChanges(BuildContext context, HistoryState state) {
    if (state is SessionDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session deleted')),
      );
    }
    if (state is HistoryError && state is! HistoryLoading) {
      // Only show snackbar for errors that aren't already showing as state
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _navigateToDetail(BuildContext context, SessionSummaryEntity session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionDetailPage(sessionId: session.id),
      ),
    );
  }

  void _exportSession(BuildContext context, SessionSummaryEntity session) {
    // TODO: Implement DOCX export via context.push
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export coming soon')),
    );
  }

  void _confirmDelete(BuildContext context, SessionSummaryEntity session) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
          'This will permanently delete the session and its audio recording.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<HistoryBloc>().add(DeleteSession(session.id));
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
}

// ---------------------------------------------------------------------------
// Desktop Layout (Master-Detail)
// ---------------------------------------------------------------------------

class _DesktopLayout extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final String? currentlyPlayingId;
  final String? selectedSessionId;
  final Future<void> Function(String) onPlayAudio;
  final void Function(String) onCopyText;
  final ValueChanged<String> onSessionSelected;

  const _DesktopLayout({
    required this.audioPlayer,
    required this.currentlyPlayingId,
    required this.selectedSessionId,
    required this.onPlayAudio,
    required this.onCopyText,
    required this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Master: session list
          SizedBox(
            width: 400,
            child: Column(
              children: [
                AppBar(
                  title: const Text('History'),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(56),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SessionSearchBar(
                        onChanged: (query) {
                          context.read<HistoryBloc>().add(SearchSessions(query));
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: BlocConsumer<HistoryBloc, HistoryState>(
                    listener: (context, state) {
                      if (state is SessionDeleted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Session deleted')),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is HistoryLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is HistoryEmpty) {
                        return _EmptyState(searchQuery: state.searchQuery);
                      }
                      if (state is HistoryLoaded) {
                        return RefreshIndicator(
                          onRefresh: () async {
                            context.read<HistoryBloc>().add(const RefreshHistory());
                          },
                          child: ListView.builder(
                            itemCount: state.sessions.length,
                            itemBuilder: (context, index) {
                              final session = state.sessions[index];
                              final isSelected = session.id == selectedSessionId;
                              return Container(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                                    : null,
                                child: SessionListItem(
                                  session: session,
                                  onTap: () => onSessionSelected(session.id),
                                  onPlayAudio: () => onPlayAudio(session.audioFilePath),
                                  onCopyText: () => onCopyText(session.previewText),
                                  onExport: () => _exportSession(context, session),
                                  onDelete: () => _confirmDelete(context, session),
                                ),
                              );
                            },
                          ),
                        );
                      }
                      if (state is HistoryError) {
                        return _ErrorState(
                          message: state.message,
                          onRetry: () {
                            context.read<HistoryBloc>().add(const LoadHistory());
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Divider
          const VerticalDivider(width: 1),
          // Detail: session detail
          Expanded(
            child: selectedSessionId != null
                ? SessionDetailPage(
                    sessionId: selectedSessionId!,
                    showAppBar: false,
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Select a session to view details',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _exportSession(BuildContext context, SessionSummaryEntity session) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export coming soon')),
    );
  }

  void _confirmDelete(BuildContext context, SessionSummaryEntity session) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
          'This will permanently delete the session and its audio recording.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<HistoryBloc>().add(DeleteSession(session.id));
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
}

// ---------------------------------------------------------------------------
// Shared UI Components
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final String? searchQuery;

  const _EmptyState({this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = searchQuery != null && searchQuery!.isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Icons.search_off : Icons.history,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery
                ? 'No sessions match "$searchQuery"'
                : 'No sessions yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasQuery
                ? 'Try a different search term'
                : 'Start recording to create your first session',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
