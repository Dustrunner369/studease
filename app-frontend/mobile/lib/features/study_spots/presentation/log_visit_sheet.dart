import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/celebrations.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/services/api_service.dart';

const _studiedMaxLength = 200;
const _drinkMaxLength = 60;

/// Opens as a centered card rather than a bottom sheet — logging a visit is a
/// deliberate, journal-like moment, not routine editing. Both fields are
/// optional, so the save button is always enabled — there's nothing to
/// validate. Returns `true` on a successful log, `null`/`false` otherwise.
Future<bool?> showLogVisitDialog(
  BuildContext context, {
  required String spotId,
  required String spotName,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierLabel: 'Log a visit',
    barrierColor: Colors.black54,
    barrierDismissible: true,
    transitionDuration: Motion.short,
    pageBuilder: (context, animation, secondaryAnimation) =>
        LogVisitDialog(spotId: spotId, spotName: spotName),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class LogVisitDialog extends StatefulWidget {
  final String spotId;
  final String spotName;

  const LogVisitDialog({super.key, required this.spotId, required this.spotName});

  @override
  State<LogVisitDialog> createState() => _LogVisitDialogState();
}

class _LogVisitDialogState extends State<LogVisitDialog> {
  final _studiedController = TextEditingController();
  final _drinkController = TextEditingController();

  bool _saving = false;
  String? _error;
  bool _showCelebration = false;

  @override
  void dispose() {
    _studiedController.dispose();
    _drinkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await logVisit(
        spotId: widget.spotId,
        studied: _trimmedOrNull(_studiedController),
        drinkOrder: _trimmedOrNull(_drinkController),
      );

      if (!mounted) return;
      // The celebration card pops the dialog itself once it's played out.
      setState(() => _showCelebration = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  static String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: MediaQuery.of(context).viewInsets +
          const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Tone.bg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                child: _showCelebration ? _buildCelebration() : _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebration() {
    return VisitLoggedCard(
      spotName: widget.spotName,
      onDone: () => Navigator.of(context).pop(true),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Log a visit',
                style: GoogleFonts.fraunces(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Tone.ink,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Tone.muted, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          widget.spotName,
          style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tone.muted),
        ),
        const SizedBox(height: 22),
        _sectionLabel('WHAT DID YOU STUDY?'),
        const SizedBox(height: 8),
        _bigField(),
        const SizedBox(height: 18),
        _sectionLabel('WHAT DID YOU ORDER?'),
        const SizedBox(height: 8),
        _smallField(),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _errorBox(_error!),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(color: Tone.ink, borderRadius: BorderRadius.circular(14)),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Log visit',
                        style: GoogleFonts.fraunces(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.fraunces(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Tone.muted,
        ),
      );

  // The primary write space — sized and weighted like the thing you actually
  // came here to say, not just another form field.
  Widget _bigField() {
    return Container(
      decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: TextField(
        controller: _studiedController,
        minLines: 3,
        maxLines: 6,
        maxLength: _studiedMaxLength,
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: 'Organic chemistry, chapter 4 problem set...',
          hintStyle: GoogleFonts.fraunces(
            fontSize: 16.5,
            fontWeight: FontWeight.w500,
            color: Tone.muted,
            height: 1.4,
          ),
        ),
        style: GoogleFonts.fraunces(fontSize: 16.5, fontWeight: FontWeight.w600, color: Tone.ink, height: 1.4),
      ),
    );
  }

  Widget _smallField() {
    return Container(
      decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: _drinkController,
        maxLength: _drinkMaxLength,
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: 'Vanilla latte',
          hintStyle: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w500, color: Tone.muted),
        ),
        style: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w600, color: Tone.ink),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tone.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Tone.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.fraunces(fontSize: 13, fontWeight: FontWeight.w600, color: Tone.error),
            ),
          ),
        ],
      ),
    );
  }
}
