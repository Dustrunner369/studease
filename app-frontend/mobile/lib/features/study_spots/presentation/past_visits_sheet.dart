import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/models/visit.dart';
import 'package:mobile/services/api_service.dart';

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
          _VisitRow(visit: visits[i]),
        ],
      ],
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
