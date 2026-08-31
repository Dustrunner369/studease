import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/features/profile/presentation/feedback_page.dart';
import 'package:mobile/features/profile/presentation/privacy_policy_page.dart';
import 'package:mobile/main.dart';
import 'package:mobile/services/auth_controller.dart';

/// The right-side settings panel, opened via the menu icon in ProfilePage's
/// header. A standard Material [Drawer] used as a Scaffold.endDrawer, which
/// already slides in from the right edge with the expected scrim + swipe-to-
/// dismiss behavior.
class SettingsDrawer extends StatelessWidget {
  final AuthController auth;

  const SettingsDrawer({super.key, required this.auth});

  Future<void> _signOut(BuildContext context) async {
    Navigator.of(context).pop(); // close the drawer first
    await auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => SpotsPage(auth: auth)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Tone.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Settings',
                      style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w800, color: Tone.ink),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Tone.muted),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Tone.line),
            _SettingsRow(
              icon: Icons.chat_bubble_outline,
              label: 'Leave Feedback',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FeedbackPage()),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Tone.line),
            _SettingsRow(
              icon: Icons.shield_outlined,
              label: 'Privacy Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Tone.line),
            _SettingsRow(
              icon: Icons.logout,
              label: 'Sign out',
              labelColor: Tone.error,
              onTap: () => _signOut(context),
            ),
            const Divider(height: 1, thickness: 1, color: Tone.line),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _SettingsRow({required this.icon, required this.label, this.labelColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: labelColor ?? Tone.ink),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w700, color: labelColor ?? Tone.ink),
            ),
          ],
        ),
      ),
    );
  }
}
