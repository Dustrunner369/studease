import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/features/authentication/presentation/login_page.dart';
import 'package:mobile/main.dart';
import 'package:mobile/models/me.dart';
import 'package:mobile/services/auth_controller.dart';

class ProfilePage extends StatelessWidget {
  final AuthController auth;

  const ProfilePage({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // Reactive rather than read-once: signing in from here, or from the guest-limit
        // dialog on the Spots tab and then navigating back, both change auth.me without
        // this page being rebuilt from scratch.
        child: ListenableBuilder(
          listenable: auth,
          builder: (context, _) {
            final me = auth.me;
            if (me == null) return const Center(child: CircularProgressIndicator(color: Tone.ink));

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: GoogleFonts.fraunces(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Tone.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (me.isGuest) _GuestPrompt(auth: auth, me: me) else _AccountCard(auth: auth, me: me),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: CleanBottomNav(currentIndex: 2, auth: auth),
    );
  }
}

class _GuestPrompt extends StatelessWidget {
  final AuthController auth;
  final Me me;

  const _GuestPrompt({required this.auth, required this.me});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_outline, size: 28, color: Tone.muted),
          const SizedBox(height: 14),
          Text(
            "You don't have an account yet!",
            style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
          ),
          const SizedBox(height: 6),
          Text(
            "You're browsing as a guest — your spots stay right here on this device. "
            'Create an account to keep them for good, on any device.',
            style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w500, color: Tone.muted),
          ),
          const SizedBox(height: 6),
          Text(
            '${me.entryCount} of $guestEntryLimit guest spots used',
            style: GoogleFonts.fraunces(fontSize: 12.5, fontWeight: FontWeight.w600, color: Tone.terracotta),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LoginPage(auth: auth, startInSignUp: true),
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Tone.ink, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text(
                    'Create one?',
                    style: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LoginPage(auth: auth, startInSignUp: false),
              )),
              child: Text(
                'Already have an account? Sign in',
                style: GoogleFonts.fraunces(fontSize: 12.5, fontWeight: FontWeight.w700, color: Tone.terracotta),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AuthController auth;
  final Me me;

  const _AccountCard({required this.auth, required this.me});

  Future<void> _signOut(BuildContext context) async {
    await auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => SpotsPage(auth: auth)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Tone.field,
              child: Text(
                me.displayName.isNotEmpty ? me.displayName[0].toUpperCase() : '?',
                style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w800, color: Tone.ink),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me.displayName,
                    style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
                  ),
                  Text(
                    '@${me.handle}',
                    style: GoogleFonts.fraunces(fontSize: 13, fontWeight: FontWeight.w600, color: Tone.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, size: 18, color: Tone.muted),
              const SizedBox(width: 10),
              Text(
                '${me.entryCount} spot${me.entryCount == 1 ? '' : 's'} rated',
                style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tone.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () => _signOut(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Tone.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Tone.line, width: 1.5),
              ),
              child: Center(
                child: Text(
                  'Sign out',
                  style: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w700, color: Tone.error),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
