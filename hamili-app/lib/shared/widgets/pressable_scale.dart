import 'package:flutter/material.dart';

/// Wraps a tappable widget with a subtle spring-scale on press (0.96),
/// per the ui-ux-pro-max `scale-feedback` guideline. Non-blocking and
/// interruptible — the scale just tracks the press state.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap, this.pressedScale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
