/// Hand-built placeholder illustrations in the loose, sketchy-ink style from the
/// brand references — a moka pot, a coffee cup. These are deliberately rough (small
/// coordinate wobble instead of perfect CAD curves) rather than slick, since a too-
/// clean line reads as "AI doodle," not "hand drawn."
///
/// Placeholders only. Drop real asset files into assets/illustrations/ (registered
/// in pubspec.yaml) and swap the call sites in main.dart / login_page.dart from
/// e.g. `MokaPotSketch()` to `Image.asset('assets/illustrations/moka-pot.png')` —
/// nothing else about the layout needs to change, both are just a `Widget`.
library;

import 'package:flutter/material.dart';
import 'package:mobile/design/theme.dart';

class _SketchPainter extends CustomPainter {
  final Color color;
  final void Function(Canvas canvas, Size size, Paint paint) draw;

  _SketchPainter({required this.color, required this.draw});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide / 34
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    draw(canvas, size, paint);
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A stovetop moka pot, side profile — echoes the "shelf of coffee things" reference.
/// Drawn in a 120x150 logical box, scaled to fill whatever size it's given.
class MokaPotSketch extends StatelessWidget {
  final double size;
  final Color color;

  const MokaPotSketch({super.key, this.size = 120, this.color = Tone.ink});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.25,
      child: CustomPaint(
        painter: _SketchPainter(color: color, draw: _drawMokaPot),
      ),
    );
  }

  static void _drawMokaPot(Canvas canvas, Size size, Paint paint) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x * w / 120, y * h / 150);

    // Base — wide octagonal chamber, tapering up. Points nudged off-grid on
    // purpose so the silhouette doesn't read as machine-perfect.
    final base = Path()
      ..moveTo(p(24, 148).dx, p(24, 148).dy)
      ..lineTo(p(96, 147).dx, p(96, 147).dy)
      ..lineTo(p(92, 108).dx, p(92, 108).dy)
      ..quadraticBezierTo(p(74, 92).dx, p(74, 92).dy, p(60, 92).dx, p(60, 92).dy)
      ..quadraticBezierTo(p(46, 93).dx, p(46, 93).dy, p(29, 109).dx, p(29, 109).dy)
      ..close();
    canvas.drawPath(base, paint);

    // Waist rule where the two chambers screw together.
    final waist = Path()
      ..moveTo(p(30, 92).dx, p(30, 92).dy)
      ..lineTo(p(90, 91).dx, p(90, 91).dy);
    canvas.drawPath(waist, paint);

    // Top chamber — a shorter, slightly narrower echo of the base.
    final top = Path()
      ..moveTo(p(33, 91).dx, p(33, 91).dy)
      ..lineTo(p(87, 90).dx, p(87, 90).dy)
      ..lineTo(p(80, 58).dx, p(80, 58).dy)
      ..quadraticBezierTo(p(60, 46).dx, p(60, 46).dy, p(40, 58).dx, p(40, 58).dy)
      ..close();
    canvas.drawPath(top, paint);

    // Lid, domed, with a small round knob.
    final lid = Path()
      ..moveTo(p(38, 46).dx, p(38, 46).dy)
      ..quadraticBezierTo(p(60, 30).dx, p(60, 30).dy, p(83, 47).dx, p(83, 47).dy);
    canvas.drawPath(lid, paint);
    canvas.drawCircle(p(60, 26), w / 40, paint);

    // Spout, jutting left off the top chamber.
    final spout = Path()
      ..moveTo(p(40, 62).dx, p(40, 62).dy)
      ..lineTo(p(16, 52).dx, p(16, 52).dy)
      ..lineTo(p(22, 70).dx, p(22, 70).dy)
      ..close();
    canvas.drawPath(spout, paint);

    // Handle, right side — a single confident curve, not a closed shape.
    final handle = Path()
      ..moveTo(p(88, 68).dx, p(88, 68).dy)
      ..cubicTo(
        p(112, 70).dx, p(112, 70).dy,
        p(112, 108).dx, p(112, 108).dy,
        p(90, 112).dx, p(90, 112).dy,
      );
    canvas.drawPath(handle, paint);
  }
}

/// A coffee cup on a saucer, side profile with a little steam — echoes the
/// cup-and-croissant reference. Deliberately simpler than the moka pot: one warm
/// signature object rather than a whole still-life.
class CoffeeCupSketch extends StatelessWidget {
  final double size;
  final Color color;

  const CoffeeCupSketch({super.key, this.size = 100, this.color = Tone.ink});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.85,
      child: CustomPaint(
        painter: _SketchPainter(color: color, draw: _drawCup),
      ),
    );
  }

  static void _drawCup(Canvas canvas, Size size, Paint paint) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x * w / 100, y * h / 85);

    // Cup body — a soft trapezoid, wider at the rim.
    final cup = Path()
      ..moveTo(p(22, 30).dx, p(22, 30).dy)
      ..quadraticBezierTo(p(20, 58).dx, p(20, 58).dy, p(30, 66).dx, p(30, 66).dy)
      ..lineTo(p(62, 66).dx, p(62, 66).dy)
      ..quadraticBezierTo(p(72, 58).dx, p(72, 58).dy, p(70, 30).dx, p(70, 30).dy);
    canvas.drawPath(cup, paint);

    // Rim — a flattened ellipse, slightly open so it doesn't read as a perfect oval.
    final rim = Path()
      ..moveTo(p(22, 30).dx, p(22, 30).dy)
      ..quadraticBezierTo(p(46, 22).dx, p(46, 22).dy, p(70, 30).dx, p(70, 30).dy)
      ..quadraticBezierTo(p(46, 38).dx, p(46, 38).dy, p(22, 30).dx, p(22, 30).dy);
    canvas.drawPath(rim, paint);

    // Handle — one open loop.
    final handle = Path()
      ..moveTo(p(70, 38).dx, p(70, 38).dy)
      ..cubicTo(
        p(90, 36).dx, p(90, 36).dy,
        p(90, 60).dx, p(90, 60).dy,
        p(68, 58).dx, p(68, 58).dy,
      );
    canvas.drawPath(handle, paint);

    // Saucer.
    final saucer = Path()
      ..moveTo(p(10, 70).dx, p(10, 70).dy)
      ..quadraticBezierTo(p(46, 80).dx, p(46, 80).dy, p(84, 70).dx, p(84, 70).dy);
    canvas.drawPath(saucer, paint);

    // Two lazy steam curls — kept within y >= 0 (there's headroom above the rim at
    // y=22) since CustomPaint doesn't clip overflow by default.
    final steam1 = Path()
      ..moveTo(p(38, 20).dx, p(38, 20).dy)
      ..cubicTo(
        p(32, 14).dx, p(32, 14).dy,
        p(44, 10).dx, p(44, 10).dy,
        p(38, 2).dx, p(38, 2).dy,
      );
    final steam2 = Path()
      ..moveTo(p(54, 20).dx, p(54, 20).dy)
      ..cubicTo(
        p(48, 14).dx, p(48, 14).dy,
        p(60, 10).dx, p(60, 10).dy,
        p(54, 2).dx, p(54, 2).dy,
      );
    canvas.drawPath(steam1, paint);
    canvas.drawPath(steam2, paint);
  }
}
