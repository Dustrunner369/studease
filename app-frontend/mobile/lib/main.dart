// STUDY SPOTS — neubrutalist "Spots" page
//
// Setup:
//   1. In pubspec.yaml, add:
//        dependencies:
//          google_fonts: ^6.2.1
//   2. flutter pub get
//   3. Replace lib/main.dart with this file and run.
//      (google_fonts downloads Archivo Black + Space Grotesk on first
//       launch, so the device/emulator needs internet once.)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const StudySpotsApp());
}

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------

abstract final class Neo {
  static const ink = Color(0xFF17151F); // borders, text, shadows
  static const paper = Color(0xFFE7E1F5); // lavender background
  static const card = Color(0xFFFFFCF4); // warm white cards
  static const yellow = Color(0xFFFFD230); // primary accent
  static const coral = Color(0xFFFF7A5C); // "top spot" tape
  static const muted = Color(0xFF8A85A0); // secondary text
}

/// How good an amenity is. The color IS the rating.
enum Level {
  good(Color(0xFF97E06E)),
  ok(Color(0xFFFFDE59)),
  rough(Color(0xFFFF9C8C));

  final Color color;
  const Level(this.color);
}

enum SpotType {
  cafe('CAFÉ', Color(0xFFFFC1E0)),
  library('LIBRARY', Color(0xFFB5D8FF)),
  campus('CAMPUS', Color(0xFFFFC97A));

  final String label;
  final Color color;
  const SpotType(this.label, this.color);
}

// ---------------------------------------------------------------------------
// Model + sample data
// ---------------------------------------------------------------------------

class StudySpot {
  final String name;
  final SpotType type;
  final double score; // Beli-style 0–10
  final String distance;
  final String hours;
  final Level wifi;
  final Level seating;
  final Level noise; // green = quiet enough to focus
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
    distance: '4.6 MI',
    hours: 'OPEN 24 HRS',
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
    distance: '0.2 MI',
    hours: 'TIL 11 PM',
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
    distance: '0.1 MI',
    hours: 'TIL 10 PM',
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
    distance: '5.1 MI',
    hours: 'TIL 5 PM',
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
    distance: '3.4 MI',
    hours: 'TIL 9 PM',
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
    distance: '1.2 MI',
    hours: 'TIL 6 PM',
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
    distance: '1.8 MI',
    hours: 'TIL 7 PM',
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

class StudySpotsApp extends StatelessWidget {
  const StudySpotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Spots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Neo.paper,
        colorScheme: ColorScheme.fromSeed(seedColor: Neo.yellow),
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
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
  SpotType? _filter; // null = all

  List<StudySpot> get _visibleSpots {
    final spots =
        _sampleSpots.where((s) => _filter == null || s.type == _filter).toList();
    spots.sort((a, b) => b.score.compareTo(a.score));
    return spots;
  }

