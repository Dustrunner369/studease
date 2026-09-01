import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/design/illustrations.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/features/authentication/presentation/choose_handle_page.dart';
import 'package:mobile/features/authentication/presentation/verify_email_page.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_controller.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum _Mode { signUp, signIn }

/// Email/password sign-up and sign-in, plus Google and Apple buttons — Apple is
/// required alongside Google per App Store guideline 4.8, not optional polish.
///
/// Both paths *link* the guest's current anonymous session (see AuthController), so
/// whatever they've already added carries over. If that email turns out to already have
/// an account, email sign-up switches to sign-in mode with an explanation rather than
/// guessing — the password just typed may not belong to that other account; Google hits
/// `account-exists-with-different-credential` instead, since Firebase enforces one
/// account per email address (see auth-plan.md "Account collision").
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
        if (!mounted) return;

        // Real credential attached, but not verified yet — the only screen shown in
        // that state. Nothing to do here until it resolves out of
        // needsEmailVerification, either verified (-> maybe still needs a handle) or
        // the user backs out via "sign out and start over" inside that screen.
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VerifyEmailPage(auth: widget.auth),
        ));
        if (!mounted) return;

        if (widget.auth.phase == AuthPhase.needsRegistration) {
          // Verified, but still no handle chosen yet.
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChooseHandlePage(auth: widget.auth),
          ));
          if (!mounted) return;
        }

        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      await widget.auth.signInWithEmail(email, password);
      if (!mounted) return;
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

  // Same guest-linking and needsRegistration handling as email/password, but Google
  // accounts arrive pre-verified — no VerifyEmailPage detour.
  Future<void> _submitGoogle() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.auth.signInWithGoogle();
      if (!mounted) return;

      if (widget.auth.phase == AuthPhase.needsRegistration) {
        // Linked (or brand-new) Google identity, no handle chosen yet.
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChooseHandlePage(auth: widget.auth),
        ));
        if (!mounted) return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // A user backing out of the account picker isn't an error worth surfacing.
        if (e.code != GoogleSignInExceptionCode.canceled) {
          _error = 'Could not sign in with Google. Try again.';
        }
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.code == 'account-exists-with-different-credential'
            ? 'You already have an account with this email — sign in with your '
                'password, then link Google from your profile.'
            : _messageFor(e);
      });
    } catch (e) {
      if (e is ApiException && e.needsRegistration) {
        // Brand-new Google identity, no handle chosen yet.
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

  // Same shape as _submitGoogle - see its doc for the guest-linking/needsRegistration
  // handling, which is identical here.
  Future<void> _submitApple() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.auth.signInWithApple();
      if (!mounted) return;

      if (widget.auth.phase == AuthPhase.needsRegistration) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChooseHandlePage(auth: widget.auth),
        ));
        if (!mounted) return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // A user backing out of the Apple sheet isn't an error worth surfacing.
        if (e.code != AuthorizationErrorCode.canceled) {
          _error = 'Could not sign in with Apple. Try again.';
        }
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.code == 'account-exists-with-different-credential'
            ? 'You already have an account with this email — sign in with your '
                'password, then link Apple from your profile.'
            : _messageFor(e);
      });
    } catch (e) {
      if (e is ApiException && e.needsRegistration) {
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
              _appleButton(),
              const SizedBox(height: 12),
              _googleButton(),
              const SizedBox(height: 20),
              _orDivider(),
              const SizedBox(height: 20),
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

  // Apple's own button widget, not a hand-rolled one like _googleButton - Apple's
  // Human Interface Guidelines require using their supplied button for brand/contrast
  // compliance, not a custom look-alike.
  Widget _appleButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: SignInWithAppleButton(
        onPressed: _submitting ? () {} : _submitApple,
        style: SignInWithAppleButtonStyle.black,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _submitting ? null : _submitGoogle,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: Tone.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Tone.line, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.g_mobiledata, size: 26, color: Tone.ink),
              const SizedBox(width: 4),
              Text(
                'Continue with Google',
                style: GoogleFonts.fraunces(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Tone.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1, thickness: 1, color: Tone.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: GoogleFonts.fraunces(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Tone.muted,
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1, thickness: 1, color: Tone.line)),
      ],
    );
  }

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
