import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/main.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_controller.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum _Step { reauth, confirm }

/// Two-step account deletion: re-authenticate first (Firebase requires a "recent"
/// sign-in for a deletion this sensitive, and doing it up front avoids landing in a
/// half-deleted state if it were only tried reactively after the delete itself), then a
/// final destructive confirm. Only reachable from SettingsDrawer, which only renders for
/// a signed-in, non-guest user, so the identity here always has a real password, Google,
/// or Apple credential to re-collect - never an anonymous session.
class DeleteAccountPage extends StatefulWidget {
  final AuthController auth;

  const DeleteAccountPage({super.key, required this.auth});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _passwordController = TextEditingController();

  _Step _step = _Step.reauth;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String get _provider => widget.auth.reauthProvider;
  bool get _isPasswordProvider => _provider == 'password';
  bool get _isAppleProvider => _provider == 'apple.com';

  Future<void> _reauthenticate() async {
    if (_isPasswordProvider && _passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isPasswordProvider) {
        await widget.auth.reauthenticateWithPassword(_passwordController.text);
      } else if (_isAppleProvider) {
        await widget.auth.reauthenticateWithApple();
      } else {
        await widget.auth.reauthenticateWithGoogle();
      }
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _step = _Step.confirm;
      });
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // Backing out of the account picker isn't an error worth surfacing.
        if (e.code != GoogleSignInExceptionCode.canceled) {
          _error = 'Could not verify with Google. Try again.';
        }
      });
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // Backing out of the Apple sheet isn't an error worth surfacing.
        if (e.code != AuthorizationErrorCode.canceled) {
          _error = 'Could not verify with Apple. Try again.';
        }
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'That password is incorrect.'
            : e.message ?? 'Could not verify. Try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong. Try again.';
      });
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Tone.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete your account?',
          style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
        ),
        content: Text(
          "This is permanent and can't be undone.",
          style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w500, color: Tone.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w700, color: Tone.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete Account',
              style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w700, color: Tone.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.auth.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SpotsPage(auth: widget.auth)),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message ?? 'Something went wrong. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tone.bg,
      appBar: AppBar(
        backgroundColor: Tone.bg,
        elevation: 0,
        foregroundColor: Tone.ink,
        title: Text(
          'Delete Account',
          style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _step == _Step.reauth ? _buildReauth() : _buildConfirm(),
        ),
      ),
    );
  }

  Widget _buildReauth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, size: 32, color: Tone.muted),
        const SizedBox(height: 16),
        Text(
          "Verify it's you",
          style: GoogleFonts.fraunces(fontSize: 19, fontWeight: FontWeight.w800, color: Tone.ink),
        ),
        const SizedBox(height: 8),
        Text(
          'For your security, confirm your identity before deleting your account.',
          style: GoogleFonts.fraunces(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Tone.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        if (_isPasswordProvider)
          _passwordField()
        else if (_isAppleProvider)
          _appleButton()
        else
          _googleButton(),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _errorBox(_error!),
        ],
        if (_isPasswordProvider) ...[
          const SizedBox(height: 22),
          _button(
            label: 'Continue',
            color: Tone.ink,
            onTap: _submitting ? null : _reauthenticate,
          ),
        ],
      ],
    );
  }

  Widget _buildConfirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 32, color: Tone.error),
        const SizedBox(height: 16),
        Text(
          'This will permanently delete:',
          style: GoogleFonts.fraunces(fontSize: 19, fontWeight: FontWeight.w800, color: Tone.ink),
        ),
        const SizedBox(height: 12),
        _bullet('Your profile and account sign-in'),
        _bullet('Every spot you\'ve rated'),
        _bullet('Your study history'),
        const SizedBox(height: 16),
        Text(
          "This can't be undone.",
          style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w700, color: Tone.error),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _errorBox(_error!),
        ],
        const SizedBox(height: 22),
        _button(
          label: 'Delete My Account',
          color: Tone.error,
          onTap: _submitting ? null : _confirmAndDelete,
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(width: 5, height: 5, decoration: const BoxDecoration(
              color: Tone.muted,
              shape: BoxShape.circle,
            )),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.fraunces(fontSize: 14, fontWeight: FontWeight.w600, color: Tone.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField() {
    return Container(
      decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: _passwordController,
        obscureText: true,
        autocorrect: false,
        keyboardType: TextInputType.visiblePassword,
        onSubmitted: (_) => _submitting ? null : _reauthenticate(),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Password',
          hintStyle: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w500, color: Tone.muted),
        ),
        style: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w600, color: Tone.ink),
      ),
    );
  }

  Widget _appleButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: SignInWithAppleButton(
        onPressed: _submitting ? () {} : _reauthenticate,
        style: SignInWithAppleButtonStyle.black,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _submitting ? null : _reauthenticate,
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
                style: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w700, color: Tone.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button({required String label, required Color color, required VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
          child: Center(
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    label,
                    style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
          ),
        ),
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
