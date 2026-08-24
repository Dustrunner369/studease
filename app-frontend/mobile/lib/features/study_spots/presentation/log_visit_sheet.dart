import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/services/api_service.dart';

/// Logs "I'm studying here today" at [spotId]. Both fields are optional, so the save
/// button is always enabled — there's nothing to validate. Returns `true` on a
/// successful log, `null`/`false` otherwise.
Future<bool?> showLogVisitSheet(
  BuildContext context, {
  required String spotId,
  required String spotName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => LogVisitSheet(spotId: spotId, spotName: spotName),
  );
}

class LogVisitSheet extends StatefulWidget {
  final String spotId;
  final String spotName;

  const LogVisitSheet({super.key, required this.spotId, required this.spotName});

  @override
  State<LogVisitSheet> createState() => _LogVisitSheetState();
}

class _LogVisitSheetState extends State<LogVisitSheet> {
  final _studiedController = TextEditingController();
  final _drinkController = TextEditingController();

  bool _saving = false;
  String? _error;

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
      Navigator.of(context).pop(true);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                Text(
                  'Log a visit',
                  style: GoogleFonts.fraunces(fontSize: 21, fontWeight: FontWeight.w800, color: Tone.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.spotName,
                  style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tone.muted),
                ),
                const SizedBox(height: 22),
                _sectionLabel('WHAT DID YOU STUDY?'),
                const SizedBox(height: 8),
                _field(controller: _studiedController, hint: 'Organic chemistry'),
                const SizedBox(height: 16),
                _sectionLabel('WHAT DID YOU ORDER?'),
                const SizedBox(height: 8),
                _field(controller: _drinkController, hint: 'Vanilla latte'),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _errorBox(_error!),
                ],
                const SizedBox(height: 20),
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
            ),
          ),
        ),
      ),
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

  Widget _field({required TextEditingController controller, required String hint}) {
    return Container(
      decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
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
