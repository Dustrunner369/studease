// STUDY SPOTS — concept 4: "the corner table"
// cozy + hipster, built on your uploaded palette:
//   Saffron #F8C662 · Ultra Violet #595082 · Dark Purple #2C263F
//   Hunter Green #41644A · Dark Green #213722
//
// vibe: candlelit café menu — serif type, passport-stamp scores,
// dotted menu leaders, alternating velvet cards
//
// Setup:
//   1. pubspec.yaml needs google_fonts (you already have it).
//   2. Save as lib/main_cozy.dart and run with:
//        flutter run -t lib/main_cozy.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const StudySpotsCozyApp());
}

// ---------------------------------------------------------------------------
// Design tokens — your palette + two neutrals for readability
// ---------------------------------------------------------------------------

abstract final class Cozy {
  static const forest = Color(0xFF213722); // dark green — background
  static const moss = Color(0xFF41644A); // hunter green
  static const mossDeep = Color(0xFF35523E); // hunter green, dimmed (cards)
  static const plum = Color(0xFF2C263F); // dark purple (cards)
  static const violet = Color(0xFF595082); // ultra violet (borders, meta)
  static const saffron = Color(0xFFF8C662); // accent

  static const cream = Color(0xFFF4EEDD); // primary text
  static const fog = Color(0xFFB9B3CE); // secondary text (violet tint)
}

/// Ratings as "strength dots", like espresso shots on a menu.
enum Level {
  good(3, 'lovely'),
  ok(2, 'decent'),
  rough(1, 'rough');

  final int dots;
  final String word;
  const Level(this.dots, this.word);
}

enum SpotType {
  cafe('café'),
  library('library'),
  campus('campus');

  final String label;
  const SpotType(this.label);
}

// ---------------------------------------------------------------------------
// Model + sample data (same shape as the other concepts)
// ---------------------------------------------------------------------------

class StudySpot {
  final String name;
  final SpotType type;
  final double score;
  final String distance;
  final String hours;
  final Level wifi;
  final Level seating;
  final Level noise;
  final Level coffee;
  final Level outlets;

  const StudySpot({
    required this.name,
    required this.type,
    required this.score,
    required this.distance,
    required this.hours,
    required this.wifi,
    required this.seating,
    required this.noise,
    required this.coffee,
    required this.outlets,
  });

  List<(IconData, String, Level)> get amenities => [
        (Icons.wifi, 'wi-fi', wifi),
        (Icons.event_seat, 'seating', seating),
        (Icons.volume_up, 'noise', noise),
        (Icons.local_cafe, 'coffee', coffee),
        (Icons.bolt, 'outlets', outlets),
      ];
}

// TODO: replace with ApiService.getSpots() once the .NET endpoint is wired up.
const _sampleSpots = <StudySpot>[
  StudySpot(
    name: "Lestat's Coffee House",
    type: SpotType.cafe,
    score: 9.4,
    distance: '4.6 mi',
    hours: 'open 24 hrs',
    wifi: Level.good,
    seating: Level.good,
    noise: Level.ok,
    coffee: Level.good,
    outlets: Level.good,
  ),
  StudySpot(
    name: 'Ryan Library',
    type: SpotType.library,
    score: 9.1,
    distance: '0.2 mi',
    hours: 'til 11 pm',
    wifi: Level.good,
    seating: Level.good,
    noise: Level.good,
    coffee: Level.rough,
    outlets: Level.good,
  ),
  StudySpot(
    name: 'Fermanian Lounge',
    type: SpotType.campus,
    score: 8.6,
    distance: '0.1 mi',
    hours: 'til 10 pm',
    wifi: Level.good,
    seating: Level.ok,
    noise: Level.good,
    coffee: Level.rough,
    outlets: Level.ok,
  ),
  StudySpot(
    name: 'Communal Coffee',
    type: SpotType.cafe,
    score: 8.4,
    distance: '5.1 mi',
    hours: 'til 5 pm',
    wifi: Level.ok,
    seating: Level.ok,
    noise: Level.ok,
    coffee: Level.good,
    outlets: Level.rough,
  ),
  StudySpot(
    name: 'Moniker General',
    type: SpotType.cafe,
    score: 8.0,
    distance: '3.4 mi',
    hours: 'til 9 pm',
    wifi: Level.good,
    seating: Level.good,
    noise: Level.rough,
    coffee: Level.good,
    outlets: Level.ok,
  ),
  StudySpot(
    name: 'Hervey Branch Library',
    type: SpotType.library,
    score: 7.9,
    distance: '1.2 mi',
    hours: 'til 6 pm',
    wifi: Level.ok,
    seating: Level.good,
    noise: Level.good,
    coffee: Level.rough,
    outlets: Level.ok,
  ),
  StudySpot(
    name: 'Better Buzz Point Loma',
    type: SpotType.cafe,
    score: 7.6,
    distance: '1.8 mi',
    hours: 'til 7 pm',
    wifi: Level.ok,
    seating: Level.rough,
    noise: Level.rough,
    coffee: Level.good,
    outlets: Level.rough,
  ),
];

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class StudySpotsCozyApp extends StatelessWidget {
  const StudySpotsCozyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'study spots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Cozy.forest,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Cozy.saffron,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.karlaTextTheme(ThemeData.dark().textTheme),
        splashColor: Cozy.saffron.withValues(alpha: 0.08),
        highlightColor: Cozy.saffron.withValues(alpha: 0.05),
      ),
      home: const SpotsPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Spots page
