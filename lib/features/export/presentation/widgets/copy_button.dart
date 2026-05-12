import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/export_bloc.dart';
import '../bloc/export_event.dart';
import '../bloc/export_state.dart';

/// A button that copies text to the clipboard and shows visual feedback.
///
/// Displays a copy icon by default. After successful copy, briefly
/// shows a checkmark icon before reverting to the copy icon.
///
/// Usage:
/// ```dart
/// CopyButton(
///   textToCopy: 'Text to copy',
///   onCopied: () => debugPrint('Text was copied'),
/// )
/// ```
class CopyButton extends StatefulWidget {
  /// The text to copy to the clipboard.
  final String textToCopy;

  /// Optional callback invoked after successful copy.
  final VoidCallback? onCopied;

  /// Optional tooltip text.
  final String tooltip;

  /// Optional icon size.
  final double iconSize;

  /// Optional icon color.
  final Color? iconColor;

  /// Creates a [CopyButton].
  const CopyButton({
    super.key,
    required this.textToCopy,
    this.onCopied,
    this.tooltip = 'Copy to clipboard',
    this.iconSize = 20,
    this.iconColor,
  });

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _showCheckmark = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCopy() {
    context.read<ExportBloc>().add(CopyToClipboard(text: widget.textToCopy));
  }

  void _showCopiedFeedback() {
    setState(() => _showCheckmark = true);
    _controller.forward(from: 0);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showCheckmark = false);
      }
    });

    widget.onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExportBloc, ExportState>(
      listener: (context, state) {
        if (state is ClipboardCopied) {
          _showCopiedFeedback();
        }
      },
      child: IconButton(
        onPressed: _handleCopy,
        tooltip: widget.tooltip,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: _showCheckmark ? _scaleAnimation : animation,
              child: child,
            );
          },
          child: _showCheckmark
              ? Icon(
                  Icons.check_circle,
                  key: const ValueKey('check'),
                  size: widget.iconSize,
                  color: Colors.green.shade600,
                )
              : Icon(
                  Icons.copy_outlined,
                  key: const ValueKey('copy'),
                  size: widget.iconSize,
                  color: widget.iconColor,
                ),
        ),
      ),
    );
  }
}

/// A text button variant of the copy button with a label.
///
/// Shows both an icon and text label, useful in menus or toolbars
/// where the action needs to be more explicit.
class CopyTextButton extends StatelessWidget {
  /// The text to copy to the clipboard.
  final String textToCopy;

  /// Optional label override.
  final String label;

  /// Optional callback invoked after successful copy.
  final VoidCallback? onCopied;

  /// Creates a [CopyTextButton].
  const CopyTextButton({
    super.key,
    required this.textToCopy,
    this.label = 'Copy',
    this.onCopied,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExportBloc, ExportState>(
      listener: (context, state) {
        if (state is ClipboardCopied) {
          onCopied?.call();
        }
      },
      child: TextButton.icon(
        onPressed: () {
          context.read<ExportBloc>().add(CopyToClipboard(text: textToCopy));
        },
        icon: const Icon(Icons.copy_outlined, size: 18),
        label: Text(label),
      ),
    );
  }
}
