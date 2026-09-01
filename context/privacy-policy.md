<!--
Maintainer note (not shown in-app — see app-frontend/mobile/lib/features/profile/presentation/privacy_policy_page.dart
for the version users actually read).

This is the source of truth for that page. Written and fact-checked against the actual
backend/frontend code as of 2026-08-31, not aspirationally — see the corrections noted
inline as they matter. Update this file first, then port the change into
privacy_policy_page.dart.

Revisit before shipping any of: public profiles / handle visible to other users,
a following system, a working private-rating toggle (Visibility exists on SpotEntry
but nothing in the client ever sets it away from the Public default, and no API response
ever shows one user's individual rating to another), photo upload (AvatarUrl exists on
User but nothing writes it), analytics/crash reporting, push notifications, or worldwide
App Store availability.

Updated 2026-08-31: Sign in with Apple shipped (see auth-plan.md, "Apple is out of
scope" - reversed) - the account section and provider table below already reflect it.
-->

# Privacy Policy — Studease

**Effective:** August 31, 2026 · **Last updated:** August 31, 2026
**Operator:** Matthew Swift — an individual, not a registered company · **Contact:** matthewswift369@gmail.com

Studease helps you find, rate, and keep track of places to study. This is a personal project, not a company — this policy explains exactly what I store when you use it, who else can see it, and how to get rid of it.

This Privacy Policy explains how Matthew Swift ("Studease," "we," "us") collects, uses, shares, and deletes information when you use the Studease iOS app (the "Service"). If you don't agree with this policy, please don't use Studease.

## 01 · What we collect

### Your account

Studease never receives or stores a password. You sign in with email and password, with Google, or with Apple — either way, sign-in itself is handled by Firebase (Google's authentication platform), and Studease's own servers never see or store a password.

- **Sign-in identifier** — from Firebase, when you first sign in — to recognize you on your next visit
- **Email address** — the one you sign up with, or your Google account's — used for account-related messages (like verifying a password sign-up) and to reply if you use the feedback form
- **Handle and display name** — you choose them — your identity within the app
- **Avatar icon and accent color** — optional, chosen from a preset set — personalizes your profile

### What you create in Studease

- **Ratings** — six 1–5 ratings for a spot (wifi, noise, outlets, seating, table size, coffee), whether it worked for group study, and an overall score calculated from them
- **Tags** — labels you attach to a spot. Requesting a new one that doesn't exist yet stores the request under your account so it can be reviewed before joining the shared list
- **Notes and coffee order** — free text you write. Stored and shown back to you, never parsed, analyzed, or used to build a profile of you
- **Visit log** — each time you log that you studied somewhere: the spot, a timestamp our server records at that moment, and optionally what you studied and what you ordered
- **Spots you add** — the place's name and address, and its Google Place identifier if you picked it from search rather than typing it in by hand

**Your visit log is the most sensitive thing in Studease** — it's a record of where you've physically been. It's visible only to you, full stop: it never appears on a spot's page, in search, or anywhere another user can see it, and you can delete any single visit at any time.

### Collected automatically

- **A coarse region inferred from your IP address** (city/region level) — a normal by-product of any request reaching our server
- Nothing else. Studease doesn't currently use any analytics or crash-reporting tool, so no usage data, diagnostics, or device/installation identifiers are collected. If that changes, this policy changes first.

### What we never collect

Studease doesn't ask for your device's location and doesn't collect GPS or precise location data of any kind — you find spots by searching for them by name or address. We also don't collect your password (Firebase handles that), your contacts, your photo library, camera or microphone input, your device's advertising identifier, health data, payment details, or anything from your school.

## 02 · What other people can see

Almost nothing. Every rating, tag, note, coffee order, visit, and profile detail you create is visible only to you. Studease doesn't have public profiles today, there's no way for another user to look you up, and no rating is ever shown next to who left it — not even your handle.

The one exception is aggregates: a spot's average score and tag counts are visible to everyone, calculated across every rating left on that spot — but only as numbers, never broken out by who rated what.

## 03 · How we use it

We use what we collect to:

- create, authenticate, and secure your account
- store your ratings, tags, notes, and visits, and show them back to you
- build each spot's page, including the average score and tag counts calculated from everyone's ratings
- let you find spots by name and address
- review requests for new tags and keep the shared list usable
- operate the app and fix problems as they come up
- respond to feedback and support requests you send us
- comply with legal obligations

We do not sell your information, we do not use it for advertising, we do not build behavioral profiles from your notes or visits, and we do not use your content to train machine learning models.

## 04 · Who we share it with

We share information only in these situations:

- **Service providers**, listed below, who process data on our behalf to run the Service. They may use it only for that purpose.
- **Legal reasons** — where we believe in good faith that disclosure is required by law, subpoena, or other legal process, or is necessary to protect the rights, property, or safety of Studease, our users, or the public.
- **A business transfer** — if Studease is ever sold or transferred, your information may transfer with it. You'd be notified before it becomes subject to a different privacy policy.

**The providers, and what they receive:**

- **Firebase (Google)** — authentication (email/password, Google, and Apple sign-in), and sending account-verification emails — receives your sign-in identifier and email address
- **Apple** — Sign in with Apple, if you choose it — receives your Apple ID identifier and, unless you choose to hide it, your email address (Apple's own "Hide My Email" gives you a private relay address instead, which still reaches you but isn't your real one)
- **Google Maps Platform** — place search and details for spots — receives your search text, the place being viewed, and your IP address; Google sees which places are looked up and when, but not who you are on Studease
- **Fly.io** — hosts the application server — receives everything in section 01, since this is where requests are processed
- **Neon** — hosts the Postgres database — receives everything in section 01, since this is where your account and content live
- **Gmail**, my own personal account, via SMTP — receives only what you type into the in-app feedback form, plus your handle and display name. It's one-directional: this pipeline emails your feedback *to* me, it never emails *you*, and it never receives your account email address

## 05 · Retention and deletion

We keep your account and everything in it for as long as your account exists. You can delete a rating (which also removes its tags, notes, and coffee order) or a single logged visit at any time.

### Deleting your account

You can delete your account directly in the app, from Settings → Delete Account. Deletion is immediate and permanent — it doesn't queue or take days to process.

- **Your account** — handle, display name, email, sign-in identifier, avatar choice — deleted immediately
- **Your ratings and tags** — deleted, along with their notes and coffee orders
- **Your visit log** — deleted in full
- **Spots you added** — kept, since they're part of a shared catalogue other people's ratings depend on, but no longer linked to your account in any way
- **Tags you requested** — the tag itself stays in the shared list if it was approved; the record of who requested it is cleared
- **A spot's average score and tag counts** — recalculated immediately without your ratings
- **Backups** — our database host (Neon) keeps rolling backups for disaster recovery, cycled out on its own standard schedule
- **Legal records** — we may keep a minimal record of the deletion itself where required by law or to resolve a dispute

## 06 · Your choices and rights

Wherever you live, you can:

- **See and correct** your profile in the app's settings
- **Delete individual items** — a rating or a logged visit
- **Get a copy** of your ratings, visits, and profile by emailing matthewswift369@gmail.com
- **Delete your account**, and everything described in section 05
- **Revoke Studease's access** to your Google account from your Google account's own security settings, if you signed in with Google

To exercise any of these, use the in-app controls or email matthewswift369@gmail.com. We respond within 45 days, and we will not treat you differently for exercising a privacy right.

## 07 · Notice to California residents

Studease is a personal project, not the kind of large business the CCPA is written for — this section is included as a courtesy, not because the law necessarily requires it at this scale. Your rights under this policy don't depend on that distinction.

**Categories collected in the past 12 months**

- **Identifiers** — yes: handle, display name, email address, account ID, sign-in identifier, IP address
- **Customer records** — yes: email address. No passwords — sign-in is delegated to Firebase
- **Commercial information** — no: Studease has no purchases or subscriptions
- **Internet or network activity** — no: Studease doesn't use analytics or crash reporting
- **Geolocation data** — yes, but never from your device: a coarse region inferred from your IP address, and the places you choose to tell us you studied at
- **User-created content** — yes: ratings, tags, notes, coffee orders, visit log
- **Inferences** — no: we don't analyze your text or build profiles. A spot's average score is a fact about the place, not about you
- **Sensitive personal information** — none
- **Education records under FERPA** — no
- **Biometric, audio/visual, professional, or protected classifications** — no

**Sources.** Directly from you, from Firebase (Google) when you sign in, and automatically as a byproduct of your requests reaching our server.

**Business purposes.** As described in section 03.

**Sale or sharing.** We have not sold personal information and have not shared it for cross-context behavioral advertising in the past 12 months, including the information of consumers under 16.

**Retention.** As described in section 05.

**Your rights.** To know, to access a copy, to correct, to delete, to opt out of sale or sharing, to limit the use of sensitive personal information, and to be free from discrimination for exercising these rights.

**How to submit a request.** Use the in-app controls in Settings, or email matthewswift369@gmail.com. We verify your identity by confirming you control the account, through the same sign-in you use for the app.

## 08 · Security

Traffic between the app and our servers is encrypted with TLS, and data is encrypted at rest by our database host. Because sign-in is delegated to Firebase, we hold no passwords — the most commonly stolen thing in a breach simply isn't in our database.

Studease is a solo project — I'm the only person with access to the database and hosting infrastructure. The app also has an internal "moderator" role used only for reviewing new tag requests; right now, that's me too.

No system is perfectly secure and we cannot guarantee absolute security. If a breach affects your personal information, we will notify you as required by applicable law.

## 09 · Children's privacy

Studease is intended for users aged 17 and older and is not directed to children under 13. We do not knowingly collect personal information from anyone under 13. If we learn that we have, we delete it promptly. A parent or guardian who believes their child has provided us information may contact matthewswift369@gmail.com.

## 10 · Where your data is processed

Studease is operated in the United States: the application server runs on Fly.io, and the database runs on Neon, both on U.S. infrastructure. The Service is intended for users in the United States and is not directed to individuals in the European Economic Area or the United Kingdom.

## 11 · Changes to this policy

We may update this policy as Studease changes. When we do, we revise the "Last updated" date above. Studease doesn't currently have a way to notify you directly — no push notifications, no account emails beyond sign-in — so please check back here occasionally. Continued use of Studease after a change takes effect means you accept the updated policy.

## 12 · Contact us

Matthew Swift
matthewswift369@gmail.com

------------------------------------------------------------------------

*This policy was written to match Studease's actual code as of August 31, 2026. It isn't legal advice. If Studease ever adds features like public profiles, a following system, analytics, or ads, this policy needs to be updated to match before that ships.*
