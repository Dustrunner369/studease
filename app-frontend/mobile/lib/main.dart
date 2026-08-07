import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/profile/presentation/profile_page.dart';
import 'package:mobile/features/study_spots/presentation/add_spot_sheet.dart';
import 'package:mobile/services/auth_controller.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/models/spot.dart';
import 'package:mobile/design/illustrations.dart';
import 'package:mobile/design/motion_widgets.dart';
import 'package:mobile/design/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final auth = AuthController();
  unawaited(auth.bootstrap());

  runApp(StudySpotApp(auth: auth));
}

class StudySpotApp extends StatelessWidget {
  final AuthController auth;

  const StudySpotApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Spots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Tone.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: Tone.terracotta),
        textTheme: GoogleFonts.frauncesTextTheme(),
        splashColor: Tone.field,
        highlightColor: Tone.field,
      ),
      // Nobody sees this stall for long: bootstrap signs a guest in anonymously before
      // fetching /me, so "loading" only ever covers that one round trip.
      home: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => switch (auth.phase) {
          AuthPhase.loading => const _BootSplash(),
          AuthPhase.error => _BootError(auth: auth),
          AuthPhase.ready => SpotsPage(auth: auth),
        },
      ),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tone.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The one wordmark moment in the app right now — outlier typeface,
            // used nowhere else. Placeholder script until a purchased font
            // replaces it; see AppText.wordmark.
            Text('Studease', style: AppText.wordmark()),
            const SizedBox(height: Space.lg),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Tone.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootError extends StatelessWidget {
  final AuthController auth;

  const _BootError({required this.auth});

  // Bootstrap fails two very different ways: Firebase itself rejecting the sign-in
  // (a console config problem, e.g. the Anonymous provider being disabled — nothing
  // to do with the API), or the API being unreachable once a token exists. Telling
  // them apart here saves someone debugging their backend for a Firebase console
  // setting, or vice versa.
  bool get _isAuthFailure => auth.error is FirebaseAuthException;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tone.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isAuthFailure ? Icons.lock_outline : Icons.cloud_off, size: 32, color: Tone.muted),
              const SizedBox(height: 12),
              Text(
                _isAuthFailure ? "Couldn't sign you in" : "Couldn't reach the server",
                style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w700, color: Tone.ink),
              ),
              const SizedBox(height: 4),
              Text(
                '${auth.error}',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fraunces(fontSize: 12.5, fontWeight: FontWeight.w500, color: Tone.muted),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: auth.bootstrap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(color: Tone.ink, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model → UI adapter
//
// The API sends each spot already joined to my rating of it, with the 0–10 score
// computed by Postgres. Nothing here recalculates it — this is only about turning
// those values into icons, labels and colours.
// ---------------------------------------------------------------------------

extension SpotPresentation on MySpotListItem {
  /// One-line summary for the list row.
  ///
  /// No opening hours: they'd cost a Places lookup per row, so the detail sheet
  /// fetches them instead.
  String get subtitle => [
        if (address != null && address!.isNotEmpty) address!,
        if (priceLevel != null && priceLevel! > 0) '\$' * priceLevel!,
      ].join(' · ');

  List<(IconData, String, Level)> get amenities => [
        (Icons.wifi, 'WiFi', levelFor(ratings.wifi)),
        (Icons.volume_off, 'Quiet', levelFor(ratings.noise)),
        (Icons.bolt, 'Outlets', levelFor(ratings.outlets)),
        (Icons.event_seat, 'Seating', levelFor(ratings.seating)),
        (Icons.table_restaurant, 'Tables', levelFor(ratings.tableSize)),
        (Icons.local_cafe, 'Coffee', levelFor(ratings.coffee)),
      ];

  /// Optional free-text fields, shown in the detail sheet when present.
  List<(IconData, String, String)> get details => [
        if (address != null && address!.isNotEmpty)
          (Icons.place_outlined, 'Address', address!),
        if (coffeeOrder != null) (Icons.coffee, 'Usual order', coffeeOrder!),
        if (notes != null) (Icons.notes, 'Notes', notes!),
      ];
}

// ---------------------------------------------------------------------------
// Spots page
// ---------------------------------------------------------------------------

class SpotsPage extends StatefulWidget {
  final AuthController auth;

  const SpotsPage({super.key, required this.auth});

  @override
  State<SpotsPage> createState() => _SpotsPageState();
}

class _SpotsPageState extends State<SpotsPage> {
  // Multi-select, AND semantics: a spot must carry every selected tag to show.
  final Set<String> _filterTags = {};

  // Held as a list rather than a Future so a row can be removed the instant it's
  // swiped away, without waiting for the server to confirm.
  List<MySpotListItem>? _spots;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      // Only blank the page on the first load — a pull-to-refresh keeps the list
      // on screen and shows its own spinner.
      _loading = _spots == null;
      _error = null;
    });

    try {
      final spots = await fetchMySpots();
      if (!mounted) return;
      setState(() {
        _spots = spots;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _addSpot() async {
    final saved = await showAddSpotSheet(context, widget.auth);
    if (saved == true && mounted) await _load();
  }

  Future<void> _deleteSpot(MySpotListItem spot) async {
    // Drop it from the list first: a Dismissible has to leave the tree as soon as
    // it's dismissed, and the undo below puts it back if asked.
    setState(() => _spots = [...?_spots]..removeWhere((s) => s.entryId == spot.entryId));

    try {
      await deleteEntry(spot.spotId);
    } catch (_) {
      if (!mounted) return;
      _soon('Could not remove ${spot.name}');
      await _load();
      return;
    }

    if (!mounted) return;
    _showUndo(spot);
  }

  /// Undo re-saves the same ratings. Deleting an entry leaves the spot itself
  /// alone, so this puts the rating back exactly where it was.
  void _showUndo(MySpotListItem spot) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Tone.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        content: Text(
          'Removed ${spot.name}',
          style: GoogleFonts.fraunces(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Tone.terracotta,
          onPressed: () => _restore(spot),
        ),
      ),
    );
  }

  Future<void> _restore(MySpotListItem spot) async {
    try {
      await saveEntry(
        spotId: spot.spotId,
        ratings: spot.ratings,
        groupStudy: spot.groupStudy,
        tagSlugs: spot.tags,
        coffeeOrder: spot.coffeeOrder,
        notes: spot.notes,
      );
    } catch (_) {
      if (!mounted) return;
      _soon('Could not restore ${spot.name}');
    }

    if (!mounted) return;
    await _load();
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
          style: GoogleFonts.fraunces(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spots = _spots;
    final visible = spots == null
        ? const <MySpotListItem>[]
        : (_filterTags.isEmpty
            ? spots
            : spots.where((s) => _filterTags.every(s.tags.contains)).toList());

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: Tone.ink,
          onRefresh: _load,
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
              ..._buildBody(visible),
            ],
          ),
        ),
      ),
      floatingActionButton: PressScale(
        onTap: _addSpot,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: Tone.terracotta, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      bottomNavigationBar: CleanBottomNav(currentIndex: 0, auth: widget.auth),
    );
  }

  List<Widget> _buildBody(List<MySpotListItem> visible) {
    if (_loading) {
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

    if (_error != null) {
      return [_ErrorBox(error: _error!, onRetry: _load)];
    }

    if (visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xl2),
          child: Center(
            child: Column(
              children: [
                const MokaPotSketch(size: 96, color: Tone.muted),
                const SizedBox(height: Space.md),
                Text(
                  _filterTags.isEmpty
                      ? 'No spots yet — tap + to add one'
                      : 'No spots tagged ${_filterTags.map((t) => '#$t').join(', ')}',
                  style: AppText.body(color: Tone.muted, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      for (var i = 0; i < visible.length; i++) ...[
        // Keyed by entry so dismissing one row doesn't take its neighbour's state
        // with it when the list closes up, and so RevealOnce only animates a row
        // that's genuinely new — not every row on a pull-to-refresh.
        RevealOnce(
          key: ValueKey('reveal-${visible[i].entryId}'),
          index: i,
          child: _DismissibleSpotRow(
            key: ValueKey(visible[i].entryId),
            rank: i + 1,
            spot: visible[i],
            onDismissed: () => _deleteSpot(visible[i]),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Divider(height: 1, thickness: 1, color: Tone.line),
        ),
      ],
    ];
  }

  Widget _buildHeader(int? count) {
    final countLabel = switch (count) {
      null => '',      
      1 => '1 spot',
      _ => '$count spots',
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
                style: GoogleFonts.fraunces(
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
                  for (final c in const [Tone.terracotta, Tone.slate, Tone.sage])
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
                style: GoogleFonts.fraunces(
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
              style: GoogleFonts.fraunces(
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

  // Options come from whatever tags are actually present on the loaded spots, not
  // the full global label list — a chip that would always show zero results isn't
  // worth offering.
  Widget _buildFilters() {
    final tags = {for (final s in _spots ?? const <MySpotListItem>[]) ...s.tags}.toList()
      ..sort();

    if (tags.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final tag in tags) ...[
            InkWell(
              onTap: () => setState(() {
                if (!_filterTags.remove(tag)) _filterTags.add(tag);
              }),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _filterTags.contains(tag) ? Tone.ink : Tone.field,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#$tag',
                  style: GoogleFonts.fraunces(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _filterTags.contains(tag) ? Colors.white : Tone.ink,
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
            style: GoogleFonts.fraunces(
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
            style: GoogleFonts.fraunces(
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
                style: GoogleFonts.fraunces(
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

/// Wraps a row so it can be swiped away. Deleting removes only *my* rating —
/// the place itself stays, which is what makes Undo a simple re-save.
class _DismissibleSpotRow extends StatelessWidget {
  final int rank;
  final MySpotListItem spot;
  final VoidCallback onDismissed;

  const _DismissibleSpotRow({
    super.key,
    required this.rank,
    required this.spot,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${spot.entryId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        color: Tone.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: SpotRow(rank: rank, spot: spot),
    );
  }
}

class SpotRow extends StatelessWidget {
  final int rank;
  final MySpotListItem spot;

  const SpotRow({super.key, required this.rank, required this.spot});

  @override
  Widget build(BuildContext context) {
    return PressScale(
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
                style: GoogleFonts.fraunces(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Tone.muted,
                ),
              ),
            ),
            const _CategoryCircle(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fraunces(
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
                    style: GoogleFonts.fraunces(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Tone.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Wrap, not Row: six rating icons plus the group marker overflow a
                  // fixed row once the name column narrows on a 320px screen.
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final (icon, label, level) in spot.amenities)
                        Tooltip(
                          message: '$label: ${level.display}',
                          child: Icon(icon, size: 14, color: level.color),
                        ),
                      if (spot.groupStudy)
                        const Tooltip(
                          message: 'Good for group study',
                          child: Icon(Icons.groups, size: 14, color: Tone.sage),
                        ),
                    ],
                  ),
                  if (spot.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _TagPills(tags: spot.tags),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ScoreBubble(score: spot.score, heroTag: 'score-${spot.entryId}'),
          ],
        ),
      ),
    );
  }
}

// Every row gets the same neutral glyph now — spots no longer have a single category
// to color-code by, since a spot's tags are optional and multi-valued (see the
// label/tag system replacing SpotType). A visible step down from the old per-category
// icon+color, accepted as the mechanical trade for this pass; tags render as pills
// below the name instead, not a leading glyph.
class _CategoryCircle extends StatelessWidget {
  const _CategoryCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(color: Tone.field, shape: BoxShape.circle),
      child: const Icon(Icons.place, size: 20, color: Tone.muted),
    );
  }
}

/// A non-interactive `#slug` pill row — the row/detail-sheet display counterpart to
/// the tappable filter chips in `_buildFilters` and the tappable picker chips in
/// add_spot_sheet.dart. Same visual language, different behavior.
class _TagPills extends StatelessWidget {
  final List<String> tags;

  const _TagPills({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Tone.field,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '#$tag',
              style: GoogleFonts.fraunces(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Tone.ink,
              ),
            ),
          ),
      ],
    );
  }
}

class _ScoreBubble extends StatelessWidget {
  final double score;

  /// When set, this bubble is a Hero endpoint — pass the same tag on the row and
  /// the detail sheet (`'score-$entryId'`) and Flutter flies the bubble between
  /// them on navigation instead of the sheet just appearing. Null renders a plain
  /// bubble with no flight (used nowhere twice at once, so no tag collision risk).
  final String? heroTag;

  const _ScoreBubble({required this.score, this.heroTag});

  @override
  Widget build(BuildContext context) {
    // AnimatedContainer, not Container: if a spot's score changes (re-rated),
    // the fill color crossfades instead of snapping.
    final bubble = AnimatedContainer(
      duration: Motion.short,
      curve: Motion.easeInOut,
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scoreColor(score),
        shape: BoxShape.circle,
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: AppText.bodySm(color: Colors.white, weight: FontWeight.w800),
      ),
    );

    return heroTag == null ? bubble : Hero(tag: heroTag!, child: bubble);
  }
}

// ---------------------------------------------------------------------------
// Spot detail bottom sheet
// ---------------------------------------------------------------------------

class SpotDetailSheet extends StatelessWidget {
  final MySpotListItem spot;

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
          style: GoogleFonts.fraunces(
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
                    const _CategoryCircle(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spot.name,
                            style: GoogleFonts.fraunces(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Tone.ink,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _HoursLine(spot: spot),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ScoreBubble(score: spot.score, heroTag: 'score-${spot.entryId}'),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, thickness: 1, color: Tone.line),
                const SizedBox(height: 16),
                Text(
                  'THE RUNDOWN',
                  style: GoogleFonts.fraunces(
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
                            style: GoogleFonts.fraunces(
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
                          style: GoogleFonts.fraunces(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: level.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Sits with the ratings but renders differently on purpose — it's a
                // yes/no, so it gets no 1-5 dot and no Level colour ramp.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.groups, size: 19, color: Tone.muted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Group study',
                          style: GoogleFonts.fraunces(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Tone.ink,
                          ),
                        ),
                      ),
                      Text(
                        spot.groupStudy ? 'Works' : 'Not really',
                        style: GoogleFonts.fraunces(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: spot.groupStudy ? Tone.sage : Tone.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (spot.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'TAGS',
                    style: GoogleFonts.fraunces(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Tone.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // My own tags, not the spot-wide aggregate — everyone's opinion
                  // would need a second request (SpotDetail, not MySpotListItem).
                  _TagPills(tags: spot.tags),
                ],
                if (spot.details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'DETAILS',
                    style: GoogleFonts.fraunces(
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
                                  style: GoogleFonts.fraunces(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Tone.muted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  value,
                                  style: GoogleFonts.fraunces(
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

/// Opening hours are never stored — they're fetched from Google when the sheet
/// opens. So this renders the category immediately and fills in "Until 22:00" if
/// and when the lookup lands, staying quiet when Google has no hours to give.
class _HoursLine extends StatefulWidget {
  final MySpotListItem spot;

  const _HoursLine({required this.spot});

  @override
  State<_HoursLine> createState() => _HoursLineState();
}

class _HoursLineState extends State<_HoursLine> {
  String? _openUntil;

  @override
  void initState() {
    super.initState();
    _loadHours();
  }

  Future<void> _loadHours() async {
    try {
      final detail = await fetchSpot(widget.spot.spotId);
      if (!mounted) return;
      setState(() => _openUntil = detail.openUntil);
    } catch (_) {
      // Hours are a nicety, not the point of the sheet — a failed lookup just
      // leaves this line blank rather than showing a stale category label.
    }
  }

  @override
  Widget build(BuildContext context) {
    // No category label to fall back on since SpotType was removed — this line is
    // only ever hours now, and says nothing at all until the lookup lands.
    if (_openUntil == null) return const SizedBox.shrink();

    return Text(
      'Until $_openUntil',
      style: GoogleFonts.fraunces(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: Tone.muted,
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
              style: GoogleFonts.fraunces(
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

/// Each tab is its own full Scaffold rather than one shared shell — see SpotsPage,
/// _MapComingSoonPage, and ProfilePage — so switching tabs is a plain
/// pushReplacement rather than an IndexedStack. Smallest thing that works without
/// go_router or lifting SpotsPage's FAB/list state up into a shell; see
/// context/auth-plan.md on deferring routing changes.
class CleanBottomNav extends StatelessWidget {
  final int currentIndex;
  final AuthController auth;

  const CleanBottomNav({super.key, required this.currentIndex, required this.auth});

  void _select(BuildContext context, int index) {
    if (index == currentIndex) return;

    final page = switch (index) {
      0 => SpotsPage(auth: auth),
      1 => _MapComingSoonPage(auth: auth),
      _ => ProfilePage(auth: auth),
    };

    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

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
            children: [
              _NavItem(
                icon: Icons.place,
                label: 'Spots',
                active: currentIndex == 0,
                onTap: () => _select(context, 0),
              ),
              _NavItem(
                icon: Icons.map_outlined,
                label: 'Map',
                active: currentIndex == 1,
                onTap: () => _select(context, 1),
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                active: currentIndex == 2,
                onTap: () => _select(context, 2),
              ),
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Tone.ink : const Color(0xFF98A2B3);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.fraunces(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapComingSoonPage extends StatelessWidget {
  final AuthController auth;

  const _MapComingSoonPage({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            'Map — coming soon',
            style: GoogleFonts.fraunces(fontSize: 14, fontWeight: FontWeight.w600, color: Tone.muted),
          ),
        ),
      ),
      bottomNavigationBar: CleanBottomNav(currentIndex: 1, auth: auth),
    );
  }
}