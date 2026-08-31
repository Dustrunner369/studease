import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';

/// Placeholder destination for both entry points (SettingsDrawer, ProfilePage) added
/// ahead of the actual policy text being ready. Swap the body for the real copy once
/// it exists — the entry points themselves shouldn't need to change.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tone.bg,
      appBar: AppBar(
        backgroundColor: Tone.bg,
        elevation: 0,
        foregroundColor: Tone.ink,
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 40, color: Tone.muted),
                const SizedBox(height: 16),
                Text(
                  'Still being written',
                  style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Our privacy policy will be posted here once it\'s ready.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w500, color: Tone.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