// ---------------------------------------------------------------------------

class SpotsPage extends StatefulWidget {
  const SpotsPage({super.key});

  @override
  State<SpotsPage> createState() => _SpotsPageState();
}

class _SpotsPageState extends State<SpotsPage> {
  SpotType? _filter;

  List<StudySpot> get _visibleSpots {
    final spots =
        _sampleSpots.where((s) => _filter == null || s.type == _filter).toList();
    spots.sort((a, b) => b.score.compareTo(a.score));
    return spots;
  }

  void _soon(String message) => showCozySnack(context, message);

  @override
  Widget build(BuildContext context) {
    final spots = _visibleSpots;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            const OrnamentDivider(),
            const SizedBox(height: 18),
            _buildFilters(),
            const SizedBox(height: 20),
            for (var i = 0; i < spots.length; i++) ...[
              if (i == 0 && _filter == null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    '✳ house favorite',
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Cozy.saffron,
                    ),
                  ),
                ),
              ],
              SpotCard(spot: spots[i], index: i),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _soon('add a spot — coming soon'),
        backgroundColor: Cozy.saffron,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Cozy.forest),
      ),
      bottomNavigationBar: const CozyBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EST. 2026 · POINT LOMA',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Cozy.fog,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'My Spots',
                style: GoogleFonts.fraunces(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  color: Cozy.cream,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'for slow mornings & long study nights',
                style: GoogleFonts.karla(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Cozy.fog,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => _soon('search — coming soon'),
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Cozy.violet, width: 1.5),
            ),
            child: const Icon(Icons.search, size: 20, color: Cozy.cream),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final options = <(String, SpotType?)>[
      ('all', null),
      for (final t in SpotType.values) ('${t.label}s', t),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (label, type) in options) ...[
            InkWell(
              onTap: () => setState(() => _filter = type),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      _filter == type ? Cozy.saffron : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _filter == type ? Cozy.saffron : Cozy.violet,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _filter == type ? Cozy.forest : Cozy.fog,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spot card — alternating velvet tones, stamp score, espresso-dot ratings
// ---------------------------------------------------------------------------

class SpotCard extends StatelessWidget {
  final StudySpot spot;
  final int index;

  const SpotCard({super.key, required this.spot, required this.index});

  @override
  Widget build(BuildContext context) {
    final cardColor = index.isEven ? Cozy.plum : Cozy.mossDeep;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => SpotDetailSheet(spot: spot),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Cozy.violet.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              ScoreStamp(score: spot.score, tilt: index.isEven ? -0.09 : 0.07),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: GoogleFonts.fraunces(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Cozy.cream,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${spot.type.label} · ${spot.distance} · ${spot.hours}',
                      style: GoogleFonts.karla(
                        fontSize: 12.5,
                        color: Cozy.fog,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final (icon, label, level)
                            in spot.amenities) ...[
                          AmenityDots(icon: icon, label: label, level: level),
                          const SizedBox(width: 14),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Passport-stamp score: dashed saffron circle, slightly tilted.
class ScoreStamp extends StatelessWidget {
  final double score;
  final double tilt;

  const ScoreStamp({super.key, required this.score, this.tilt = -0.09});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: SizedBox(
        width: 56,
        height: 56,
        child: CustomPaint(
          painter: const _StampPainter(),
          child: Center(
            child: Text(
              score.toStringAsFixed(1),
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Cozy.saffron,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  const _StampPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2 - 1.5;

    final dashed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = Cozy.saffron;

    // dashed outer ring
    const dashes = 22;
    for (var i = 0; i < dashes; i++) {
      final start = (i * 2 * math.pi / dashes);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outer),
        start,
        math.pi / dashes * 0.9,
        false,
        dashed,
      );
    }

    // faint inner ring
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Cozy.saffron.withValues(alpha: 0.4);
    canvas.drawCircle(center, outer - 5, inner);
  }

  @override
  bool shouldRepaint(_StampPainter old) => false;
}

/// Amenity icon with espresso-shot dots underneath (3 = lovely, 1 = rough).
class AmenityDots extends StatelessWidget {
  final IconData icon;
  final String label;
  final Level level;

  const AmenityDots({
    super.key,
    required this.icon,
    required this.label,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label: ${level.word}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Cozy.cream.withValues(alpha: 0.85)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1.2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < level.dots
                        ? Cozy.saffron
                        : Cozy.violet.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spot detail bottom sheet — café-menu style with dotted leaders
// ---------------------------------------------------------------------------

void showCozySnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Cozy.plum,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Cozy.violet.withValues(alpha: 0.6)),
      ),
      content: Text(
        message,
        style: GoogleFonts.karla(
          color: Cozy.cream,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class SpotDetailSheet extends StatelessWidget {
  final StudySpot spot;

  const SpotDetailSheet({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Cozy.plum,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: Cozy.violet.withValues(alpha: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Cozy.violet,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ScoreStamp(score: spot.score, tilt: 0.06),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.name,
                          style: GoogleFonts.fraunces(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            color: Cozy.cream,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${spot.type.label} · ${spot.distance} · ${spot.hours}',
                          style: GoogleFonts.karla(
                            fontSize: 12.5,
                            color: Cozy.fog,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const OrnamentDivider(),
              const SizedBox(height: 16),
              for (final (icon, label, level) in spot.amenities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(icon,
                          size: 17,
                          color: Cozy.cream.withValues(alpha: 0.85)),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: GoogleFonts.karla(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Cozy.cream,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          child: CustomPaint(
                            size: const Size(double.infinity, 12),
                            painter: const _DottedLeaderPainter(),
                          ),
                        ),
                      ),
                      Text(
                        level.word,
                        style: GoogleFonts.fraunces(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: Cozy.saffron,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SheetButton(
                      label: 'directions',
                      icon: Icons.near_me,
                      filled: true,
                      onTap: () =>
                          showCozySnack(context, 'directions — coming soon'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SheetButton(
                      label: 'edit spot',
                      icon: Icons.edit_outlined,
                      filled: false,
                      onTap: () =>
                          showCozySnack(context, 'edit spot — coming soon'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DottedLeaderPainter extends CustomPainter {
  const _DottedLeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Cozy.violet;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawCircle(Offset(x, size.height - 3), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLeaderPainter old) => false;
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Cozy.forest : Cozy.cream;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? Cozy.saffron : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: Cozy.violet, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.karla(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ornament divider:  ————— ✳ —————
// ---------------------------------------------------------------------------

class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    Widget line() => Expanded(
          child: Container(
            height: 1,
            color: Cozy.violet.withValues(alpha: 0.5),
          ),
        );

    return Row(
      children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '✳',
            style: GoogleFonts.karla(fontSize: 13, color: Cozy.saffron),
          ),
        ),
        line(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav
// ---------------------------------------------------------------------------

class CozyBottomNav extends StatelessWidget {
  const CozyBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Cozy.forest,
        border: Border(
          top: BorderSide(
            color: Cozy.violet.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _NavItem(icon: Icons.place, label: 'spots', active: true),
              _NavItem(icon: Icons.map_outlined, label: 'map', active: false),
              _NavItem(
                  icon: Icons.person_outline, label: 'me', active: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _NavItem(
      {required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Cozy.saffron : Cozy.fog;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 21, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.karla(
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}