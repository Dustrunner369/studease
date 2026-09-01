import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';

/// Renders context/privacy-policy.md, hand-transcribed rather than parsed - the source
/// is fact-checked against this app's actual code (see that file's maintainer note) and
/// changes rarely enough that a markdown dependency isn't worth adding for it. Keep the
/// two in sync: edit the .md first, then port the change here.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static final _body = GoogleFonts.fraunces(
    fontSize: TextScale.bodySm,
    fontWeight: FontWeight.w500,
    color: Tone.ink,
    height: 1.45,
  );

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _meta(),
              const SizedBox(height: Space.md),
              _p(
                'This Privacy Policy explains how Matthew Swift ("Studease," "we," "us") '
                'collects, uses, shares, and deletes information when you use the Studease '
                'iOS app (the "Service"). If you don\'t agree with this policy, please don\'t '
                'use Studease.',
              ),

              _h('01', 'What we collect'),
              _sub('Your account'),
              _callout(
                'Studease never receives or stores a password. You sign in with email and '
                'password, with Google, or with Apple — either way, sign-in itself is '
                'handled by Firebase (Google\'s authentication platform), and Studease\'s '
                'own servers never see or store a password.',
              ),
              _bullet('Sign-in identifier', '— from Firebase, when you first sign in — to recognize you '
                  'on your next visit.'),
              _bullet('Email address', '— the one you sign up with, or your Google account\'s — used for '
                  'account-related messages and to reply if you use the feedback form.'),
              _bullet('Handle and display name', '— you choose them — your identity within the app.'),
              _bullet('Avatar icon and accent color', '— optional, chosen from a preset set — personalizes '
                  'your profile.'),
              _sub('What you create in Studease'),
              _bullet('Ratings', '— six 1–5 ratings for a spot (wifi, noise, outlets, seating, table size, '
                  'coffee), whether it worked for group study, and an overall score calculated from them.'),
              _bullet('Tags', '— labels you attach to a spot. Requesting a new one stores the request under '
                  'your account so it can be reviewed before joining the shared list.'),
              _bullet('Notes and coffee order', '— free text you write. Stored and shown back to you, never '
                  'parsed, analyzed, or used to build a profile of you.'),
              _bullet('Visit log', '— each time you log that you studied somewhere: the spot, a timestamp '
                  'our server records at that moment, and optionally what you studied and what you ordered.'),
              _bullet('Spots you add', '— the place\'s name and address, and its Google Place identifier if '
                  'you picked it from search rather than typing it in by hand.'),
              _callout(
                'Your visit log is the most sensitive thing in Studease — it\'s a record of '
                'where you\'ve physically been. It\'s visible only to you, full stop: it '
                'never appears on a spot\'s page, in search, or anywhere another user can '
                'see it, and you can delete any single visit at any time.',
              ),
              _sub('Collected automatically'),
              _bullet('A coarse region inferred from your IP address', '(city/region level) — a normal '
                  'by-product of any request reaching our server.'),
              _p('Nothing else. Studease doesn\'t currently use any analytics or crash-reporting tool, so '
                  'no usage data, diagnostics, or device/installation identifiers are collected. If that '
                  'changes, this policy changes first.'),
              _sub('What we never collect'),
              _p(
                'Studease doesn\'t ask for your device\'s location and doesn\'t collect GPS or '
                'precise location data of any kind — you find spots by searching for them by '
                'name or address. We also don\'t collect your password (Firebase handles '
                'that), your contacts, your photo library, camera or microphone input, your '
                'device\'s advertising identifier, health data, payment details, or anything '
                'from your school.',
              ),

              _h('02', 'What other people can see'),
              _p(
                'Almost nothing. Every rating, tag, note, coffee order, visit, and profile '
                'detail you create is visible only to you. Studease doesn\'t have public '
                'profiles today, there\'s no way for another user to look you up, and no '
                'rating is ever shown next to who left it — not even your handle.',
              ),
              _p(
                'The one exception is aggregates: a spot\'s average score and tag counts are '
                'visible to everyone, calculated across every rating left on that spot — but '
                'only as numbers, never broken out by who rated what.',
              ),

              _h('03', 'How we use it'),
              _p('We use what we collect to:'),
              _bulletPlain('create, authenticate, and secure your account'),
              _bulletPlain('store your ratings, tags, notes, and visits, and show them back to you'),
              _bulletPlain('build each spot\'s page, including the average score and tag counts '
                  'calculated from everyone\'s ratings'),
              _bulletPlain('let you find spots by name and address'),
              _bulletPlain('review requests for new tags and keep the shared list usable'),
              _bulletPlain('operate the app and fix problems as they come up'),
              _bulletPlain('respond to feedback and support requests you send us'),
              _bulletPlain('comply with legal obligations'),
              _p(
                'We do not sell your information, we do not use it for advertising, we do '
                'not build behavioral profiles from your notes or visits, and we do not use '
                'your content to train machine learning models.',
              ),

              _h('04', 'Who we share it with'),
              _p('We share information only in these situations:'),
              _bullet('Service providers,', 'listed below, who process data on our behalf to run the '
                  'Service. They may use it only for that purpose.'),
              _bullet('Legal reasons', '— where we believe in good faith that disclosure is required by '
                  'law, subpoena, or other legal process, or is necessary to protect the rights, property, '
                  'or safety of Studease, our users, or the public.'),
              _bullet('A business transfer', '— if Studease is ever sold or transferred, your information '
                  'may transfer with it. You\'d be notified before it becomes subject to a different '
                  'privacy policy.'),
              _sub('The providers, and what they receive'),
              _bullet('Firebase (Google)', '— authentication (email/password, Google, and Apple sign-in), '
                  'and sending account-verification emails — receives your sign-in identifier and email '
                  'address.'),
              _bullet('Apple', '— Sign in with Apple, if you choose it — receives your Apple ID identifier '
                  'and, unless you choose to hide it, your email address (Apple\'s own "Hide My Email" '
                  'gives you a private relay address instead, which still reaches you but isn\'t your '
                  'real one).'),
              _bullet('Google Maps Platform', '— place search and details for spots — receives your search '
                  'text, the place being viewed, and your IP address; Google sees which places are looked '
                  'up and when, but not who you are on Studease.'),
              _bullet('Fly.io', '— hosts the application server — receives everything in section 01, since '
                  'this is where requests are processed.'),
              _bullet('Neon', '— hosts the Postgres database — receives everything in section 01, since '
                  'this is where your account and content live.'),
              _bullet('Gmail,', 'my own personal account, via SMTP — receives only what you type into the '
                  'in-app feedback form, plus your handle and display name. It\'s one-directional: this '
                  'pipeline emails your feedback to me, it never emails you, and it never receives your '
                  'account email address.'),

              _h('05', 'Retention and deletion'),
              _p(
                'We keep your account and everything in it for as long as your account '
                'exists. You can delete a rating (which also removes its tags, notes, and '
                'coffee order) or a single logged visit at any time.',
              ),
              _sub('Deleting your account'),
              _p(
                'You can delete your account directly in the app, from Settings → Delete '
                'Account. Deletion is immediate and permanent — it doesn\'t queue or take '
                'days to process.',
              ),
              _bullet('Your account', '— handle, display name, email, sign-in identifier, avatar choice — '
                  'deleted immediately.'),
              _bullet('Your ratings and tags', '— deleted, along with their notes and coffee orders.'),
              _bullet('Your visit log', '— deleted in full.'),
              _bullet('Spots you added', '— kept, since they\'re part of a shared catalogue other people\'s '
                  'ratings depend on, but no longer linked to your account in any way.'),
              _bullet('Tags you requested', '— the tag itself stays in the shared list if it was approved; '
                  'the record of who requested it is cleared.'),
              _bullet('A spot\'s average score and tag counts', '— recalculated immediately without your '
                  'ratings.'),
              _bullet('Backups', '— our database host (Neon) keeps rolling backups for disaster recovery, '
                  'cycled out on its own standard schedule.'),
              _bullet('Legal records', '— we may keep a minimal record of the deletion itself where '
                  'required by law or to resolve a dispute.'),

              _h('06', 'Your choices and rights'),
              _p('Wherever you live, you can:'),
              _bullet('See and correct', 'your profile in the app\'s settings.'),
              _bullet('Delete individual items', '— a rating or a logged visit.'),
              _bullet('Get a copy', 'of your ratings, visits, and profile by emailing '
                  'matthewswift369@gmail.com.'),
              _bullet('Delete your account,', 'and everything described in section 05.'),
              _bullet('Revoke Studease\'s access', 'to your Google account from your Google account\'s own '
                  'security settings, if you signed in with Google.'),
              _p(
                'To exercise any of these, use the in-app controls or email '
                'matthewswift369@gmail.com. We respond within 45 days, and we will not treat '
                'you differently for exercising a privacy right.',
              ),

              _h('07', 'Notice to California residents'),
              _p(
                'Studease is a personal project, not the kind of large business the CCPA is '
                'written for — this section is included as a courtesy, not because the law '
                'necessarily requires it at this scale. Your rights under this policy don\'t '
                'depend on that distinction.',
              ),
              _sub('Categories collected in the past 12 months'),
              _bullet('Identifiers', '— yes: handle, display name, email address, account ID, sign-in '
                  'identifier, IP address.'),
              _bullet('Customer records', '— yes: email address. No passwords — sign-in is delegated to '
                  'Firebase.'),
              _bullet('Commercial information', '— no: Studease has no purchases or subscriptions.'),
              _bullet('Internet or network activity', '— no: Studease doesn\'t use analytics or crash '
                  'reporting.'),
              _bullet('Geolocation data', '— yes, but never from your device: a coarse region inferred from '
                  'your IP address, and the places you choose to tell us you studied at.'),
              _bullet('User-created content', '— yes: ratings, tags, notes, coffee orders, visit log.'),
              _bullet('Inferences', '— no: we don\'t analyze your text or build profiles. A spot\'s average '
                  'score is a fact about the place, not about you.'),
              _bullet('Sensitive personal information', '— none.'),
              _bullet('Education records under FERPA', '— no.'),
              _bullet('Biometric, audio/visual, professional, or protected classifications', '— no.'),
              _p('Sources — directly from you, from Firebase (Google) when you sign in, and automatically '
                  'as a byproduct of your requests reaching our server.'),
              _p('Business purposes — as described in section 03.'),
              _p('Sale or sharing — we have not sold personal information and have not shared it for '
                  'cross-context behavioral advertising in the past 12 months, including the information '
                  'of consumers under 16.'),
              _p('Retention — as described in section 05.'),
              _p('Your rights — to know, to access a copy, to correct, to delete, to opt out of sale or '
                  'sharing, to limit the use of sensitive personal information, and to be free from '
                  'discrimination for exercising these rights.'),
              _p('How to submit a request — use the in-app controls in Settings, or email '
                  'matthewswift369@gmail.com. We verify your identity by confirming you control the '
                  'account, through the same sign-in you use for the app.'),

              _h('08', 'Security'),
              _p(
                'Traffic between the app and our servers is encrypted with TLS, and data is '
                'encrypted at rest by our database host. Because sign-in is delegated to '
                'Firebase, we hold no passwords — the most commonly stolen thing in a breach '
                'simply isn\'t in our database.',
              ),
              _p(
                'Studease is a solo project — I\'m the only person with access to the '
                'database and hosting infrastructure. The app also has an internal '
                '"moderator" role used only for reviewing new tag requests; right now, '
                'that\'s me too.',
              ),
              _p(
                'No system is perfectly secure and we cannot guarantee absolute security. If '
                'a breach affects your personal information, we will notify you as required '
                'by applicable law.',
              ),

              _h('09', 'Children\'s privacy'),
              _p(
                'Studease is intended for users aged 17 and older and is not directed to '
                'children under 13. We do not knowingly collect personal information from '
                'anyone under 13. If we learn that we have, we delete it promptly. A parent '
                'or guardian who believes their child has provided us information may '
                'contact matthewswift369@gmail.com.',
              ),

              _h('10', 'Where your data is processed'),
              _p(
                'Studease is operated in the United States: the application server runs on '
                'Fly.io, and the database runs on Neon, both on U.S. infrastructure. The '
                'Service is intended for users in the United States and is not directed to '
                'individuals in the European Economic Area or the United Kingdom.',
              ),

              _h('11', 'Changes to this policy'),
              _p(
                'We may update this policy as Studease changes. When we do, we revise the '
                '"Last updated" date above. Studease doesn\'t currently have a way to notify '
                'you directly — no push notifications, no account emails beyond sign-in — so '
                'please check back here occasionally. Continued use of Studease after a '
                'change takes effect means you accept the updated policy.',
              ),

              _h('12', 'Contact us'),
              _p('Matthew Swift\nmatthewswift369@gmail.com'),

              const SizedBox(height: Space.md),
              const Divider(height: 1, thickness: 1, color: Tone.line),
              const SizedBox(height: Space.md),
              Text(
                'This policy was written to match Studease\'s actual code as of August 31, '
                '2026. It isn\'t legal advice. If Studease ever adds features like public '
                'profiles, a following system, analytics, or ads, this policy needs to be '
                'updated to match before that ships.',
                style: GoogleFonts.fraunces(
                  fontSize: TextScale.caption,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: Tone.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta() {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text.rich(
            TextSpan(
              style: GoogleFonts.fraunces(fontSize: TextScale.caption, fontWeight: FontWeight.w600, color: Tone.muted),
              children: [
                TextSpan(text: '$label  ', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: value),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('Effective', 'August 31, 2026'),
        row('Last updated', 'August 31, 2026'),
        row('Operator', 'Matthew Swift — an individual, not a registered company'),
        row('Contact', 'matthewswift369@gmail.com'),
      ],
    );
  }

  Widget _h(String number, String title) => Padding(
        padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
        child: Text(
          '$number · $title',
          style: GoogleFonts.fraunces(fontSize: TextScale.title, fontWeight: FontWeight.w800, color: Tone.ink),
        ),
      );

  Widget _sub(String text) => Padding(
        padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs2),
        child: Text(
          text,
          style: GoogleFonts.fraunces(fontSize: TextScale.bodyLg, fontWeight: FontWeight.w700, color: Tone.ink),
        ),
      );

  Widget _p(String text) => Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Text(text, style: _body),
      );

  Widget _bullet(String lead, String rest) => Padding(
        padding: const EdgeInsets.only(bottom: Space.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7, right: 10),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: Tone.muted, shape: BoxShape.circle),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: _body,
                  children: [
                    TextSpan(text: '$lead ', style: _body.copyWith(fontWeight: FontWeight.w800)),
                    TextSpan(text: rest),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _bulletPlain(String text) => Padding(
        padding: const EdgeInsets.only(bottom: Space.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7, right: 10),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: Tone.muted, shape: BoxShape.circle),
              ),
            ),
            Expanded(child: Text(text, style: _body)),
          ],
        ),
      );

  Widget _callout(String text) => Container(
        margin: const EdgeInsets.only(bottom: Space.sm),
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: _body.copyWith(fontWeight: FontWeight.w700)),
      );
}