  void _notYet(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Neo.yellow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Neo.ink, width: 2.5),
        ),
        content: Text(
          message,
          style: GoogleFonts.spaceGrotesk(
            color: Neo.ink,
            fontWeight: FontWeight.w700,
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
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildFilters(),
            const SizedBox(height: 10),
            _buildLegend(),
            const SizedBox(height: 18),
            for (var i = 0; i < spots.length; i++) ...[
              SpotCard(spot: spots[i], index: i, isTop: _filter == null && i == 0),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
      floatingActionButton: NeoPressable(
        color: Neo.yellow,
        borderRadius: 16,
        shadowOffset: const Offset(4, 4),
        onTap: () => _notYet('Add a spot — coming soon'),
        child: const SizedBox(
          width: 58,
          height: 58,
          child: Icon(Icons.add, size: 30, color: Neo.ink),
        ),
      ),
      bottomNavigationBar: const NeoBottomNav(),
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
                '${_sampleSpots.length} SPOTS SAVED',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Neo.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'STUDY SPOTS',
                style: GoogleFonts.archivoBlack(
                  fontSize: 30,
                  color: Neo.ink,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        NeoPressable(
          borderRadius: 12,
          borderWidth: 2.5,
          shadowOffset: const Offset(3, 3),
          onTap: () => _notYet('Search — coming soon'),
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.search, color: Neo.ink),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final options = <(String, SpotType?)>[
      ('ALL', null),
      for (final t in SpotType.values) (t.label, t),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (label, type) in options) ...[
            NeoPressable(
              color: _filter == type ? Neo.yellow : Neo.card,
              borderRadius: 30,
              borderWidth: 2.5,
              shadowOffset: const Offset(3, 3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () => setState(() => _filter = type),
              child: Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Neo.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend() {
    Widget swatch(Level level, String label) => Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: level.color,
                border: Border.all(color: Neo.ink, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Neo.muted,
              ),
            ),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        swatch(Level.good, 'GOOD'),
        const SizedBox(width: 10),
        swatch(Level.ok, 'OK'),
        const SizedBox(width: 10),
        swatch(Level.rough, 'ROUGH'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Spot card
// ---------------------------------------------------------------------------

class SpotCard extends StatelessWidget {
  final StudySpot spot;
  final int index;
  final bool isTop;

  const SpotCard({
    super.key,
    required this.spot,
    required this.index,
    required this.isTop,
  });

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SpotDetailSheet(spot: spot),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        NeoPressable(
          padding: const EdgeInsets.all(14),
          onTap: () => _showDetail(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScoreBadge(score: spot.score, index: index),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Neo.ink,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TypeTag(type: spot.type),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${spot.distance} • ${spot.hours}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: Neo.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (icon, label, level) in spot.amenities)
                          AmenityTile(icon: icon, label: label, level: level),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isTop)
          Positioned(
            top: -10,
            right: 14,
            child: Transform.rotate(
              angle: 0.05,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Neo.coral,
                  border: Border.all(color: Neo.ink, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '★ TOP SPOT',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Neo.ink,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ScoreBadge extends StatelessWidget {
  final double score;
  final int index;

  const ScoreBadge({super.key, required this.score, required this.index});

  @override
  Widget build(BuildContext context) {
    // Alternate the sticker tilt down the list.
    final angle = index.isEven ? -0.09 : 0.07;

    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Neo.yellow,
          border: Border.all(color: Neo.ink, width: 3),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Neo.ink, offset: Offset(3, 3))],
        ),
        child: Text(
          score.toStringAsFixed(1),
          style: GoogleFonts.archivoBlack(fontSize: 16, color: Neo.ink),
        ),
      ),
    );
  }
}

class TypeTag extends StatelessWidget {
  final SpotType type;

  const TypeTag({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: type.color,
        border: Border.all(color: Neo.ink, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Neo.ink,
        ),
      ),
    );
  }
}

class AmenityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Level level;

  const AmenityTile({
    super.key,
    required this.icon,
    required this.label,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label: ${level.name.toUpperCase()}',
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: level.color,
          border: Border.all(color: Neo.ink, width: 2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 18, color: Neo.ink),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav
// ---------------------------------------------------------------------------

class NeoBottomNav extends StatelessWidget {
  const NeoBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Neo.card,
        border: Border(top: BorderSide(color: Neo.ink, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _NavItem(icon: Icons.place, label: 'SPOTS', active: true),
              _NavItem(icon: Icons.map, label: 'MAP', active: false),
              _NavItem(icon: Icons.person, label: 'ME', active: false),
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

  const _NavItem({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Neo.ink : Neo.muted;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ],
    );

    if (!active) return content;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Neo.yellow,
        border: Border.all(color: Neo.ink, width: 2.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// NeoPressable — bordered container with a hard shadow that collapses on press
// ---------------------------------------------------------------------------

class NeoPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double borderRadius;
  final double borderWidth;
  final Offset shadowOffset;
  final EdgeInsets padding;

  const NeoPressable({
    super.key,
    required this.child,
    this.onTap,
    this.color = Neo.card,
    this.borderRadius = 16,
    this.borderWidth = 3,
    this.shadowOffset = const Offset(5, 5),
    this.padding = EdgeInsets.zero,
  });

  @override
  State<NeoPressable> createState() => _NeoPressableState();
}

class _NeoPressableState extends State<NeoPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          _down ? widget.shadowOffset.dx : 0,
          _down ? widget.shadowOffset.dy : 0,
          0,
        ),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: Neo.ink, width: widget.borderWidth),
          boxShadow: _down
              ? const []
              : [BoxShadow(color: Neo.ink, offset: widget.shadowOffset)],
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spot detail bottom sheet
// ---------------------------------------------------------------------------

void showNeoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Neo.yellow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Neo.ink, width: 2.5),
      ),
      content: Text(
        message,
        style: GoogleFonts.spaceGrotesk(
          color: Neo.ink,
          fontWeight: FontWeight.w700,
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
        color: Neo.card,
        border: Border.all(color: Neo.ink, width: 3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Neo.ink,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScoreBadge(score: spot.score, index: 0),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Neo.ink,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            TypeTag(type: spot.type),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${spot.distance} • ${spot.hours}',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: Neo.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'THE RUNDOWN',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Neo.muted,
                ),
              ),
              const SizedBox(height: 8),
              for (final (icon, label, level) in spot.amenities)
                _AmenityRow(icon: icon, label: label, level: level),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SheetButton(
                      label: 'DIRECTIONS',
                      icon: Icons.near_me,
                      color: Neo.yellow,
                      onTap: () =>
                          showNeoSnack(context, 'Directions — coming soon'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SheetButton(
                      label: 'EDIT SPOT',
                      icon: Icons.edit,
                      color: Neo.card,
                      onTap: () =>
                          showNeoSnack(context, 'Edit spot — coming soon'),
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

class _AmenityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Level level;

  const _AmenityRow({
    required this.icon,
    required this.label,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AmenityTile(icon: icon, label: label, level: level),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Neo.ink,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: level.color,
              border: Border.all(color: Neo.ink, width: 2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              level.name.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Neo.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeoPressable(
      color: color,
      borderRadius: 12,
      borderWidth: 2.5,
      shadowOffset: const Offset(3, 3),
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Neo.ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Neo.ink,
            ),
          ),
        ],
      ),
    );
  }
}