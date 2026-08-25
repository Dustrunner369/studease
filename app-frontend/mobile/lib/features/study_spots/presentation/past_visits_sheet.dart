import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/models/visit.dart';
import 'package:mobile/services/api_service.dart';

const _deleteActionWidth = 76.0;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatVisitDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

/// My past visits to [spotId], newest first.
Future<void> showPastVisitsSheet(
  BuildContext context, {
  required String spotId,
  required String spotName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PastVisitsSheet(spotId: spotId, spotName: spotName),
  );
}

class PastVisitsSheet extends StatefulWidget {
  final String spotId;
  final String spotName;

  const PastVisitsSheet({super.key, required this.spotId, required this.spotName});

  @override
  State<PastVisitsSheet> createState() => _PastVisitsSheetState();
}

class _PastVisitsSheetState extends State<PastVisitsSheet> {
  List<Visit>? _visits;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final visits = await fetchSpotVisits(widget.spotId);
      if (!mounted) return;
      setState(() => _visits = visits);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  // Split from the actual removal below: the row plays its own collapse/fade
  // animation after this succeeds, then calls back to drop itself from the list —
  // an instant setState here would cut that animation off before it's seen.
  Future<void> _deleteVisit(String visitId) =>
      deleteVisit(spotId: widget.spotId, visitId: visitId);

  void _removeVisit(String visitId) {
    setState(() => _visits = [...?_visits]..removeWhere((v) => v.id == visitId));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tone.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                    decoration: BoxDecoration(color: Tone.line, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Past visits',
                  style: GoogleFonts.fraunces(fontSize: 21, fontWeight: FontWeight.w800, color: Tone.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.spotName,
                  style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tone.muted),
                ),
                const SizedBox(height: 20),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Text(
        _error!,
        style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tone.error),
      );
    }

    final visits = _visits;
    if (visits == null) {
      return const Center(child: CircularProgressIndicator(color: Tone.ink));
    }

    if (visits.isEmpty) {
      return Text(
        'No visits logged yet — log one above.',
        style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w500, color: Tone.muted),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < visits.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: Tone.line),
          _SwipeToDeleteRow(
            key: ValueKey(visits[i].id),
            onDelete: () => _deleteVisit(visits[i].id),
            onDeleted: () => _removeVisit(visits[i].id),
            child: _VisitRow(visit: visits[i]),
          ),
        ],
      ],
    );
  }
}

/// Swipe left to reveal a pinned delete button, tap it to remove — the
/// iMessage row-action pattern, not a full swipe-to-dismiss: the row only
/// leaves the list once the button is actually tapped and the delete
/// succeeds, and swiping back (or tapping the row again) closes it with
/// nothing removed. On success, collapses its own height and fades out
/// before calling [onDeleted] — the list closes the gap smoothly instead of
/// the row just blinking out of existence.
class _SwipeToDeleteRow extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onDelete;
  final VoidCallback onDeleted;

  const _SwipeToDeleteRow({
    super.key,
    required this.child,
    required this.onDelete,
    required this.onDeleted,
  });

  @override
  State<_SwipeToDeleteRow> createState() => _SwipeToDeleteRowState();
}

class _SwipeToDeleteRowState extends State<_SwipeToDeleteRow> with TickerProviderStateMixin {
  late final AnimationController _swipeController;
  late final AnimationController _exitController;
  late final Animation<double> _exitFactor;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(vsync: this, duration: Motion.short);
    _exitController = AnimationController(vsync: this, duration: Motion.short);
    _exitFactor = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitController, curve: Motion.easeIn));
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final current = -_deleteActionWidth * _swipeController.value;
    final next = (current + details.delta.dx).clamp(-_deleteActionWidth, 0.0);
    _swipeController.value = -next / _deleteActionWidth;
  }

  void _onDragEnd(DragEndDetails details) {
    final fastFling = (details.primaryVelocity ?? 0) < -300;
    final pastThreshold = _swipeController.value > 0.4;
    _swipeController.animateTo(fastFling || pastThreshold ? 1.0 : 0.0, curve: Motion.easeOut);
  }

  Future<void> _handleDelete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _swipeController.animateTo(0, curve: Motion.easeOut);
      return;
    }

    if (!mounted) return;
    await _exitController.forward();
    if (!mounted) return;
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _exitFactor,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _exitFactor,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _swipeController,
            builder: (context, _) {
              final extent = -_deleteActionWidth * _swipeController.value;
              return Stack(
                children: [
                  // Positioned.fill (not a raw Stack child) so this layer takes its size
                  // from the Stack's resolved size — which itself comes from the
                  // foreground row below, not from this button.
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: _deleteActionWidth,
                        height: double.infinity,
                        child: GestureDetector(
                          onTap: _busy ? null : _handleDelete,
                          child: Container(
                            color: Tone.error,
                            alignment: Alignment.center,
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Transform wraps the GestureDetector (not the other way around) so the
                  // tappable/draggable region actually moves with the slide — otherwise the
                  // detector's hit box stays at the full, untranslated row bounds and
                  // swallows taps on the delete button once it's revealed underneath.
                  Transform.translate(
                    offset: Offset(extent, 0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      onTap: extent < -1
                          ? () => _swipeController.animateTo(0, curve: Motion.easeOut)
                          : null,
                      child: ColoredBox(color: Tone.bg, child: widget.child),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  final Visit visit;

  const _VisitRow({required this.visit});

  @override
  Widget build(BuildContext context) {
    final studied = visit.studied;
    final drinkOrder = visit.drinkOrder;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              formatVisitDate(visit.visitedAt),
              style: GoogleFonts.fraunces(fontSize: 13, fontWeight: FontWeight.w700, color: Tone.terracotta),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: studied == null && drinkOrder == null
                ? Text(
                    'Studied here',
                    style: GoogleFonts.fraunces(fontSize: 14, fontWeight: FontWeight.w600, color: Tone.muted),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (studied != null)
                        Text(
                          studied,
                          style: GoogleFonts.fraunces(fontSize: 14, fontWeight: FontWeight.w600, color: Tone.ink),
                        ),
                      if (drinkOrder != null) ...[
                        if (studied != null) const SizedBox(height: 4),
                        Text(
                          drinkOrder,
                          style: GoogleFonts.fraunces(fontSize: 14, fontWeight: FontWeight.w600, color: Tone.ink),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
