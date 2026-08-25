/// Two "moment of delight" cards, swapped in over a sheet's form once a save
/// succeeds, replacing [main.dart]'s old plain-text toasts for these two flows.
/// Deliberately different weight for each: saving a spot is routine bookkeeping,
/// so [JournalSavedCard] stays quiet — an ink stroke finishing itself, no confetti.
/// Logging a visit is the rewarding moment, so [VisitLoggedCard] gets the bigger
/// payoff — a confetti burst behind the illustration.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile/design/illustrations.dart';
import 'package:mobile/design/theme.dart';

/// A small uppercase pill, e.g. a stat ("3 tags") or a status word ("VISIT
/// LOGGED"). [tone] tints both background and text; leave it at the default for
/// a neutral stat, pass an accent for a status badge.
class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color tone;

  const _Pill({required this.label, this.icon, this.tone = Tone.muted});

  @override
  Widget build(BuildContext context) {
    final onNeutral = tone == Tone.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: onNeutral ? Tone.field : tone.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: onNeutral ? Tone.muted : tone),
            const SizedBox(width: 6),
          ],
          Text(label, style: AppText.label(color: onNeutral ? Tone.muted : tone)),
        ],
      ),
    );
  }
}

/// A checkmark that draws itself stroke-by-stroke, like a tick jotted in a
/// notebook, rather than popping in whole. Delayed slightly so it reads as
/// "written" after the card has already settled, not simultaneous with it.
class _DrawnCheck extends StatefulWidget {
  static const _size = 64.0;

  const _DrawnCheck();

  @override
  State<_DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<_DrawnCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _progress = CurvedAnimation(parent: _controller, curve: Motion.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
      return;
    }
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _DrawnCheck._size,
      height: _DrawnCheck._size,
      decoration: const BoxDecoration(color: Tone.field, shape: BoxShape.circle),
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => CustomPaint(painter: _CheckPainter(progress: _progress.value)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;

  _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = Tone.terracotta
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide / 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width, h = size.height;
    final tick = Path()
      ..moveTo(w * 0.29, h * 0.52)
      ..lineTo(w * 0.44, h * 0.67)
      ..lineTo(w * 0.73, h * 0.35);

    final metric = tick.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Shown in place of [AddSpotSheet]'s form after a brand-new spot saves. Calls
/// [onDone] once the moment has played out — the caller pops the sheet from
/// there, same as the old immediate-pop behavior, just delayed a beat.
class JournalSavedCard extends StatefulWidget {
  final String spotName;
  final int tagCount;
  final VoidCallback onDone;

  const JournalSavedCard({
    super.key,
    required this.spotName,
    required this.tagCount,
    required this.onDone,
  });

  @override
  State<JournalSavedCard> createState() => _JournalSavedCardState();
}

class _JournalSavedCardState extends State<JournalSavedCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Motion.long);
    _opacity = CurvedAnimation(parent: _controller, curve: Motion.easeOut);
    _offset = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(_opacity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _controller.forward();

    Future.delayed(
      reduceMotion ? const Duration(milliseconds: 700) : const Duration(milliseconds: 1700),
      () {
        if (mounted) widget.onDone();
      },
    );
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
      child: SlideTransition(
        position: _offset,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _DrawnCheck(),
              const SizedBox(height: 18),
              Text('Saved to your notebook', textAlign: TextAlign.center, style: AppText.title()),
              const SizedBox(height: 6),
              Text(widget.spotName, textAlign: TextAlign.center, style: AppText.bodySm()),
              if (widget.tagCount > 0) ...[
                const SizedBox(height: 16),
                _Pill(
                  label: widget.tagCount == 1 ? '1 tag' : '${widget.tagCount} tags',
                  icon: Icons.sell_outlined,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final double spin;
  final Color color;
  final bool round;
  final double delay;

  _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.spin,
    required this.color,
    required this.round,
    required this.delay,
  });
}

/// A small burst of squares and dots radiating outward and settling, drawn
/// from the app's own accent trio rather than a rainbow — reads as confetti
/// without breaking from the "vintage general store" palette. Skips entirely
/// under reduced motion (the caller checks [MediaQuery.disableAnimations]
/// before mounting this).
class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst();

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst> with SingleTickerProviderStateMixin {
  static const _colors = [Tone.terracotta, Tone.sage, Tone.slate];

  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();

    final rand = Random();
    _particles = List.generate(18, (i) {
      final angle = -pi / 2 + (rand.nextDouble() * 2 - 1) * (pi * 0.72);
      return _Particle(
        angle: angle,
        distance: 44 + rand.nextDouble() * 42,
        size: 5 + rand.nextDouble() * 5,
        spin: (rand.nextDouble() * 2 - 1) * 3.5,
        color: _colors[rand.nextInt(_colors.length)],
        round: rand.nextBool(),
        delay: rand.nextDouble() * 0.18,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: const Size(220, 150),
          painter: _ConfettiPainter(particles: _particles, t: _controller.value),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ConfettiPainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final eased = Curves.easeOut.transform(local);
      final dx = cos(p.angle) * p.distance * eased;
      final dy = sin(p.angle) * p.distance * eased + 20 * eased * eased;
      final opacity = local < 0.65 ? 1.0 : 1.0 - (local - 0.65) / 0.35;

      canvas.save();
      canvas.translate(center.dx + dx, center.dy + dy);
      canvas.rotate(p.spin * eased * pi);

      final paint = Paint()..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

/// Shown in place of [LogVisitDialog]'s form once a visit logs successfully.
/// Calls [onDone] once the moment has played out — the caller pops the
/// dialog from there, same as the old immediate-pop behavior, just delayed a
/// beat.
class VisitLoggedCard extends StatefulWidget {
  final String spotName;
  final VoidCallback onDone;

  const VisitLoggedCard({
    super.key,
    required this.spotName,
    required this.onDone,
  });

  @override
  State<VisitLoggedCard> createState() => _VisitLoggedCardState();
}

class _VisitLoggedCardState extends State<VisitLoggedCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Motion.long);
    _opacity = CurvedAnimation(parent: _controller, curve: Motion.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(_opacity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _controller.forward();

    Future.delayed(
      _reduceMotion ? const Duration(milliseconds: 800) : const Duration(milliseconds: 2000),
      () {
        if (mounted) widget.onDone();
      },
    );
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
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Pill(label: 'VISIT LOGGED', tone: Tone.sage),
              const SizedBox(height: 16),
              SizedBox(
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_reduceMotion) const _ConfettiBurst(),
                    const CoffeeCupSketch(size: 82, color: Tone.terracotta),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('Nice work!', textAlign: TextAlign.center, style: AppText.title()),
              const SizedBox(height: 6),
              Text(widget.spotName, textAlign: TextAlign.center, style: AppText.bodySm()),
            ],
          ),
        ),
      ),
    );
  }
}
