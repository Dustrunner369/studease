# Mobile app (Flutter)

How `app-frontend/mobile` is put together: screens, navigation, the design system, and
the client-only behavior that never crosses the wire. For what *does* cross the wire,
see [api-contracts.md](api-contracts.md); for the auth build specifically, see
[auth-plan.md](auth-plan.md). This file is about how the client is structured, not the
contract it's written against.

## Structure

```
lib/
  main.dart                                  entrypoint, StudySpotApp, SpotsPage, spot
                                              detail sheet, CleanBottomNav
  router.dart                                empty, unused — go_router is deferred
                                              until the Map/Profile tabs need it
  models/                                    spot.dart, me.dart, label.dart, visit.dart
  services/
    api_service.dart                         every HTTP call, token attachment, retry
    auth_controller.dart                     AuthController, AuthPhase
  design/
    theme.dart                               Hallmark tokens: color, type, spacing, motion
    illustrations.dart                       hand-drawn illustration widgets
    motion_widgets.dart                      PressScale, RevealOnce
  features/
    authentication/presentation/             login_page.dart, choose_handle_page.dart
    profile/presentation/                    profile_page.dart
    study_spots/presentation/                add_spot_sheet.dart, tag_picker_page.dart,
                                              log_visit_sheet.dart, past_visits_sheet.dart
```

## Navigation

Two real tabs, via `CleanBottomNav` in `main.dart`: **Spots** (`SpotsPage`, index 0) and
**Profile** (`ProfilePage`, index 1). **No Map tab exists in this codebase.** Everything
else is a screen pushed on top, or a modal sheet:

- `LoginPage` — sign-in/sign-up, shown for a signed-out or unregistered boot state.
  Has a "Continue with Google" button (built 2026-08-23) alongside email/password.
- `VerifyEmailPage` — gates handle selection for a `password`-provider account until
  its emailed link is clicked. Built 2026-08-23; see "Boot and auth state" below.
- `ChooseHandlePage` — registration. Reached two ways; see "Boot and auth state" below.
- `AddSpotSheet` (`showAddSpotSheet`) — modal, dual **add** and **edit** mode (see
  "Client-only features").
- `TagPickerPage` — modal, opened from `AddSpotSheet`.
- `SpotDetailSheet` — modal, opened from a row on the Spots tab.
- `LogVisitSheet` (`showLogVisitSheet`) / `PastVisitsSheet` (`showPastVisitsSheet`) —
  modals opened from `SpotDetailSheet`'s "Log a visit" / "Past visits" buttons. See
  [api-contracts.md](api-contracts.md) § Visits (D12).

## Boot and auth state

`AuthController` (`auth_controller.dart`) exposes `AuthPhase`: `loading`, `ready`,
`needsRegistration`, `needsEmailVerification`, `error`. `StudySpotApp`'s root
`ListenableBuilder` in `main.dart` switches on it directly — there's no separate router
for this, `MaterialApp.home` just swaps widgets as the phase changes:

| Phase | Screen |
| --- | --- |
| `loading` | `_BootSplash` (shows `CafeShelfSketch` above the wordmark) |
| `error` | `_BootError` |
| `needsRegistration` | `ChooseHandlePage`, as the **root** screen |
| `needsEmailVerification` | `VerifyEmailPage`, as the **root** screen |
| `ready` | `SpotsPage` |

