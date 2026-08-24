/// Hand-drawn illustrations for the "cozy coffee shop" brand.
///
/// [MokaPotSketch] is still a CustomPaint placeholder (small coordinate wobble
/// instead of perfect CAD curves, so it doesn't read as "AI doodle") — no moka pot
/// asset has landed yet. [CoffeeCupSketch], [CoffeeOnBooksSketch], and
/// [CafeShelfSketch] are backed by real PNGs in assets/illustrations/ (registered
/// in pubspec.yaml), recolored via [_AssetSketch] so they sit in the app's warm-ink
/// register instead of the source art's flat black.
library;

import 'package:flutter/material.dart';
import 'package:mobile/design/theme.dart';

/// Renders a hand-drawn PNG asset, recolored to [color] via `BlendMode.srcIn` —
/// the source art is solid black-on-transparent, so this swaps in the brand's
/// warm ink (or whatever tone the call site needs) instead of flat black.
class _AssetSketch extends StatelessWidget {
  final String asset;
  final double width;
  final double height;
  final Color color;

  const _AssetSketch({
    required this.asset,
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(asset, width: width, height: height, fit: BoxFit.contain),
    );
  }
}

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

/// A coffee cup on a saucer with a curl of steam — echoes the cup-and-croissant
/// reference. Deliberately simpler than the café shelf: one warm signature object
/// rather than a whole still-life.
class CoffeeCupSketch extends StatelessWidget {
  final double size;
  final Color color;

  const CoffeeCupSketch({super.key, this.size = 100, this.color = Tone.ink});

  @override
  Widget build(BuildContext context) {
    // Source art is 1500x1670.
    return _AssetSketch(
      asset: 'assets/illustrations/coffeeWithSteam.png',
      width: size,
      height: size * 1670 / 1500,
      color: color,
    );
  }
}

/// A steaming mug resting on a stack of books — the "study spot" pairing. Reach
/// for this where the app has nothing to show yet, rather than the standalone cup.
class CoffeeOnBooksSketch extends StatelessWidget {
  final double size;
  final Color color;

  const CoffeeOnBooksSketch({super.key, this.size = 100, this.color = Tone.ink});

  @override
  Widget build(BuildContext context) {
    // Source art is 1500x2044.
    return _AssetSketch(
      asset: 'assets/illustrations/coffeeOnBooks.png',
      width: size,
      height: size * 2044 / 1500,
      color: color,
    );
  }
}

/// A café shelf of mugs over a table-and-chairs scene. Busier than the other two —
/// it's a whole-room still life, not a single object — so it reads best as a full
/// branding moment (a splash or welcome screen) rather than a small inline accent.
class CafeShelfSketch extends StatelessWidget {
  final double size;
  final Color color;

  const CafeShelfSketch({super.key, this.size = 160, this.color = Tone.ink});

  @override
  Widget build(BuildContext context) {
    // Source art is 1500x1703.
    return _AssetSketch(
      asset: 'assets/illustrations/coffeeTable.png',
      width: size,
      height: size * 1703 / 1500,
      color: color,
    );
  }
}

/// A puzzled cat — the one non-coffee sketch, reserved for "you're not signed in
/// yet" on the Profile tab rather than the empty/loading states the coffee sketches
/// cover.
class ConfusedCatSketch extends StatelessWidget {
  final double size;
  final Color color;

  const ConfusedCatSketch({super.key, this.size = 120, this.color = Tone.ink});

  @override
  Widget build(BuildContext context) {
    // Source art is 1500x2211.
    return _AssetSketch(
      asset: 'assets/illustrations/confusedCat.png',
      width: size,
      height: size * 2211 / 1500,
      color: color,
    );
  }
}
