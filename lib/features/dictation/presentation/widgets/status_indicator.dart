import 'package:flutter/material.dart';

import '../bloc/dictation_state.dart';

/// A small status indicator showing the current dictation state.
///
/// Displays a colored dot with a label:
/// - Idle (Ready): Green dot, "Ready" text
/// - Recording: Red pulsing dot, "Recording" text
/// - Processing: Amber dot, "Processing" text
class StatusIndicator extends StatelessWidget {
  /// Current recording status to display.
  final RecordingStatus status;

  const StatusIndicator({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (Color dotColor, String label, bool pulse) = switch (status) {
      RecordingStatus.idle => (
        const Color(0xFF2D6A4F),
        'Ready',
        false,
      ),
      RecordingStatus.recording => (
        const Color(0xFFE63946),
        'Recording',
        true,
      ),
      RecordingStatus.processing => (
        const Color(0xFFE9C46A),
        'Processing',
        false,
      ),
    };

    return Tooltip(
      message: 'Status: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pulse
              ? _PulsingDot(color: dotColor)
              : Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A pulsing colored dot animation used during recording state.
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withAlpha((255 * _animation.value).toInt()),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(
                  (128 * (1 - _animation.value)).toInt(),
                ),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
