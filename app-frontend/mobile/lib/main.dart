import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/models/studyspot.dart';
import 'package:mobile/design/theme.dart';

void main() {
  runApp(const StudySpotApp());
}

class StudySpotApp extends StatelessWidget {
  const StudySpotApp({super.key});

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
// Model → UI adapter
//
// The API model (studyspot.dart) doesn't carry UI concepts like score, type,
// or amenity levels, so they're derived here.
//
// ASSUMPTION: `seating` and `coffeeQuality` are 1–5 ratings. If your backend
// uses a different scale, adjust _levelFor and `score` — everything else
// reads through this extension.
// ---------------------------------------------------------------------------

Level _levelFor(int rating) {
  if (rating >= 4) return Level.good;
  if (rating >= 3) return Level.ok;
  return Level.rough;
}

extension SpotPresentation on StudySpot {
  String get displayName => name ?? 'Unnamed spot';

  /// The backend has no `type` field yet, so every spot renders as a café.
  SpotType get type => SpotType.cafe;

  /// One-line summary for the list row.
  String get subtitle => [
        if (address != null) address!,
        'Until $openUntil',
      ].join(' · ');

  /// 0–10: two 1–5 ratings summed, plus a half point for charging.
  double get score {
    final base = (seating + coffeeQuality).toDouble();
    final bonus = hasCharging ? 0.5 : 0.0;
    return (base + bonus).clamp(0.0, 10.0).toDouble();
  }

  List<(IconData, String, Level)> get amenities => [
        (Icons.bolt, 'Charging', hasCharging ? Level.good : Level.rough),
        (Icons.event_seat, 'Seating', _levelFor(seating)),
        (Icons.local_cafe, 'Coffee', _levelFor(coffeeQuality)),
      ];

  /// Optional free-text fields, shown in the detail sheet when present.
  List<(IconData, String, String)> get details => [
        if (address != null) (Icons.place_outlined, 'Address', address!),
        if (generalPrice != null) (Icons.attach_money, 'Price', generalPrice!),
        if (drinkOrder != null) (Icons.coffee, 'Usual order', drinkOrder!),
        if (extraNotes != null) (Icons.notes, 'Notes', extraNotes!),
      ];
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
  late Future<List<StudySpot>> _studySpots;

  @override
  void initState() {
    super.initState();
    _studySpots = fetchStudySpots();
  }

  Future<void> _reload() {
    final next = fetchStudySpots();
    setState(() {
      _studySpots = next;
    });
    // Swallow the error here; FutureBuilder surfaces it in the UI.
    return next.then<void>((_) {}).catchError((_) {});
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
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<StudySpot>>(
          future: _studySpots,
          builder: (context, snapshot) {
            final spots = snapshot.data;
            final visible = spots == null
                ? const <StudySpot>[]
                : (_filter == null
                    ? spots
                    : spots.where((s) => s.type == _filter).toList());

            return RefreshIndicator(
              color: Tone.ink,
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(spots?.length),
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                        const SizedBox(height: 14),
                        _buildFilters(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 1, color: Tone.line),
                  ..._buildBody(snapshot, visible),
                ],
              ),
            );
          },
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

  List<Widget> _buildBody(
    AsyncSnapshot<List<StudySpot>> snapshot,
    List<StudySpot> visible,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Tone.ink,
              ),
            ),
          ),
        ),
      ];
    }

    if (snapshot.hasError) {
      return [_ErrorBox(error: snapshot.error!, onRetry: _reload)];
    }

    if (visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: Text(
              _filter == null
                  ? 'No spots yet'
                  : 'No ${_filter!.label.toLowerCase()} spots',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Tone.muted,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      for (var i = 0; i < visible.length; i++) ...[
        SpotRow(rank: i + 1, spot: visible[i]),
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Divider(height: 1, thickness: 1, color: Tone.line),
        ),
      ],
    ];
  }

  Widget _buildHeader(int? count) {
    final countLabel = switch (count) {
      null => 'Point Loma',
      1 => '1 spot · Point Loma',
      _ => '$count spots · Point Loma',
    };

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
                countLabel,
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
// Error state
// ---------------------------------------------------------------------------

class _ErrorBox extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 32, color: Tone.muted),
          const SizedBox(height: 12),
          Text(
            "Couldn't load spots",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Tone.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$error',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Tone.muted,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: Tone.ink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
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
                    spot.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Tone.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spot.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                            spot.displayName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Tone.ink,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${spot.type.label} · Until ${spot.openUntil}',
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
                if (spot.details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'DETAILS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Tone.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final (icon, label, value) in spot.details)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 19, color: Tone.muted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Tone.muted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  value,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: Tone.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SheetButton(
                        label: 'Directions',
                        icon: Icons.near_me,
                        filled: true,
                        onTap: () =>
                            _soon(context, 'Directions — coming soon'),
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
    required this.active,
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