import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/illustrations.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/features/authentication/presentation/choose_handle_page.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_controller.dart';

enum _Mode { signUp, signIn }

/// Email/password sign-up and sign-in. No Google button yet — see context/auth-plan.md
/// Phase 4.
///
/// Sign-up *links* the guest's current anonymous session (see AuthController), so
/// whatever they've already added carries over. If that email turns out to already have
/// an account, this switches to sign-in mode with an explanation rather than guessing —
/// the password just typed may not belong to that other account.
class LoginPage extends StatefulWidget {
  final AuthController auth;
  final bool startInSignUp;

  const LoginPage({super.key, required this.auth, this.startInSignUp = true});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late _Mode _mode = widget.startInSignUp ? _Mode.signUp : _Mode.signIn;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isSignUp => _mode == _Mode.signUp;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter an email and password.');
      return;
    }

    if (_isSignUp && password != _confirmController.text) {
      setState(() => _error = "Passwords don't match.");
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await widget.auth.signUpWithEmail(email, password);
      } else {
        await widget.auth.signInWithEmail(email, password);
      }

      if (!mounted) return;

      if (_isSignUp && widget.auth.me!.isGuest) {
        // Real credential attached, but no handle chosen yet — the only screen shown
        // in that state.
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChooseHandlePage(auth: widget.auth),
        ));
        if (!mounted) return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (_isSignUp && (e.code == 'email-already-in-use' || e.code == 'credential-already-in-use')) {
        setState(() {
          _mode = _Mode.signIn;
          _submitting = false;
          _error = 'You already have an account with that email — sign in below instead.';
        });
        return;
      }

      setState(() {
        _submitting = false;
        _error = _messageFor(e);
      });
    } catch (e) {
      if (e is ApiException && e.needsRegistration) {
        // A stray direct sign-up (see class doc) — a real Firebase identity with no
        // `users` row. Same recovery as the ordinary guest-upgrade path just above.
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChooseHandlePage(auth: widget.auth),
        ));
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong. Try again.';
      });
    }
  }

  String _messageFor(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address looks wrong.',
        'weak-password' => 'Choose a stronger password (6+ characters).',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email or password is incorrect.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts — wait a moment and try again.',
        _ => e.message ?? 'Something went wrong. Try again.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tone.bg,
      appBar: AppBar(
        backgroundColor: Tone.bg,
        elevation: 0,
        foregroundColor: Tone.ink,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: CoffeeCupSketch(size: 84)),
              const SizedBox(height: 12),
              Text(
                _isSignUp ? 'Create your account' : 'Welcome back',
                style: GoogleFonts.fraunces(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Tone.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? "Your spots so far come with you — you're not starting over."
                    : 'Sign in to see your spots.',
                style: GoogleFonts.fraunces(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Tone.muted,
                ),
              ),
              const SizedBox(height: 28),
              _label('EMAIL'),
              const SizedBox(height: 8),
              _field(controller: _emailController, hint: 'you@example.com'),
              const SizedBox(height: 16),
              _label('PASSWORD'),
              const SizedBox(height: 8),
              _field(controller: _passwordController, hint: '••••••••', obscure: true),
              if (_isSignUp) ...[
                const SizedBox(height: 16),
                _label('CONFIRM PASSWORD'),
                const SizedBox(height: 8),
                _field(controller: _confirmController, hint: '••••••••', obscure: true),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _errorBox(_error!),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Tone.ink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isSignUp ? 'Create account' : 'Sign in',
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
                  onTap: _submitting
                      ? null
                      : () => setState(() {
                            _mode = _isSignUp ? _Mode.signIn : _Mode.signUp;
                            _error = null;
                          }),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign in'
                        : "Don't have an account? Create one",
                    style: GoogleFonts.fraunces(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Tone.terracotta,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.fraunces(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Tone.muted,
        ),
      );

  Widget _field({required TextEditingController controller, required String hint, bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autocorrect: !obscure,
        keyboardType: obscure ? TextInputType.visiblePassword : TextInputType.emailAddress,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.fraunces(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: Tone.muted,
          ),
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