`needsEmailVerification` (**built 2026-08-23**) only fires for the `password`
provider — a Google identity arrives with `emailVerified: true` already and skips it
entirely. `bootstrap()` checks `emailVerified` before ever calling `GET /me`, so a
cached unverified session can't skip ahead to `ChooseHandlePage`. `VerifyEmailPage`
polls Firebase every 5s (`user.reload()` + `emailVerified`) so clicking the emailed
link is normally enough on its own, plus a manual check button, a resend action, and a
sign-out escape hatch. See [auth-plan.md § Email
verification](auth-plan.md#email-verification-built-2026-08-23) for the full design,
including a same-day bug fix worth knowing: `GET /me` succeeding does **not** mean
registered, because a guest linking a credential always gets a `200` back for its
existing throwaway row — the phase transition out of `needsEmailVerification` branches
on `me!.isGuest`, not on whether `fetchMe()` throws. `ProfilePage` has a permanent
`_FinishSetupPrompt` escape hatch for any account that ends up `isGuest: true` with an
already-non-anonymous Firebase user (e.g. the app was killed between verifying and
picking a handle) — sign-up and sign-in are both dead ends from that state.

`ChooseHandlePage` is reachable two ways, and it has to behave correctly in both:

1. **Pushed** from `LoginPage`, after a guest links a real credential (or a stray
   direct sign-up circles back to `needsRegistration` mid-flow) — there's a screen
   underneath to pop back to.
2. **Booted straight into it**, as the app's root screen, when `bootstrap()` itself
   gets `ApiException.needsRegistration` from `GET /me` — a real, non-anonymous
   Firebase identity with a valid token but no `users` row (most concretely: a device
   holding a cached session that outlived a database reset). **Built 2026-08-23.**
   Before this, any `GET /me` failure at boot fell into the generic `error` phase.

`ChooseHandlePage.onSave` pops only `if (Navigator.of(context).canPop())` — in case 2
there's nothing to pop; the root `ListenableBuilder` swaps the screen out on its own
once `completeRegistration()` flips `phase` to `ready`. See
[auth-plan.md § Client state](auth-plan.md#client-state-refined-2026-08-23) for the
full account of why this state exists.

## Design system

`theme.dart`'s header is the Hallmark route line: *route: custom (tuned) · vibe: cozy
coffee shop, hand-drawn, warm*. Rebuilt 2026-08-06 — this replaced an earlier
teal/amber/coral Material 3 palette from the app's previous redesign pass; don't
resurrect that one.

**Palette** (`Tone`, paper `#EAE0C8` from the user's own reference, not generated):

| Token | Value | Use |
| --- | --- | --- |
| `Tone.bg` | `#EAE0C8` | Cream paper, scaffold background |
| `Tone.field` | `#DED1AC` | One elevation step down: cards, fields, chips |
| `Tone.ink` | `#2B2318` | Warm coffee-brown ink — never near-black |
| `Tone.muted` | `#7D7259` | Secondary text, warm taupe — never neutral gray |
| `Tone.line` | `#D6C7A1` | Hairline dividers |
| `Tone.terracotta` | `#BC6B47` | Primary warm accent — CTAs, "great" |
| `Tone.slate` | `#708090` | Cool secondary accent |
| `Tone.sage` | `#838C67` | Muted botanical third accent |
| `Tone.error` | `#9B4A2C` | Destructive/error — deliberately split from the accent trio |

`scoreColor`/`Level` bucket ratings and scores into this same palette (sage/terracotta/
rust), not a generic green/amber/red.

**Typography**: Fraunces (via `google_fonts`) for everything, weight-differentiated
instead of paired with a second family — headings heavy, body light — which keeps a
consistent "handwritten warmth" instead of splitting the app across two typefaces.
Pacifico is the one deliberate outlier, wordmark-only (`AppText.wordmark`), and is a
placeholder until a purchased script font replaces it.

**Spacing**: `Space.*`, a 4pt scale — the mobile-scoped subset of Hallmark's nine
steps (the two largest don't come up on a phone screen).

**Motion**: `Motion.*` durations and cubic-bezier curves (Hallmark's exact values, not
Flutter's `Curves` presets), animating transform/opacity only. `PressScale` and
`RevealOnce` in `motion_widgets.dart` are the two shared motion primitives —
scale-on-press instead of a Material ripple, and a once-per-element fade/rise for a
staggered page-load reveal.

**Rollout is intentionally partial**: colors and type apply app-wide for free, but the
structural/motion rebuild itself is scoped to the Spots tab and its detail sheet first.
Other screens picked up the new palette and font but haven't had a structural pass yet
— check the individual screen before assuming it fully reflects this system.

`theme.dart`'s header line names the design skill this app is styled with (Hallmark).
Most of that skill is CSS/web-specific and doesn't apply to a Flutter app at all — no
OKLCH tokens, no nav/footer/page archetypes, no `:focus-visible`. What does carry over:
typography, color, spacing, and motion discipline; the anti-patterns list; 8-state
interaction coverage; the app-scope brief doesn't map to either of the skill's two
routes (page or component), so surfaces are picked explicitly rather than letting the
page-level apparatus run.

## Illustration system

`illustrations.dart` was built as a `Widget`-based placeholder layer specifically so
real art could drop in later without touching call sites (see the file's own
docstring). Real hand-drawn PNGs landed 2026-08-23 in `assets/illustrations/`
(registered as a whole-directory asset in `pubspec.yaml`). They're flat black ink on
transparent; a shared `_AssetSketch` helper recolors them at render time via
`ColorFilter.mode(color, BlendMode.srcIn)`, so each call site gets whichever `Tone` it
passes instead of mismatched black clipart.

| Widget | Asset | Call site |
| --- | --- | --- |
| `CoffeeCupSketch` | `coffeeWithSteam.png` | `LoginPage` header |
| `CoffeeOnBooksSketch` | `coffeeOnBooks.png` | Spots tab empty state (`Tone.muted`) |
| `CafeShelfSketch` | `coffeeTable.png` | `_BootSplash`, above the wordmark |
| `MokaPotSketch` | *none* — still `CustomPaint` | no current call site |

`MokaPotSketch` is the one holdout: a hand-wobbled `CustomPainter` line drawing (small
coordinate jitter on purpose, so it doesn't read as machine-perfect), with no asset
provided yet. Its call site (the Spots tab empty state) was removed 2026-08-17, before
any of the real PNGs existed — that slot sat with no illustration at all until
`CoffeeOnBooksSketch` took it over on 2026-08-23.

## Client-only features

None of these have a wire shape — they're pure client behavior. See
[api-contracts.md](api-contracts.md) for what actually crosses the wire.

### Fuzzy search (Spots tab)

The `fuzzy` package (`^0.5.1`, added 2026-08-06/07). `_getVisibleSpots` in `main.dart`
runs it **client-side**, over whatever page of `MySpotListItem`s is already loaded —
there is no server-side search endpoint. It runs *after* the tag filter, so a spot must
already pass the AND-tag-filter before fuzzy matching ever sees it. Weighted keys:
`name` (weight 2), `address` (weight 1), and `tags` joined into one string (weight 1);
`threshold: 0.3`, `tokenize` and `findAllMatches` both on.

### Directions button

`url_launcher` (`^6.3.2`, added 2026-08-07 alongside the edit button). `_openDirections`
in `SpotDetailSheet` builds a platform-specific maps deep link from the spot's address
text — `maps.apple.com/?daddr=` on iOS, a Google Maps `dir` URL elsewhere — and launches
it externally, so the person's default map app opens with no picker. It refuses (shows
a toast) when the spot has no address, rather than falling back to a name-only Maps
search: `MySpotListItem` doesn't carry `googlePlaceId`, and a name-only search could
route to the wrong place that happens to share the name.

### Edit spot button

Reuses `AddSpotSheet` in edit mode (`existing: spot`) — same fields, same save path,
pre-filled from the row's `MySpotListItem`. Saving calls `updateSpot()`
(`PUT /spots/{id}`, corrects the shared spot's own name/address) and then the ordinary
entry upsert (`PUT /spots/{id}/entry`, saves ratings/tags/notes) — see
[api-contracts.md](api-contracts.md). Never touches `googlePlaceId` or coordinates,
same restriction the endpoint itself enforces.

## Dependencies worth knowing the status of

- **`google_sign_in: ^7.2.0`** — provider call **built 2026-08-23**.
  `GoogleSignIn.instance.initialize()` runs once in `main()`, awaited before
  `runApp` (required by the 7.x contract: initialize exactly once, before any other
  call — a breaking rewrite of the old `GoogleSignIn()`/`signIn()` API, so most
  tutorials and generated snippets are still 6.x and won't compile). `LoginPage`'s
  "Continue with Google" calls `AuthController.signInWithGoogle()`, which links from a
  guest session the same way `signUpWithEmail` does. **Not yet verified end-to-end on
  a real device** — native config was in place as of 2026-08-06, but nothing in the
  repo can confirm the Firebase-console side actually works; the simulator hides
  SHA-1/URL-scheme problems that only show up on a real Android device and iPhone.
- **`router.dart`** is an empty file. `go_router` is deferred until the Map and Profile
  tabs need declarative routing — see [auth-plan.md](auth-plan.md) § State.

## Known gaps

- `MokaPotSketch` has no illustration asset and no current call site.
- The structural/motion design rebuild hasn't reached every screen — see "Rollout is
  intentionally partial" above.
- No Map tab exists in this codebase, only Spots and Profile.
- Google Sign-In has never been exercised on a real device (see above).
- Password reset is not built — [auth-plan.md](auth-plan.md) Phase 4/5.
