import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/services/auth_controller.dart';

/// Shown right after signUpWithEmail sends a verification link, and as the app's root
/// screen when AuthController.bootstrap() finds a cached, non-anonymous, still-unverified
/// password-provider session (AuthPhase.needsEmailVerification). Auto-polls Firebase in
/// the background so most people never have to tap anything — clicking the emailed link
/// is enough.
class VerifyEmailPage extends StatefulWidget {
  final AuthController auth;

  const VerifyEmailPage({super.key, required this.auth});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  Timer? _pollTimer;
  bool _checking = false;
  bool _resending = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // Background tick: silent unless it succeeds, so a slow inbox doesn't spam errors.
  Future<void> _poll() async {
    if (_checking) return;
    final verified = await widget.auth.checkVerification();
    if (!mounted || !verified) return;
    _pollTimer?.cancel();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _checkNow() async {
    setState(() {
      _checking = true;
      _error = null;
      _notice = null;
    });

    final verified = await widget.auth.checkVerification();
    if (!mounted) return;

    if (!verified) {
      setState(() {
        _checking = false;
        _error = "Still not verified — check your inbox (and spam folder), then try again.";
      });
      return;
    }

    _pollTimer?.cancel();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });

    try {
      await widget.auth.resendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _resending = false;
        _notice = 'Verification email sent.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = e.code == 'too-many-requests'
            ? 'Too many attempts — wait a moment and try again.'
            : e.message ?? 'Could not resend the email.';
      });
    }
  }

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;

    return PopScope(
      // No back button: a real (non-anonymous) Firebase credential already exists at
      // this point, so there's nowhere sensible to land on a back-press. "Sign out and
      // start over" below is the deliberate way out.
      canPop: false,
      child: Scaffold(
        backgroundColor: Tone.bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Icon(Icons.mark_email_unread_outlined, size: 64, color: Tone.terracotta),
                ),
                const SizedBox(height: 20),
                Text(
                  'Verify your email',
                  style: GoogleFonts.fraunces(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Tone.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email == null
                      ? "We sent you a verification link. Click it, then come back here."
                      : "We sent a verification link to $email. Click it, then come back here.",
                  style: GoogleFonts.fraunces(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Tone.muted,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _messageBox(_error!, Tone.error),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 16),
                  _messageBox(_notice!, Tone.sage),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _checking ? null : _checkNow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(color: Tone.ink, borderRadius: BorderRadius.circular(14)),
                      child: Center(
                        child: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                "I've verified — Continue",
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
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _resending ? null : _resend,
                    child: Text(
                      _resending ? 'Sending…' : "Resend link",
                      style: GoogleFonts.fraunces(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Tone.terracotta,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: _signOut,
                    child: Text(
                      'Sign out and start over',
                      style: GoogleFonts.fraunces(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Tone.muted,
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

  Widget _messageBox(String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            color == Tone.error ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.fraunces(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
