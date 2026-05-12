import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../injection.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/usecases/get_session_by_id.dart';
import '../../domain/usecases/copy_session_text.dart';
import '../widgets/session_detail_actions.dart';

/// Detail page for a single session.
///
/// Shows full transcribed text, refined text (if available), audio player
/// controls, metadata, and action buttons.
///
/// Can be used either as a full page (mobile) or embedded in a desktop
/// master-detail layout ([showAppBar] = false).
class SessionDetailPage extends StatefulWidget {
  /// The session ID to display.
  final String sessionId;

  /// Whether to show an AppBar (set to false for desktop embedded layout).
  final bool showAppBar;

  /// Creates a [SessionDetailPage].
  const SessionDetailPage({
    super.key,
    required this.sessionId,
    this.showAppBar = true,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final TabController _tabController;

  SessionEntity? _session;
  bool _isLoading = true;
  String? _error;

  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  bool _isPlaying = false;

  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadSession();
    _setupAudioListeners();
  }

  void _onTabChanged() {
    setState(() => _selectedTab = _tabController.index);
  }

  void _setupAudioListeners() {
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _audioPosition = position);
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _audioDuration = duration);
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _audioPosition = Duration.zero);
    });
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final getSession = getIt<GetSessionById>();
    final result = await getSession(GetSessionByIdParams(id: widget.sessionId));

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (session) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
        // Initialize audio
        _audioPlayer.setSource(DeviceFileSource(session.audioFilePath));

        // If no refined text, only show one tab
        if (session.refinedText == null || session.refinedText!.isEmpty) {
          _tabController.length = 1;
        }
      },
    );
  }

  Future<void> _togglePlayPause() async {
    if (_session == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_audioPosition >= _audioDuration && _audioDuration > Duration.zero) {
        await _audioPlayer.seek(Duration.zero);
      }
      await _audioPlayer.play(DeviceFileSource(_session!.audioFilePath));
    }
  }

  Future<void> _seekTo(double fraction) async {
    if (_audioDuration > Duration.zero) {
      final position = Duration(
        milliseconds: (_audioDuration.inMilliseconds * fraction).toInt(),
      );
      await _audioPlayer.seek(position);
    }
  }

  Future<void> _copyText() async {
    if (_session == null) return;
    final text = _selectedTab == 1 && _session!.refinedText != null
        ? _session!.refinedText!
        : _session!.transcribedText;

    final copyUseCase = getIt<CopySessionText>();
    final result = await copyUseCase(CopySessionTextParams(text: text));

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to copy: ${failure.message}')),
          );
        }
      },
      (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        }
      },
    );
  }

  void _exportDocx() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('DOCX export coming soon')),
    );
  }

  void _refineText() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text refinement coming soon')),
    );
  }

  Future<void> _deleteSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
          'This will permanently delete the session and its audio recording.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(); // Go back after deletion
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: widget.showAppBar ? AppBar(title: const Text('Session')) : null,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: widget.showAppBar ? AppBar(title: const Text('Session')) : null,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadSession,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final session = _session!;
    final hasRefinedText =
        session.refinedText != null && session.refinedText!.isNotEmpty;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Session Details'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy text',
                  onPressed: _copyText,
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _showOptionsMenu,
                ),
              ],
              bottom: hasRefinedText
                  ? TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Original'),
                        Tab(text: 'Refined'),
                      ],
                    )
                  : null,
            )
          : null,
      body: Column(
        children: [
          // Audio player section
          _AudioPlayerSection(
            position: _audioPosition,
            duration: _audioDuration,
            isPlaying: _isPlaying,
            onPlayPause: _togglePlayPause,
            onSeek: _seekTo,
          ),
          const Divider(),
          // Metadata section
          _MetadataSection(session: session),
          const Divider(),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SessionDetailActions(
              onCopy: _copyText,
              onExport: _exportDocx,
              onRefine: hasRefinedText ? null : _refineText,
              showRefine: !hasRefinedText,
              onDelete: _deleteSession,
            ),
          ),
          const Divider(),
          // Text content
          Expanded(
            child: hasRefinedText
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _TextContent(text: session.transcribedText),
                      _TextContent(text: session.refinedText!),
                    ],
                  )
                : _TextContent(text: session.transcribedText),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.pop(context);
                _copyText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Export as DOCX'),
              onTap: () {
                Navigator.pop(context);
                _exportDocx();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteSession();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audio Player Section
// ---------------------------------------------------------------------------

class _AudioPlayerSection extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;

  const _AudioPlayerSection({
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 36,
                onPressed: onPlayPause,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: onSeek,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(
                            _formatDuration(duration),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata Section
// ---------------------------------------------------------------------------

class _MetadataSection extends StatelessWidget {
  final SessionEntity session;

  const _MetadataSection({required this.session});

  static const Map<String, String> _languageFlags = {
    'en': '\u{1F1EC}\u{1F1E7}',
    'fr': '\u{1F1EB}\u{1F1F7}',
    'ar': '\u{1F1E6}\u{1F1EA}',
  };

  String get _languageFlag =>
      _languageFlags[session.languageCode] ?? '\u{1F310}';

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

  int get _wordCount {
    final text = session.refinedText ?? session.transcribedText;
    return text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _MetadataChip(
            icon: Icons.calendar_today,
            label: _formattedDate,
          ),
          _MetadataChip(
            icon: Icons.timer,
            label: _formattedDuration,
          ),
          _MetadataChip(
            icon: Icons.language,
            label: '${_languageFlag} ${AppConstants.supportedLanguages[session.languageCode] ?? session.languageCode}',
          ),
          _MetadataChip(
            icon: Icons.format_list_numbered,
            label: '$_wordCount words',
          ),
        ],
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Chip(
      avatar: Icon(icon, size: 16, color: colorScheme.primary),
      label: Text(label),
      backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ---------------------------------------------------------------------------
// Text Content
// ---------------------------------------------------------------------------

class _TextContent extends StatelessWidget {
  final String text;

  const _TextContent({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (text.isEmpty) {
      return Center(
        child: Text(
          'No transcription available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.6,
        ),
      ),
    );
  }
}
