// STUDY SPOTS — concept 3: "clean ranked" (Beli-inspired)
// simple + modern: white space, ranked rows, colored score bubbles,
// pastel category illustrations, thin lines and small colorful accents
//
// Setup:
//   1. pubspec.yaml needs google_fonts (you already have it).
//   2. Save as lib/main_clean.dart and run with:
//        flutter run -t lib/main_clean.dart
//      (or paste over lib/main.dart)


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const StudySpotsCleanApp());
}

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------

abstract final class Tone {
  static const bg = Color(0xFFFFFFFF);
  static const ink = Color(0xFF101828); // near-black text
  static const muted = Color(0xFF667085); // secondary text
  static const line = Color(0xFFEAECF0); // hairline dividers
  static const field = Color(0xFFF2F4F7); // search field / chips

  // accent trio — used for small lines and illustration strokes
  static const teal = Color(0xFF0BA574);
  static const amber = Color(0xFFF5A623);
  static const coral = Color(0xFFF4633A);
}

/// Beli-style score banding: the bubble color tells you the tier.
Color scoreColor(double s) {
  if (s >= 9.0) return const Color(0xFF0BA574); // emerald
  if (s >= 8.0) return const Color(0xFF7CB342); // green
  if (s >= 7.0) return const Color(0xFFF5A623); // amber
  return const Color(0xFFF4633A); // coral
}

enum Level {
  good(Color(0xFF0BA574), 'Great'),
  ok(Color(0xFFF5A623), 'Okay'),
  rough(Color(0xFFF4633A), 'Rough');

  final Color color;
  final String display;
  const Level(this.color, this.display);
}

enum SpotType {
  cafe('Café', Icons.local_cafe, Color(0xFFFFE8D9), Color(0xFFF4633A)),
  library('Library', Icons.menu_book, Color(0xFFDDF3E8), Color(0xFF0BA574)),
  campus('Campus', Icons.school, Color(0xFFECE8FD), Color(0xFF7A5AF8));

  final String label;
  final IconData icon;
  final Color pastel; // circle background
  final Color accent; // icon color
  const SpotType(this.label, this.icon, this.pastel, this.accent);
}

// ---------------------------------------------------------------------------
// Model + sample data (same shape as concepts 1 & 2)
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
        (Icons.wifi, 'Wi-Fi', wifi),
        (Icons.event_seat, 'Seating', seating),
        (Icons.volume_up, 'Noise', noise),
        (Icons.local_cafe, 'Coffee', coffee),
        (Icons.bolt, 'Outlets', outlets),
      ];
}

// TODO: replace with ApiService.getSpots() once the .NET endpoint is wired up.
const _sampleSpots = <StudySpot>[
  StudySpot(
    name: "Lestat's Coffee House",
    type: SpotType.cafe,
    score: 9.4,
    distance: '4.6 mi',
    hours: 'Open 24 hrs',
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
    hours: 'Til 11 pm',
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
    hours: 'Til 10 pm',
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
    hours: 'Til 5 pm',
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
    hours: 'Til 9 pm',
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
    hours: 'Til 6 pm',
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
    hours: 'Til 7 pm',
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

class StudySpotsCleanApp extends StatelessWidget {
  const StudySpotsCleanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Spots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Tone.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: Tone.teal),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        splashColor: Tone.field,
        highlightColor: Tone.field,
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

  void _soon(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Tone.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spots = _visibleSpots;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 14),
                  _buildFilters(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 1, color: Tone.line),
            for (var i = 0; i < spots.length; i++) ...[
              SpotRow(rank: i + 1, spot: spots[i]),
              const Padding(
                padding: EdgeInsets.only(left: 20),
                child: Divider(height: 1, thickness: 1, color: Tone.line),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _soon('Add a spot — coming soon'),
        backgroundColor: Tone.ink,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const CleanBottomNav(),
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
                'Spots',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Tone.ink,
                ),
              ),
              const SizedBox(height: 6),
              // small tri-color accent line
              Row(
                children: [
                  for (final c in const [Tone.teal, Tone.amber, Tone.coral])
                    Container(
                      width: 16,
                      height: 3,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${_sampleSpots.length} spots · Point Loma',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Tone.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return InkWell(
      onTap: () => _soon('Search — coming soon'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Tone.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: Tone.muted),
            const SizedBox(width: 8),
            Text(
              'Search your spots',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Tone.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final options = <(String, SpotType?)>[
      ('All', null),
      for (final t in SpotType.values) (t.label, t),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (label, type) in options) ...[
            InkWell(
              onTap: () => setState(() => _filter = type),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _filter == type ? Tone.ink : Tone.field,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _filter == type ? Colors.white : Tone.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ranked row
// ---------------------------------------------------------------------------

class SpotRow extends StatelessWidget {
  final int rank;
  final StudySpot spot;

  const SpotRow({super.key, required this.rank, required this.spot});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => SpotDetailSheet(spot: spot),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Tone.muted,
                ),
              ),
            ),
            _CategoryCircle(type: spot.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Tone.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${spot.distance} · ${spot.hours}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Tone.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final (icon, label, level) in spot.amenities) ...[
                        Tooltip(
                          message: '$label: ${level.display}',
                          child: Icon(icon, size: 14, color: level.color),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ScoreBubble(score: spot.score),
          ],
        ),
      ),
    );
  }
}

class _CategoryCircle extends StatelessWidget {
  final SpotType type;

  const _CategoryCircle({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: type.pastel, shape: BoxShape.circle),
      child: Icon(type.icon, size: 20, color: type.accent),
    );
  }
}

class _ScoreBubble extends StatelessWidget {
  final double score;

  const _ScoreBubble({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scoreColor(score),
        shape: BoxShape.circle,
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spot detail bottom sheet
// ---------------------------------------------------------------------------

class SpotDetailSheet extends StatelessWidget {
  final StudySpot spot;

  const SpotDetailSheet({super.key, required this.spot});

  void _soon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Tone.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tone.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Tone.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _CategoryCircle(type: spot.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Tone.ink,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${spot.type.label} · ${spot.distance} · ${spot.hours}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Tone.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ScoreBubble(score: spot.score),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, thickness: 1, color: Tone.line),
              const SizedBox(height: 16),
              Text(
                'THE RUNDOWN',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Tone.muted,
                ),
              ),
              const SizedBox(height: 6),
              for (final (icon, label, level) in spot.amenities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(icon, size: 19, color: Tone.muted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Tone.ink,
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: level.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        level.display,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: level.color,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SheetButton(
                      label: 'Directions',
                      icon: Icons.near_me,
                      filled: true,
                      onTap: () => _soon(context, 'Directions — coming soon'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SheetButton(
                      label: 'Edit spot',
                      icon: Icons.edit_outlined,
                      filled: false,
                      onTap: () => _soon(context, 'Edit spot — coming soon'),
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
    final fg = filled ? Colors.white : Tone.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? Tone.ink : Tone.bg,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: Tone.line, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
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
// Bottom nav
// ---------------------------------------------------------------------------

class CleanBottomNav extends StatelessWidget {
  const CleanBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tone.bg,
        border: Border(top: BorderSide(color: Tone.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _NavItem(icon: Icons.place, label: 'Spots', active: true),
              _NavItem(icon: Icons.map_outlined, label: 'Map', active: false),
              _NavItem(
                  icon: Icons.person_outline, label: 'Profile', active: false),
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

  const _NavItem({
    required this.icon, 
    required this.label, 
    required this.active
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Tone.ink : const Color(0xFF98A2B3);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}