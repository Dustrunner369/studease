import 'package:flutter/material.dart';
import 'package:mobile/design/theme.dart';

/// Scales down slightly on press, back to rest on release — the recipe from
/// Hallmark's microinteractions.md, not a Material ripple. Replaces InkWell where
/// used so the app reads as its own thing rather than generic Material.
///
/// Respects reduced motion: [MediaQuery.disableAnimations] skips the scale, but the
/// tap still fires — the animation is decoration, never the mechanism.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const PressScale({super.key, required this.child, this.onTap, this.borderRadius});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final scale = _pressed && !reduceMotion ? 0.98 : 1.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: scale,
        duration: _pressed ? const Duration(milliseconds: 100) : Motion.micro,
        curve: _pressed ? Motion.easeIn : Motion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades and rises into place once, the first time this widget's element is built —
/// not on every rebuild. Give it a stable `index` (its position when the list first
/// loaded) to stagger a page-load reveal per Hallmark's motion.md § Page-load
/// orchestration, capped so the whole list settles within ~500ms regardless of
/// length.
///
/// Relies on Flutter reusing State across rebuilds for a widget at a stable key/
/// position — a row already on screen during a pull-to-refresh does NOT replay this,
/// only genuinely new rows do.
class RevealOnce extends StatefulWidget {
  final int index;
  final Widget child;

  const RevealOnce({super.key, required this.index, required this.child});

  @override
  State<RevealOnce> createState() => _RevealOnceState();
}

class _RevealOnceState extends State<RevealOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _controller = AnimationController(vsync: this, duration: Motion.long);
    _opacity = CurvedAnimation(parent: _controller, curve: Motion.easeOut);
    _offset = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(_opacity);

    // Stagger by position, capped at ~500ms total so a long list doesn't feel slow
    // to settle. Reduced motion: no delay, no rise, just the opacity fade.
    final delay = reduceMotion
        ? Duration.zero
        : Duration(milliseconds: (widget.index * 40).clamp(0, 480));

    if (reduceMotion) {
      _controller.duration = const Duration(milliseconds: 150);
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
