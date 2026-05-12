import 'package:flutter/material.dart';

/// Displays the refined text with a streaming animation effect.
///
/// Shows accumulated text as it arrives from the LLM stream, with:
/// - A subtle blinking cursor at the end while streaming is active
/// - Auto-scroll to bottom as new text arrives
/// - Smooth visual feedback for text changes
///
/// Usage:
/// ```dart
/// RefinementPreview(
///   text: accumulatedText,
///   isStreaming: true,
/// )
/// ```
class RefinementPreview extends StatefulWidget {
  /// The accumulated refined text to display.
  final String text;

  /// Whether the stream is still active (shows blinking cursor).
  final bool isStreaming;

  /// Optional text style for the refined text.
  final TextStyle? textStyle;

  /// Creates a [RefinementPreview].
  const RefinementPreview({
    super.key,
    required this.text,
    this.isStreaming = false,
    this.textStyle,
  });

  @override
  State<RefinementPreview> createState() => _RefinementPreviewState();
}

class _RefinementPreviewState extends State<RefinementPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;
  late final Animation<double> _cursorAnimation;
  final ScrollController _scrollController = ScrollController();
  String? _previousText;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cursorAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _cursorController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isStreaming) {
      _cursorController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RefinementPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start/stop cursor animation based on streaming state
    if (widget.isStreaming && !_cursorController.isAnimating) {
      _cursorController.repeat(reverse: true);
    } else if (!widget.isStreaming && _cursorController.isAnimating) {
      _cursorController.stop();
      _cursorController.value = 0.0;
    }

    // Auto-scroll to bottom when text changes
    if (widget.text != _previousText && widget.text.isNotEmpty) {
      _previousText = widget.text;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = widget.textStyle ??
        theme.textTheme.bodyLarge?.copyWith(
          height: 1.6,
          fontSize: 16,
        );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: widget.text,
                    style: effectiveStyle?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (widget.isStreaming)
                    WidgetSpan(
                      child: AnimatedBuilder(
                        animation: _cursorAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _cursorAnimation.value,
                            child: Container(
                              width: 2,
                              height: 18,
                              margin: const EdgeInsets.only(left: 2),
                              color: theme.colorScheme.primary,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shimmer effect widget that indicates streaming is in progress.
///
/// Shows a subtle pulsing gradient to indicate the LLM is still
/// generating text.
class StreamingShimmer extends StatefulWidget {
  /// The child widget to wrap with the shimmer effect.
  final Widget child;

  /// Whether the shimmer animation is active.
  final bool isActive;

  const StreamingShimmer({
    super.key,
    required this.child,
    this.isActive = true,
  });

  @override
  State<StreamingShimmer> createState() => _StreamingShimmerState();
}

class _StreamingShimmerState extends State<StreamingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StreamingShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.1 + (_animation.value * 0.3)),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
