import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../bloc/dictation_bloc.dart';
import '../bloc/dictation_event.dart';
import '../bloc/dictation_state.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/language_selector.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/recording_controls.dart';
import '../widgets/recording_timer.dart';
import '../widgets/status_indicator.dart';
import '../widgets/transcription_display.dart';

/// The main dictation screen — the primary interface of the app.
///
/// Provides a clean, minimal, focused design for dictation with:
/// - Language selection dropdown
/// - Recording timer
/// - Status indicator
/// - Transcription text display (with RTL support)
/// - Audio amplitude visualizer
/// - Large record button
/// - Quick action buttons (copy, export, refine)
///
/// Layout adapts responsively:
/// - Desktop (>900px): Full layout with sidebar
/// - Mobile (<600px): Compact stacked layout
class DictationPage extends StatefulWidget {
  const DictationPage({super.key});

  @override
  State<DictationPage> createState() => _DictationPageState();
}

class _DictationPageState extends State<DictationPage> {
  /// Whether to show refined text (when available).
  bool _showRefined = false;

  /// Audio amplitude stream controller for the visualizer.
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();

  @override
  void dispose() {
    _amplitudeController.close();
    super.dispose();
  }

  /// Push amplitude updates from state to the visualizer stream.
  void _updateAmplitude(DictationState state) {
    if (_amplitudeController.isClosed) return;

    if (state is DictationRecording) {
      _amplitudeController.add(state.currentAmplitude);
    } else if (state is DictationProcessing) {
      _amplitudeController.add(0.05);
    } else {
      _amplitudeController.add(0.0);
    }
  }

  /// Handle keyboard shortcuts.
  void _handleKeyEvent(KeyEvent event, DictationState state) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        // Space = start/stop recording
        if (state is DictationReady) {
          context.read<DictationBloc>().add(const StartDictationPressed());
        } else if (state is DictationRecording) {
          context.read<DictationBloc>().add(const StopDictationPressed());
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        // Escape = stop recording
        if (state is DictationRecording) {
          context.read<DictationBloc>().add(const StopDictationPressed());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DictationBloc, DictationState>(
      listenWhen: (previous, current) =>
          current is DictationError ||
          current is DictationCompleted ||
          (current is DictationRecording && previous is! DictationRecording) ||
          (current is! DictationRecording && previous is DictationRecording),
      listener: (context, state) {
        if (state is DictationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Theme.of(context).colorScheme.onError,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }

        if (state is DictationRecording) {
          // Reset refined view when starting a new recording
          setState(() => _showRefined = false);
        }
      },
      builder: (context, state) {
        // Update amplitude stream based on state
        _updateAmplitude(state);

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            _handleKeyEvent(event, state);
            return KeyEventResult.ignored;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > AppConstants.desktopBreakpoint;
              final isMobile = constraints.maxWidth < AppConstants.tabletBreakpoint;

              return _buildContent(
                context: context,
                state: state,
                isDesktop: isDesktop,
                isMobile: isMobile,
              );
            },
          ),
        );
      },
    );
  }

  /// Build the main content layout based on screen size.
  Widget _buildContent({
    required BuildContext context,
    required DictationState state,
    required bool isDesktop,
    required bool isMobile,
  }) {
    final padding = isDesktop ? 24.0 : 16.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          children: [
            // Top bar: Language | Timer | Status
            _buildTopBar(context, state, isMobile),

            const SizedBox(height: 16),

            // Transcription text area (expands to fill space)
            Expanded(
              flex: 3,
              child: _buildTranscriptionArea(context, state),
            ),

            const SizedBox(height: 12),

            // Quick actions bar (when text is available)
            if (state.currentText != null && state.currentText!.isNotEmpty)
              _buildQuickActions(context, state),

            if (state.currentText != null && state.currentText!.isNotEmpty)
              const SizedBox(height: 12),

            // Audio visualizer
            _buildVisualizer(state),

            const SizedBox(height: 16),

            // Bottom area: Record button
            _buildBottomControls(context, state, isMobile),
          ],
        ),
      ),
    );
  }

  /// Build the top bar with language selector, timer, and status.
  Widget _buildTopBar(
    BuildContext context,
    DictationState state,
    bool isMobile,
  ) {
    final languageEnabled = !state.isRecording && !state.isProcessing;

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LanguageSelector(
                  selectedLanguage: state.selectedLanguage,
                  enabled: languageEnabled,
                  onChanged: (value) {
                    context.read<DictationBloc>().add(
                          LanguageSelected(languageCode: value),
                        );
                  },
                ),
              ),
              const SizedBox(width: 12),
              RecordingTimer(
                elapsedMs: state is DictationRecording ? state.elapsedMs : 0,
                isRunning: state is DictationRecording,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              StatusIndicator(status: state.recordingStatus),
            ],
          ),
        ],
      );
    }

    // Desktop layout
    return Row(
      children: [
        // Language dropdown
        LanguageSelector(
          selectedLanguage: state.selectedLanguage,
          enabled: languageEnabled,
          onChanged: (value) {
            context.read<DictationBloc>().add(
                  LanguageSelected(languageCode: value),
                );
          },
        ),
        const Spacer(),
        // Timer
        RecordingTimer(
          elapsedMs: state is DictationRecording ? state.elapsedMs : 0,
          isRunning: state is DictationRecording,
        ),
        const SizedBox(width: 16),
        // Status indicator
        StatusIndicator(status: state.recordingStatus),
      ],
    );
  }

  /// Build the transcription text area.
  Widget _buildTranscriptionArea(BuildContext context, DictationState state) {
    final text = state.currentText ?? '';
    final isArabic = state.selectedLanguage == 'ar';
    final refinedText = state is DictationCompleted ? state.refinedText : null;
    final isRefinedAvailable = refinedText != null && refinedText.isNotEmpty;

    return TranscriptionDisplay(
      text: text,
      isRtl: isArabic,
      isRefinedAvailable: isRefinedAvailable,
      refinedText: refinedText,
      showRefined: _showRefined,
      onShowRefinedChanged: (showRefined) {
        setState(() => _showRefined = showRefined);
      },
    );
  }

  /// Build the quick actions bar.
  Widget _buildQuickActions(BuildContext context, DictationState state) {
    final text = state.currentText ?? '';
    final refinedText = state is DictationCompleted ? state.refinedText : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        QuickActionsBar(
          text: text,
          refinedText: refinedText,
          onCopy: () async {
            final textToCopy = (_showRefined && refinedText != null)
                ? refinedText
                : text;
            await ClipboardHelper.copyWithFeedback(
              context,
              textToCopy,
              message: 'Transcription copied',
            );
          },
          onExport: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Export feature coming soon'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          },
          onRefine: null, // LLM refine not yet configured
        ),
      ],
    );
  }

  /// Build the audio visualizer.
  Widget _buildVisualizer(DictationState state) {
    return AudioVisualizer(
      amplitudeStream: _amplitudeController.stream,
      height: 40,
    );
  }

  /// Build the bottom controls (record button).
  Widget _buildBottomControls(
    BuildContext context,
    DictationState state,
    bool isMobile,
  ) {
    final buttonSize = isMobile ? 80.0 : 72.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RecordingButtonWithPulse(
            status: state.recordingStatus,
            size: buttonSize,
            onPressed: () {
              if (state is DictationReady || state is DictationInitial) {
                context.read<DictationBloc>().add(const StartDictationPressed());
              } else if (state is DictationRecording) {
                context.read<DictationBloc>().add(const StopDictationPressed());
              }
            },
          ),
        ],
      ),
    );
  }
}
