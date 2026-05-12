import 'dart:async';

import 'package:flutter/material.dart';

/// A timer display that formats elapsed time as MM:SS or HH:MM:SS.
///
/// Uses a monospaced font for stable width to prevent UI jitter.
/// When [isRunning] is true, updates every second via a [StreamBuilder].
class RecordingTimer extends StatelessWidget {
  /// Elapsed time in milliseconds.
  final int elapsedMs;

  /// Whether the timer is actively counting.
  final bool isRunning;

  const RecordingTimer({
    super.key,
    required this.elapsedMs,
    this.isRunning = false,
  });

  /// Format milliseconds into MM:SS or HH:MM:SS display.
  static String formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }

    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // When running, use a stream to trigger updates every second
    // Otherwise, just display the static time
    Widget timeDisplay;

    if (isRunning) {
      timeDisplay = StreamBuilder(
        stream: Stream.periodic(const Duration(seconds: 1)),
        builder: (context, _) {
          return _buildTimeText(theme);
        },
      );
    } else {
      timeDisplay = _buildTimeText(theme);
    }

    return Tooltip(
      message: isRunning ? 'Recording time' : 'Timer',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isRunning
              ? theme.colorScheme.primaryContainer.withAlpha(128)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRunning ? Icons.fiber_manual_record : Icons.timer_outlined,
              size: 18,
              color: isRunning
                  ? const Color(0xFFE63946)
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey(elapsedMs),
                child: timeDisplay,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the formatted time text with monospaced font.
  Widget _buildTimeText(ThemeData theme) {
    return Text(
      formatDuration(elapsedMs),
      style: theme.textTheme.titleLarge?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }
}
