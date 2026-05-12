import 'package:flutter/material.dart';

import '../bloc/dictation_state.dart';

/// A large circular recording button that changes appearance based on recording status.
///
/// Displays:
/// - Idle: Green background with microphone icon
/// - Recording: Red background with stop icon
/// - Processing: Grey background with circular progress indicator (disabled)
///
/// Uses [AnimatedContainer] for smooth state transitions (200ms).
class RecordingButton extends StatelessWidget {
  /// Current recording status to display.
  final RecordingStatus status;

  /// Callback when the button is pressed.
  final VoidCallback onPressed;

  /// Diameter of the circular button.
  final double size;

  const RecordingButton({
    super.key,
    required this.status,
    required this.onPressed,
    this.size = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine colors and icon based on status
    final (Color backgroundColor, Color foregroundColor, Widget child, bool isEnabled) =
        switch (status) {
      RecordingStatus.idle => (
        const Color(0xFF2D6A4F),
        Colors.white,
        Icon(Icons.mic, size: size * 0.4),
        true,
      ),
      RecordingStatus.recording => (
        const Color(0xFFE63946),
        Colors.white,
        Icon(Icons.stop, size: size * 0.4),
        true,
      ),
      RecordingStatus.processing => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        SizedBox(
          width: size * 0.35,
          height: size * 0.35,
          child: const CircularProgressIndicator(strokeWidth: 3),
        ),
        false,
      ),
    };

    return Tooltip(
      message: switch (status) {
        RecordingStatus.idle => 'Start recording',
        RecordingStatus.recording => 'Stop recording',
        RecordingStatus.processing => 'Processing...',
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: backgroundColor.withAlpha(76),
                    blurRadius: status == RecordingStatus.recording ? 20 : 8,
                    spreadRadius: status == RecordingStatus.recording ? 4 : 0,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            customBorder: const CircleBorder(),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: IconTheme(
                  key: ValueKey(status),
                  data: IconThemeData(
                    color: foregroundColor,
                    size: size * 0.4,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pulse animation wrapper for the recording button.
///
/// Adds a pulsing ring animation around the button when recording.
class RecordingButtonWithPulse extends StatelessWidget {
  final RecordingStatus status;
  final VoidCallback onPressed;
  final double size;

  const RecordingButtonWithPulse({
    super.key,
    required this.status,
    required this.onPressed,
    this.size = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    if (status != RecordingStatus.recording) {
      return RecordingButton(
        status: status,
        onPressed: onPressed,
        size: size,
      );
    }

    return _PulseAnimation(
      size: size,
      child: RecordingButton(
        status: status,
        onPressed: onPressed,
        size: size,
      ),
    );
  }
}

/// Animated pulse ring that appears around the button during recording.
class _PulseAnimation extends StatefulWidget {
  final double size;
  final Widget child;

  const _PulseAnimation({required this.size, required this.child});

  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size * 1.6,
          height: widget.size * 1.6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: widget.size + (widget.size * 0.6 * _animation.value),
                height: widget.size + (widget.size * 0.6 * _animation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE63946).withAlpha(
                    (38 * (1 - _animation.value)).toInt(),
                  ),
                ),
              ),
              // Inner pulse ring
              Container(
                width: widget.size + (widget.size * 0.3 * _animation.value),
                height: widget.size + (widget.size * 0.3 * _animation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE63946).withAlpha(
                    (25 * (1 - _animation.value)).toInt(),
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: Center(child: widget.child),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
