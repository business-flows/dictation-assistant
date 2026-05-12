import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../bloc/refinement_bloc.dart';
import '../bloc/refinement_event.dart';
import '../bloc/refinement_state.dart';
import '../widgets/accept_discard_buttons.dart';
import '../widgets/diff_view.dart';
import '../widgets/refinement_preview.dart';

/// Full-screen refinement preview page.
///
/// Provides a side-by-side comparison of the original dictation text
/// and the LLM-refined version. Supports:
/// - Split view on desktop (original left, refined right)
/// - Tabbed view on mobile
/// - Real-time streaming with shimmer animation
/// - Accept/discard/regenerate actions
///
/// Navigation:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => RefinementPreviewPage(
///       sessionId: session.id,
///       originalText: session.transcribedText,
///       languageCode: session.languageCode,
///     ),
///   ),
/// );
/// ```
class RefinementPreviewPage extends StatelessWidget {
  /// The session ID being refined.
  final String sessionId;

  /// The original dictation text.
  final String originalText;

  /// ISO 639-1 language code.
  final String languageCode;

  /// Optional custom prompt override.
  final String? customPrompt;

  /// Creates a [RefinementPreviewPage].
  const RefinementPreviewPage({
    super.key,
    required this.sessionId,
    required this.originalText,
    required this.languageCode,
    this.customPrompt,
  });

  @override
  Widget build(BuildContext context) {
    // Start refinement when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RefinementBloc>().add(StartRefinement(
            sessionId: sessionId,
            text: originalText,
            languageCode: languageCode,
            customPrompt: customPrompt,
          ));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refinement Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<RefinementBloc, RefinementState>(
        listener: (context, state) {
          if (state is RefinementAccepted) {
            _showSnackBar(context, 'Refinement accepted', Icons.check_circle);
            Navigator.pop(context, true);
          } else if (state is RefinementDiscarded) {
            _showSnackBar(context, 'Refinement discarded', Icons.delete);
            Navigator.pop(context, false);
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // Main content area
              Expanded(
                child: _buildBody(context, state),
              ),

              // Bottom action bar (only show when not streaming)
              if (state is! RefinementIdle) ...[
                _buildActionBar(context, state),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, RefinementState state) {
    if (state is RefinementIdle) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state is RefinementError) {
      return _buildErrorState(context, state);
    }

    final String displayOriginal = _getOriginalText(state);
    final String displayRefined = _getRefinedText(state);
    final bool isStreaming = state is RefinementInProgress &&
        (state as RefinementInProgress).isStreaming;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > AppConstants.desktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopLayout(
            context,
            originalText: displayOriginal,
            refinedText: displayRefined,
            isStreaming: isStreaming,
          );
        }

        return _buildMobileLayout(
          context,
          originalText: displayOriginal,
          refinedText: displayRefined,
          isStreaming: isStreaming,
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context, {
    required String originalText,
    required String refinedText,
    required bool isStreaming,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original text panel
        Expanded(
          child: _buildPanel(
            context,
            title: 'Original',
            icon: Icons.text_snippet_outlined,
            child: _buildOriginalView(context, originalText),
          ),
        ),

        const VerticalDivider(width: 1),

        // Refined text panel
        Expanded(
          child: _buildPanel(
            context,
            title: isStreaming ? 'Refining...' : 'Refined',
            icon: isStreaming ? Icons.auto_awesome : Icons.check_circle_outline,
            isActive: isStreaming,
            child: StreamingShimmer(
              isActive: isStreaming,
              child: RefinementPreview(
                text: refinedText,
                isStreaming: isStreaming,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context, {
    required String originalText,
    required String refinedText,
    required bool isStreaming,
  }) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.text_snippet_outlined,
                    color: Theme.of(context).colorScheme.onSurface),
                text: 'Original',
              ),
              Tab(
                icon: Icon(
                  isStreaming ? Icons.auto_awesome : Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                text: isStreaming ? 'Refining...' : 'Refined',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Original tab
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildOriginalView(context, originalText),
                ),
                // Refined tab
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: StreamingShimmer(
                    isActive: isStreaming,
                    child: RefinementPreview(
                      text: refinedText,
                      isStreaming: isStreaming,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Divider(
          height: 1,
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),

        // Panel content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildOriginalView(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.6,
          fontSize: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, RefinementError state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Refinement Failed',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<RefinementBloc>().add(StartRefinement(
                      sessionId: sessionId,
                      text: originalText,
                      languageCode: languageCode,
                      customPrompt: customPrompt,
                    ));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, RefinementState state) {
    final String refinedText = _getRefinedText(state);
    final bool isStreaming = state is RefinementInProgress &&
        (state as RefinementInProgress).isStreaming;

    return RefinementActionBar(
      onAccept: isStreaming || refinedText.isEmpty
          ? null
          : () {
              context.read<RefinementBloc>().add(AcceptRefinement(
                    sessionId: sessionId,
                    refinedText: refinedText,
                  ));
            },
      onDiscard: () {
        context.read<RefinementBloc>().add(DiscardRefinement(
              sessionId: sessionId,
            ));
      },
      onCancel: () => Navigator.pop(context),
      onRegenerate: () {
        context.read<RefinementBloc>().add(RegenerateRefinement(
              sessionId: sessionId,
              text: originalText,
              languageCode: languageCode,
            ));
      },
      isLoading: isStreaming,
      showRegenerate: state is RefinementCompleted || state is RefinementError,
    );
  }

  /// Extracts the original text from any state.
  String _getOriginalText(RefinementState state) {
    if (state is RefinementInProgress) return state.originalText;
    if (state is RefinementCompleted) return state.originalText;
    if (state is RefinementError) return state.originalText;
    return originalText;
  }

  /// Extracts the refined text from any state.
  String _getRefinedText(RefinementState state) {
    if (state is RefinementInProgress) return state.accumulatedText;
    if (state is RefinementCompleted) return state.refinedText;
    return '';
  }

  void _showSnackBar(BuildContext context, String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
