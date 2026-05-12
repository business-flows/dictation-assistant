import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An animated audio amplitude visualizer bar.
///
/// Listens to a stream of amplitude values (0.0 to 1.0) and displays
/// a horizontal bar that smoothly animates based on the amplitude.
/// When amplitude is near 0, shows a thin idle line.
/// Colors transition from green (low) to yellow (medium) to red (high).
class AudioVisualizer extends StatelessWidget {
  /// Stream of amplitude values between 0.0 and 1.0.
  final Stream<double> amplitudeStream;

  /// Height of the visualizer bar in pixels.
  final double height;

  /// Optional override color. If null, uses dynamic coloring based on amplitude.
  final Color? color;

  const AudioVisualizer({
    super.key,
    required this.amplitudeStream,
    this.height = 40.0,
    this.color,
  });

  /// Get a color based on amplitude level.
  static Color _amplitudeColor(double amplitude) {
    if (amplitude < 0.33) {
      return const Color(0xFF2D6A4F);
    } else if (amplitude < 0.66) {
      return const Color(0xFFE9C46A);
    } else {
      return const Color(0xFFE63946);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<double>(
      stream: amplitudeStream,
      initialData: 0.0,
      builder: (context, snapshot) {
        final amplitude = snapshot.data?.clamp(0.0, 1.0) ?? 0.0;
        final barColor = color ?? _amplitudeColor(amplitude);
        final isIdle = amplitude < 0.05;

        return Container(
          width: double.infinity,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Main amplitude bar
              Container(
                width: double.infinity,
                height: isIdle ? 2 : height - 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(isIdle ? 1 : 8),
                ),
                child: Stack(
                  children: [
                    // Background track
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(isIdle ? 1 : 8),
                      ),
                    ),
                    // Animated fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeInOut,
                      width: isIdle ? 0 : null,
                      height: isIdle ? 2 : null,
                      child: FractionallySizedBox(
                        widthFactor: amplitude,
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                barColor.withAlpha(204),
                                barColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(isIdle ? 1 : 8),
                            boxShadow: isIdle
                                ? null
                                : [
                                    BoxShadow(
                                      color: barColor.withAlpha(76),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Multi-segment visualizer (decorative bars)
              if (!isIdle) ...[
                const SizedBox(height: 6),
                _SegmentVisualizer(
                  amplitude: amplitude,
                  barColor: barColor,
                  segmentCount: 32,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A multi-segment bar visualizer with individual animated segments.
class _SegmentVisualizer extends StatelessWidget {
  final double amplitude;
  final Color barColor;
  final int segmentCount;

  const _SegmentVisualizer({
    required this.amplitude,
    required this.barColor,
    required this.segmentCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(segmentCount, (index) {
          // Create a wave pattern based on position and amplitude
          final position = index / segmentCount;
          final wave1 = math.sin(position * math.pi * 4 + amplitude * math.pi * 2);
          final wave2 = math.cos(position * math.pi * 6 + amplitude * math.pi);
          final combinedWave = (wave1 + wave2) / 2; // -1 to 1

          // Scale by amplitude: higher amplitude = more variation
          final segmentHeight = 3.0 + (amplitude * 9.0 * (0.3 + 0.7 * (combinedWave.abs())));
          final isActive = position <= amplitude;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            width: 3,
            height: isActive ? segmentHeight.clamp(3.0, 12.0) : 3.0,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: isActive
                  ? barColor.withAlpha(
                      (180 + (75 * combinedWave.abs())).toInt().clamp(100, 255),
                    )
                  : barColor.withAlpha(30),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
