import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_controller.dart';

/// Shown exactly once per account: right after a guest links a real credential, before
/// they've ever picked a handle. POST /me is what actually flips IsGuest server-side —
/// until this completes, the account is still capped like a guest.
class ChooseHandlePage extends StatefulWidget {
  final AuthController auth;

  const ChooseHandlePage({super.key, required this.auth});

  @override
  State<ChooseHandlePage> createState() => _ChooseHandlePageState();
}

class _ChooseHandlePageState extends State<ChooseHandlePage> {
  final _handleController = TextEditingController();
  final _nameController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _handleController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final handle = _handleController.text.trim().toLowerCase();
    final displayName = _nameController.text.trim();

    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(handle)) {
      setState(() => _error = 'Handle must be 3-30 characters: lowercase letters, numbers, underscores.');
      return;
    }

    if (displayName.isEmpty) {
      setState(() => _error = 'Enter a display name.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.auth.completeRegistration(handle: handle, displayName: displayName);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // No back button: an account without a handle can't use /me/spots or the entry
      // endpoints (RequireRegisteredFilter would 403 them) were this dismissible, and
      // there's nowhere sensible to land.
      canPop: false,
      child: Scaffold(
        backgroundColor: Tone.bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick a handle',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Tone.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "This is how people find you. Choose carefully — it's not easy to change later.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Tone.muted,
                  ),
                ),
                const SizedBox(height: 28),
                _label('HANDLE'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '@',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Tone.muted,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _handleController,
                          maxLength: 30,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]'))],
                          decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Tone.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _label('DISPLAY NAME'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Jamie Rivera',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: Tone.muted,
                      ),
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Tone.ink,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Tone.coral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: Tone.coral),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Tone.coral,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _submitting ? null : _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(color: Tone.ink, borderRadius: BorderRadius.circular(14)),
                      child: Center(
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Done',
                                style: GoogleFonts.plusJakartaSans(
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

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Tone.muted,
        ),
      );
}
