import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/illustrations.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/features/authentication/presentation/choose_handle_page.dart';
import 'package:mobile/features/profile/presentation/avatar_picker_sheet.dart';
import 'package:mobile/features/profile/presentation/settings_drawer.dart';
import 'package:mobile/features/authentication/presentation/login_page.dart';
import 'package:mobile/features/study_spots/presentation/past_visits_sheet.dart'
    show formatVisitDate;
import 'package:mobile/main.dart';
import 'package:mobile/models/me.dart';
import 'package:mobile/models/visit.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_controller.dart';

class ProfilePage extends StatelessWidget {
  final AuthController auth;

  const ProfilePage({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    // Not reactive to auth.me changing after this build (e.g. a guest finishing
    // setup) — matches _StudyHistorySection's assumption that ProfilePage is
    // rebuilt from scratch on every tab switch (CleanBottomNav.pushReplacement,
    // no IndexedStack), so a stale value here only lasts until the next visit.
    final isSignedIn = auth.me != null && !auth.me!.isGuest;

    return Scaffold(
      endDrawer: isSignedIn ? SettingsDrawer(auth: auth) : null,
      body: SafeArea(
        // Reactive rather than read-once: signing in from here, or from the guest-limit
        // dialog on the Spots tab and then navigating back, both change auth.me without
        // this page being rebuilt from scratch.
        child: ListenableBuilder(
          listenable: auth,
          builder: (context, _) {
            final me = auth.me;
            if (me == null)
              return const Center(
                child: CircularProgressIndicator(color: Tone.ink),
              );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Profile',
                          style: GoogleFonts.fraunces(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Tone.ink,
                          ),
                        ),
                      ),
                      if (!me.isGuest)
                        IconButton(
                          onPressed: () => Scaffold.of(context).openEndDrawer(),
                          icon: const Icon(Icons.menu, color: Tone.ink),
                          splashRadius: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!me.isGuest)
                    _AccountCard(auth: auth, me: me)
                  // A real (non-anonymous) Firebase credential that's still isGuest
                  // server-side means sign-up/link succeeded but POST /me never ran —
                  // most often the app was closed between verifying and picking a
                  // handle. Sign-in/sign-up would just loop (that email is already
                  // theirs); the only way out is straight to ChooseHandlePage.
                  else if (FirebaseAuth.instance.currentUser?.isAnonymous ==
                      false)
                    _FinishSetupPrompt(auth: auth)
                  else
                    _GuestPrompt(auth: auth, me: me),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: CleanBottomNav(currentIndex: 1, auth: auth),
    );
  }
}

class _GuestPrompt extends StatelessWidget {
  final AuthController auth;
  final Me me;

  const _GuestPrompt({required this.auth, required this.me});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const ConfusedCatSketch(size: 128, color: Tone.muted),
          const SizedBox(height: 24),
          Text(
            "Looks like you don't have an account",
            textAlign: TextAlign.center,
            style: GoogleFonts.fraunces(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Tone.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You're browsing as a guest — your spots stay right here on this device. "
            'Create one to keep them for good, on any device.',
            textAlign: TextAlign.center,
            style: GoogleFonts.fraunces(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Tone.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${me.entryCount} of $guestEntryLimit guest spots used',
            style: GoogleFonts.fraunces(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Tone.terracotta,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoginPage(auth: auth, startInSignUp: true),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Tone.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Create one here',
                    style: GoogleFonts.fraunces(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LoginPage(auth: auth, startInSignUp: false),
              ),
            ),
            child: Text(
              'Already have an account? Sign in',
              style: GoogleFonts.fraunces(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Tone.terracotta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishSetupPrompt extends StatelessWidget {
  final AuthController auth;

  const _FinishSetupPrompt({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Tone.field,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_outline, size: 28, color: Tone.muted),
          const SizedBox(height: 14),
          Text(
            'Almost done',
            style: GoogleFonts.fraunces(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Tone.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You're signed in, but never picked a handle. Finish setting up your "
            'account to keep your spots for good.',
            style: GoogleFonts.fraunces(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Tone.muted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChooseHandlePage(auth: auth)),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Tone.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Finish setting up',
                    style: GoogleFonts.fraunces(
                      fontSize: 14.5,
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
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AuthController auth;
  final Me me;

  const _AccountCard({required this.auth, required this.me});

  Future<void> _pickAvatar(BuildContext context) async {
    final selection = await showAvatarPickerSheet(
      context,
      displayName: me.displayName,
      selectedAvatarId: me.avatarId,
      selectedColorSlug: me.avatarColor,
      selectedBackgroundTint: me.avatarBackgroundTint,
    );
    if (selection == null || !context.mounted) return;

    try {
      await auth.updateAvatar(
        selection.avatarId,
        colorSlug: selection.colorSlug,
        backgroundTint: selection.backgroundTint,
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Tone.ink,
          content: Text(
            e.message,
            style: GoogleFonts.fraunces(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = resolveAvatarTone(
      colorSlug: me.avatarColor,
      backgroundTint: me.avatarBackgroundTint,
    );

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _pickAvatar(context),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: tone.background,
                  // cafe_01 draws its own circular frame, so it fills the CircleAvatar
                  // edge-to-edge; the others get a small margin so they don't crowd it.
                  child: me.avatarId != null
                      ? AvatarIconSketch(
                          avatarId: me.avatarId!,
                          size: me.avatarId == 'cafe_01' ? 80 : 64,
                          color: tone.icon,
                        )
                      : Text(
                          me.displayName.isNotEmpty
                              ? me.displayName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.fraunces(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: tone.icon,
                          ),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Tone.terracotta,
                    shape: BoxShape.circle,
                    border: Border.all(color: Tone.bg, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            me.displayName,
            style: GoogleFonts.fraunces(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Tone.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '@${me.handle}',
            style: GoogleFonts.fraunces(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Tone.muted,
            ),
          ),
          const SizedBox(height: 36),
          // The one thing worth seeing at a glance — big and centered rather than a
          // small pill next to an icon.
          Text(
            '${me.entryCount}',
            style: GoogleFonts.fraunces(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1,
              color: Tone.terracotta,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            me.entryCount == 1 ? 'spot rated' : 'spots rated',
            style: GoogleFonts.fraunces(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Tone.muted,
            ),
          ),
          const SizedBox(height: 40),
          const _StudyHistorySection(),
        ],
      ),
    );
  }
}

/// Beli-style study history — every spot I've logged a visit at, newest first. Fetched
/// fresh on every mount rather than cached: ProfilePage is rebuilt from scratch on each
/// tab switch (CleanBottomNav.pushReplacement, no IndexedStack), so this naturally picks
/// up a visit logged moments earlier with no extra state-syncing.
class _StudyHistorySection extends StatefulWidget {
  const _StudyHistorySection();

  @override
  State<_StudyHistorySection> createState() => _StudyHistorySectionState();
}

class _StudyHistorySectionState extends State<_StudyHistorySection> {
  List<Visit>? _visits;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final visits = await fetchMyVisits();
      if (!mounted) return;
      setState(() => _visits = visits);
    } on ApiException {
      // Best-effort: the profile still renders fine without a study history.
      if (!mounted) return;
      setState(() => _visits = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STUDY HISTORY',
          style: GoogleFonts.fraunces(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Tone.muted,
          ),
        ),
        const SizedBox(height: 12),
        _buildBody(),
      ],
    );
  }

  Widget _buildBody() {
    final visits = _visits;

    if (visits == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: double.infinity,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Tone.muted),
            ),
          ),
        ),
      );
    }

    if (visits.isEmpty) {
      return Text(
        'No visits yet — log one from a spot you\'ve rated.',
        style: GoogleFonts.fraunces(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Tone.muted,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < visits.length && i < 8; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: Tone.line),
          _VisitHistoryRow(visit: visits[i]),
        ],
      ],
    );
  }
}

class _VisitHistoryRow extends StatelessWidget {
  final Visit visit;

  const _VisitHistoryRow({required this.visit});

  @override
  Widget build(BuildContext context) {
    final studied = visit.studied;
    final drinkOrder = visit.drinkOrder;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.spotName,
                  style: GoogleFonts.fraunces(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Tone.ink,
                  ),
                ),
                if (studied != null) ...[
                  const SizedBox(height: 4),
                  _LabeledLine(label: 'Studied', value: studied),
                ],
                if (drinkOrder != null) ...[
                  const SizedBox(height: 6),
                  _LabeledLine(label: 'Ordered', value: drinkOrder),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatVisitDate(visit.visitedAt, includeYear: true),
            style: GoogleFonts.fraunces(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Tone.terracotta,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled line within a visit row — a bolded title plus its value, so "what I
/// studied" and "what I ordered" read as clearly distinct.
class _LabeledLine extends StatelessWidget {
  final String label;
  final String value;

  const _LabeledLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: GoogleFonts.fraunces(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Tone.ink,
            ),
          ),
          TextSpan(
            text: value,
            style: GoogleFonts.fraunces(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Tone.muted,
            ),
          ),
        ],
      ),
    );
  }
}
