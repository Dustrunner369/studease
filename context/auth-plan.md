# Authentication plan

How a person becomes a `users` row, and how the API knows which row is calling.

This is a **plan, not a record** — nothing here is built yet. It resolves "Still open #1"
in [README.md](README.md). See [data-model.md](data-model.md) for the `users` table and
[api-contracts.md](api-contracts.md) for the wire shapes it plugs into.

> **Decided (2026-08-06): Firebase Auth, with email/password and Google Sign-In.**
> Sign in with Apple is **not** in scope — see [Apple is out of scope](#apple-is-out-of-scope)
> for the App Store condition that would force a revisit.
>
> **Built (2026-08-06): Phases 1-3, plus guest mode** (an addition to this plan, not in
> the original design below — see [Guest mode](#guest-mode-built-2026-08-06)). Every
> endpoint requires a valid Firebase token, `GET`/`POST /me` exist, and the Flutter app
> signs in with email/password. Google Sign-In (Phase 4) and hardening (Phase 5) are
> still open.
>
> **Refined 2026-08-23:** the "authenticated, unregistered" state in the table below is
> now modeled explicitly on the client as `AuthPhase.needsRegistration`, not just
> inferred at the `LoginPage` push site — see [Client state](#client-state-refined-2026-08-23).

## Where we are today

`AppDbContext.DevUserId` (`00000000-0000-0000-0000-0000000000d5`) is hardcoded in
`Program.cs:52`, and every endpoint acts as that user. There is no `Authorization` header,
no `[Authorize]`, and no way for a second person to use the app. Everything else —
`users`, the `(auth_provider, auth_subject)` unique index, the seeded dev row — is already
in place and waiting.

`api-contracts.md` already *specifies* the answer:

> **Auth**: `Authorization: Bearer <token>`; the API resolves the caller from
> `(auth_provider, auth_subject)`. Endpoints under `/me` are caller-scoped.

So this isn't a design from scratch. It's implementing a contract that's already written,
plus the one piece that contract doesn't cover: **where the token comes from**.

## Decision A1 — Firebase Authentication ✅

**Decided: Firebase Auth**, with **email/password and Google Sign-In** as the two providers
at launch. The API validates Firebase-issued ID tokens as ordinary OIDC JWTs and stores
`auth_provider = 'firebase'`, `auth_subject = <firebase uid>`.

The table below is kept as the record of what was weighed, not as a live question.

| Option | Flutter DX | Backend work | Cost | Verdict |
| --- | --- | --- | --- | --- |
| **Firebase Auth** | First-class. `firebase_auth` handles Google, Apple, email/password, refresh, persistence | One `AddJwtBearer` block | Free to 50k MAU | **Chosen** |
| Auth0 | Good (`auth0_flutter`), but you wire the callback scheme yourself | Same `AddJwtBearer` block | Free to 25k MAU | Fine alternative; more setup, better if you later need enterprise SSO |
| Supabase Auth | Decent SDK | Same, HS256 shared secret | Free tier | Drags in a second Postgres you don't need. No |
| ASP.NET Core Identity | You build every screen | You own password hashing, email verification, reset emails, refresh-token rotation, revocation | Free | **No** — see below |

### Why not ASP.NET Core Identity

It's the only option where a password hash lands in *your* database, and the model comment
on `User.cs:3` says the opposite: *"Identity comes from an external provider — no passwords
are stored here."* Choosing Identity means rewriting the users table, and then owning
password reset emails (so, an SMTP provider), email verification, breach-response, refresh
token rotation, and lockout policy — for a solo project whose actual feature backlog is
follows, photos, and an activity feed. The security surface you'd be taking on is the one
part of this app where getting it wrong is not recoverable.

### Why Firebase over Auth0

The app is Flutter-first and mobile-first. `firebase_auth` persists and silently refreshes
the ID token across app restarts, which removes the entire "where do I store the token"
question from the client — no `flutter_secure_storage`, no manual refresh timer, no
keychain code. Google and Apple sign-in are one provider call each. Auth0 gets you the
same JWT, but you configure custom URL schemes per platform to get it.

The lock-in is shallow either way: everything below depends on *"a bearer JWT with a stable
`sub`"*, so swapping providers means changing an issuer string and back-filling
`auth_provider`.

## Decision A2 — sign-in and registration are two different steps

This is the part that needs deciding before any code is written.

A valid Firebase token proves *someone owns an email address or a Google account*. It does
not produce a `handle` or a `displayName`, and both are `required` and `NOT NULL` on
`users`, with `handle` additionally unique. So a first-time caller arrives holding a
perfectly valid token for which **no `users` row can be auto-created**.

Two ways out:

1. **Auto-provision.** Derive a handle from the email (`matthewswift369@gmail.com` →
   `matthewswift369`), append digits on collision. Zero friction, but it hands people a
   public `@name` they didn't choose in a social app, leaks the email local-part, and needs
   collision retry logic anyway.
2. **Explicit registration.** The token gets you authenticated; a separate call creates the
   row with a handle the user picked.

**Take option 2.** Handles are public and permanent-ish in a social app — people should
choose them. It also makes the client's state machine honest, and it keeps the door open to
adding Apple later without redesigning onboarding (see below).

So every client is in exactly one of three states:

| State | How the client knows | What it shows |
| --- | --- | --- |
| **Signed out** | `FirebaseAuth.currentUser == null` | Sign-in screen |
| **Authenticated, unregistered** | Token valid, `GET /me` → `404` | "Pick your handle" onboarding |
| **Registered** | `GET /me` → `200` | The app |

The middle state is the one that gets forgotten and then causes a blank screen on a fresh
install. Model it explicitly from the start.

### Client state (refined 2026-08-23)

The middle row above is now a real, named `AuthController` state —
`AuthPhase.needsRegistration` — not just something `LoginPage` inferred locally. Before
this, `bootstrap()` treated *any* failure from `GET /me` as `AuthPhase.error`, which
meant the one client-visible symptom of "valid token, no `users` row" *at boot* (as
opposed to right after a guest links a credential, which `LoginPage` already handled)
was a generic error screen instead of the handle picker. That gap is real, not
hypothetical: a device holding a cached, non-anonymous Firebase session whose backing
`users` row was deleted — a database reset during development, most concretely — hits
it on the very next launch.

`main.dart`'s root `ListenableBuilder` now has a fourth branch,
`AuthPhase.needsRegistration => ChooseHandlePage(auth: auth)`, shown as the app's root
screen rather than pushed onto a navigator. `ChooseHandlePage.onSave` accounts for
both entry points — pushed (pop back to `LoginPage`) or booted straight into (nothing
to pop; the `ListenableBuilder` swaps the screen out on its own once
`completeRegistration()` flips `phase` to `ready`) — by popping only
`if (Navigator.of(context).canPop())`.

## Guest mode (built 2026-08-06)

An addition to this plan, not in the original design above: the app is usable with no
sign-in at all. Nobody sees a sign-in wall — on first launch the Flutter client calls
`FirebaseAuth.instance.signInAnonymously()` automatically, before the user has done
anything. That anonymous session gets a real Firebase ID token like any other, so it
authenticates against the API exactly the same way a registered user's does.

**This doesn't contradict Decision A2.** A guest still gets no `handle`/`displayName`
until they explicitly choose one — the difference is the backend auto-provisions a
*throwaway* `users` row (`CurrentUser.GetAsync` in `Program.cs`, handle
`guest_xxxxxxxx`, `is_guest = true`) so a guest can use `/spots` and `/me/spots` at all,
since `spot_entries.user_id` is a required FK. Nothing about that row is meant to be
permanent or public-facing; `POST /me` still requires an explicit, chosen handle before
`is_guest` flips to `false`.

**The upgrade is free because Firebase account linking preserves the uid.** Creating a
real account calls `currentUser.linkWithCredential(...)` rather than a fresh sign-up
call. Firebase attaches the new credential to the *same* Firebase user, so
`(auth_provider, auth_subject)` — the backend's login key — never changes. The guest's
`users` row isn't replaced, just updated: `POST /me` finds the existing row via that
same key and overwrites the throwaway handle with the real one. Every spot the guest
already rated is already attached to that row's id, so nothing needs migrating.

**Guests are capped at 3 spot entries** (`GuestEntryLimit` in `Program.cs`), enforced in
`PUT /spots/{id}/entry`: only a *new* entry counts against it, re-rating a spot already
rated never does. Past the cap the endpoint returns `403` with problem type
`entry-limit-reached` (see [api-contracts.md](api-contracts.md)); the Flutter client
catches that specifically and offers account creation rather than showing a generic
error.

**Signing in to an existing account (not signing up) abandons the guest session.**
`signInWithEmailAndPassword` can't link — Firebase rejects linking a credential that
already belongs to another account — so a returning user's guest spots from *that*
install are left behind under an anonymous uid nobody can reach again. Accepted
tradeoff: Firebase has no "merge two accounts" operation, and someone signing in
already has their own history to return to. Same logic applies after `signOut()`, which
starts a brand new anonymous session from zero.

**What guest mode does *not* do:** no local/offline entry counting — the cap is
enforced server-side, from the actual row count, every time. A guest who reinstalls the
app gets a new anonymous uid and a fresh cap; that's an accepted gap, not a bug to
engineer around.

### Apple is out of scope

**Decided: email/password and Google only.** Sign in with Apple is not being built.

Nothing in the design depends on that choice — `(auth_provider, auth_subject)` treats every
Firebase provider identically, and adding Apple later is one provider call in the client
plus a capability in Xcode. It is a deferral, not a door closing.

**The one condition that forces a revisit: shipping to the iOS App Store.** Guideline 4.8
says an app that offers a third-party or social login for the *primary* account must also
offer an alternative that limits collection to name and email, **lets the user keep their
email address private**, and doesn't collect interactions for advertising without consent.
Sign in with Apple satisfies this by construction. Whether a plain email/password signup
satisfies it is genuinely unsettled — it collects only an email, but it offers no masking
equivalent to Apple's relay, and reviewers are inconsistent on whether that counts.

So this is a **live risk carried knowingly**, not a solved problem:

- **Android-only, or TestFlight-internal** → no exposure. 4.8 is enforced at App Store review.
- **Public App Store release with Google sign-in enabled** → assume Apple may be required.
  Budget the $99/yr developer account and roughly a day of work, and don't discover it in
  the rejection email.

Two Apple-specific facts worth keeping, because they're expensive to learn late and they
shape onboarding if Apple is ever added:

- Sign in with Apple returns the user's name **only on the very first authorization, ever**.
  Reinstall and sign in again and `givenName`/`familyName` come back null. Apps that
  auto-provision a display name from that payload get exactly one shot at it. Asking for the
  display name in onboarding (decision A2 above) means we never depend on it — which is why
  A2 is worth keeping even though Apple is out today.
- "Hide My Email" hands out `@privaterelay.appleid.com` proxy addresses — real and
  deliverable, but not the person's email.

That second point generalises past Apple and holds right now: `users.email` is nullable and
is **display/convenience only** — never a lookup key, never a merge key. Google account
emails change too.

## Wire contract

To be folded into [api-contracts.md](api-contracts.md) once agreed (that file is being
edited elsewhere right now — don't write these in from here).

**Every** endpoint requires `Authorization: Bearer <firebase-id-token>`. Missing or invalid
token → `401` with problem+json. Valid token, no `users` row → `403` with
`type: "https://studease.app/problems/registration-required"` on everything except the
registration endpoints themselves.

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/me` | `200` with the caller's `UserSummary` + counts, or **`404`** if authenticated but not yet registered. The client's boot call. |
| `POST` | `/me` | Completes registration. Body `{ "handle": "matt", "displayName": "Matthew" }`. `201` on success, `409` if the handle is taken, `422` if malformed, `409` if this identity already has a row. |
| `GET` | `/users/handle-available?handle=matt` | `{ "available": true }`. Advisory only — `POST /me` is the real arbiter, because two people can pass this check simultaneously. |
| `PATCH` | `/me` | Edit `displayName`, `bio`, `isPrivate`. (Handle changes: decide later, they break `@mentions`.) |
| `DELETE` | `/me` | Soft delete — sets `deleted_at`. Entries cascade, added spots survive with `added_by → NULL`, per data-model.md. Must also delete the Firebase user, or the person can't re-register with that identity. |

`GET /me` returning `404` rather than a `200` with `{"registered": false}` is deliberate:
the endpoint means "the caller's user record", and there isn't one. Clients already treat
non-2xx as an exception (`api_service.dart:129`), so this is one explicit branch rather
than a truthy field everyone forgets to check.

### Handle rules

- `^[a-z0-9_]{3,30}$`, **stored lowercased**. The API lowercases before insert; the unique
  index does the rest. `@Matt` and `@matt` are the same person (`User.cs:9`).
- A reserved list, rejected at registration: `me`, `admin`, `api`, `spots`, `places`,
  `feed`, `users`, `photos`, `support`, `help`, `settings`, `about`. `GET /users/{handle}`
  shares a URL space with `/me`, so a user called `me` is a routing bug waiting to happen.

> **Drift, found while writing this.** `schema.sql:31` declares
> `CONSTRAINT users_handle_format CHECK (handle ~ '^[a-zA-Z0-9_]{3,30}$')`, but
> `AppDbContext.OnModelCreating` never configures it and the
> `ReplaceStudySpotsWithSpotsAndEntries` migration never created it. **The real database has
> no handle format check at all.** Per README ("when the code and these docs disagree, one
> of them is a bug"), fix both together: add the constraint to the EF model in the auth
> migration, and tighten the pattern to `^[a-z0-9_]{3,30}$` so the database enforces the
> lowercasing the model comment claims. Uppercase-permitting is what lets a direct SQL
> insert quietly break case-insensitive uniqueness.

## Backend

### Packages

```
Microsoft.AspNetCore.Authentication.JwtBearer  9.0.6   (match the other 9.0.6 pins)
```

That's it. No Firebase Admin SDK — verifying an ID token is plain OIDC, and the Admin SDK
would need a service-account key file, which is a secret you'd then have to manage. Only
reach for it if you later need to *revoke* sessions server-side or mint custom claims.

### Wiring (`Program.cs`)

```csharp
var firebaseProject = builder.Configuration["Auth:FirebaseProjectId"];

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        // Firebase publishes an OIDC discovery document here, so JwtBearer fetches and
        // caches the signing keys itself and rotates them without a restart.
        options.Authority = $"https://securetoken.google.com/{firebaseProject}";
        options.Audience  = firebaseProject;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = $"https://securetoken.google.com/{firebaseProject}",
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            // Default is 5 minutes of slop. Tokens last an hour and the SDK refreshes
            // them; a phone with a wrong clock is the client's problem, not ours.
            ClockSkew = TimeSpan.FromSeconds(30),
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddScoped<CurrentUser>();
```

Then, after `app.UseCors()`:

```csharp
app.UseAuthentication();
app.UseAuthorization();
```

Order matters, and CORS must come first.

### Resolving the caller

Replace `var currentUserId = AppDbContext.DevUserId;` with a scoped service. Every endpoint
that reads `currentUserId` today (`POST /spots`, `GET /me/spots`, `GET /spots/{id}`,
`PUT`/`DELETE /spots/{id}/entry`, and `ToDetailDto`) takes `CurrentUser` as a parameter
instead — minimal-API DI injects it by type.

```csharp
// Resolves the JWT's (provider, subject) to a users row, once per request.
public class CurrentUser(IHttpContextAccessor accessor, AppDbContext db)
{
    private const string Provider = "firebase";
    private User? _cached;

    public string Subject => accessor.HttpContext!.User.FindFirstValue("user_id")
                          ?? accessor.HttpContext!.User.FindFirstValue(ClaimTypes.NameIdentifier)!;

    public string? Email => accessor.HttpContext!.User.FindFirstValue(ClaimTypes.Email);

    /// The users row, or null when this identity hasn't registered yet.
    public async Task<User?> GetAsync(CancellationToken ct) => _cached ??= await db.Users
        .FirstOrDefaultAsync(u => u.AuthProvider == Provider
                              && u.AuthSubject == Subject
                              && u.DeletedAt == null, ct);

    /// For endpoints that already ran RequireRegistered().
    public async Task<Guid> IdAsync(CancellationToken ct) =>
        (await GetAsync(ct))!.Id;
}
```

Needs `builder.Services.AddHttpContextAccessor()`.

Firebase puts the uid in both `sub` and a `user_id` claim; JwtBearer maps `sub` to
`ClaimTypes.NameIdentifier` by default, hence the fallback. Verify which one you actually
get before trusting either — print the claims once on the first real token.

The "registered?" check belongs in an **endpoint filter**, not repeated in every handler:

```csharp
// .AddEndpointFilter<RequireRegisteredFilter>() on the group; returns 403 +
// registration-required when the token is fine but no users row exists yet.
```

Apply it to a route group covering everything except `GET /me`, `POST /me`, and
`GET /users/handle-available`.

### Locking the endpoints

`app.MapGroup("").RequireAuthorization()` over everything, including
**`GET /places/search`**. That one is easy to leave open because it looks like a read, but
it proxies a *metered* Google API — an unauthenticated autocomplete endpoint on a public
host is someone else's free Places quota, billed to you. It is the single most expensive
thing in this codebase to leave unauthenticated.

Add rate limiting (`AddRateLimiter`, built into ASP.NET Core 9) on `POST /me` and
`GET /users/handle-available` — handle enumeration and registration spam are the two
endpoints worth bounding.

### Keeping local development working

Requiring a real Firebase token to `curl` the API would make development miserable, and
would break the Angular app and the `.http` file immediately. So keep a bypass, fenced hard:

```csharp
// Dev only, and only when explicitly asked for. Two conditions, not one: an env var
// alone must never be enough to disable auth on a deployed instance.
var devAuth = builder.Environment.IsDevelopment()
           && builder.Configuration.GetValue<bool>("Auth:AllowDevBypass");
```

When on, register a second authentication scheme whose handler emits a fixed identity for
`DevUserId` (`auth_provider = 'dev'`, `auth_subject = 'local'` — exactly the seeded row), and
make it the default. When off, there is no code path that produces an identity without a
validated token. Log a loud warning at startup when the bypass is active.

`appsettings.json` gains:

```json
"Auth": {
  "FirebaseProjectId": "",
  "AllowDevBypass": true
}
```

The project ID is not a secret. It ships in the client anyway.

## Flutter

### Packages

```yaml
firebase_core: ^4.13.0   # already added
firebase_auth: ^6.5.7    # already added
google_sign_in: ^7.x     # still to add
```

No `sign_in_with_apple` — see [Apple is out of scope](#apple-is-out-of-scope). Add it only
if App Store review forces the issue.

Pin the versions `flutter pub add` actually resolves — the Firebase plugins move fast and
must be mutually compatible; take whatever `firebase_core` pulls in rather than pinning by
hand.

> **`google_sign_in` 7.x is a breaking rewrite.** The old `GoogleSignIn()` constructor plus
> `signIn()` is gone, replaced by an `initialize()` call and `authenticate()`. Most tutorials
> and most model-generated snippets are still 6.x and will not compile. Read the migration
> notes before writing the provider call, not after.

**Not** `flutter_secure_storage`. `firebase_auth` already persists the refresh token in the
keychain/keystore and refreshes the ID token in the background. Storing tokens yourself
here would be strictly worse code that does the same job.

### State

There is no state-management package in this project and `lib/router.dart` is **empty**.
Don't fix both problems at once. Smallest thing that works:

```dart
// lib/services/auth_controller.dart
enum AuthState { loading, signedOut, unregistered, ready }

class AuthController extends ChangeNotifier {
  AuthState state = AuthState.loading;
  UserSummary? me;
  // Listens to FirebaseAuth.authStateChanges(); on a non-null user, calls GET /me and
  // resolves to unregistered (404) or ready (200).
}
```

Drive it with a `ListenableBuilder` at the root — no new dependency, and it's a
`ChangeNotifier` either way if you later add `provider` or Riverpod.

`main.dart` swaps `home: const SpotsPage()` for an auth gate that switches on
`AuthState`. Leave `go_router` for whenever the Map and Profile tabs become real; adding
declarative routing and auth in the same change means debugging two new things at once.

**Built as `AuthPhase`, not `AuthState`** — `loading | ready | needsRegistration |
error` (the last two named differently than this sketch's `unregistered`/`signedOut`,
and `needsRegistration` added later, see [Client
state](#client-state-refined-2026-08-23)). The `go_router` deferral turned out to be
open-ended rather than "until the Map tab": **there is no Map tab in this app** — see
[mobile-app.md](mobile-app.md) — and Profile shipped as a real screen in this same
phase, not deferred. `router.dart` is still empty as of 2026-08-23.

### Attaching the token

`api_service.dart` funnels every call through `_send`, which is lucky — the change is
contained. Today `_jsonHeaders` is a `const`; it has to become per-request and async:

```dart
Future<Map<String, String>> _headers() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
```

`getIdToken()` returns the cached token and only hits the network when it's near expiry, so
awaiting it per request is cheap. On a `401`, retry **once** with `getIdToken(true)` to
force a refresh; if that also fails, sign out and let the gate show the sign-in screen. Put
that retry inside `_send` so no call site has to think about it.

`ApiException` grows a companion to `isPlacesUnavailable`:

```dart
bool get needsRegistration => problemType == _registrationRequiredType;
```

**Built as `problemType`, not a bare status check** — the real implementation matches
the RFC 9457 `type` string, because `GET /me`'s `404` and `RequireRegisteredFilter`'s
`403` both carry `registration-required` for the identical condition (see
[api-contracts.md](api-contracts.md)); a bare status-code check would miss one of them.

### Screens

Four new surfaces, all currently missing:

1. **Sign in** — Continue with Google, and email + password, plus a link to sign up and one
   to reset the password. No Apple button.
2. **Sign up (email)** — email, password, confirm. Firebase enforces password strength; show
   its error messages rather than inventing your own rules.
3. **Choose your handle** — handle + display name, with live availability from
   `GET /users/handle-available` (debounced ~400ms), then `POST /me`. This is the
   `unregistered` state and the *only* screen shown in it.
4. **Profile tab** — currently a dead nav item (`main.dart:987`). Becomes: avatar, handle,
   display name, entry count, sign out, delete account.

Sign out is `FirebaseAuth.instance.signOut()` plus clearing the in-memory spot list. Deleting
an account calls `DELETE /me` **first** (needs a valid token), then
`FirebaseAuth.currentUser!.delete()` — which may throw `requires-recent-login` and need a
re-authentication prompt. That's expected; handle it rather than swallowing it.

### Platform configuration

`flutterfire configure` has already run. `lib/firebase_options.dart`,
`android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` all exist and
are committed, and `main.dart` initialises with `DefaultFirebaseOptions.currentPlatform`.
**Email/password will work today on both platforms with no further setup** — the options are
passed from Dart, so nothing reads the native config files at launch.

Google Sign-In is what needs the rest. Verified state as of 2026-08-06:

| Platform | Needed | State |
| --- | --- | --- |
| Android | `google-services.json`, Gradle plugin, **debug and release SHA-1 fingerprints in the Firebase console** — Google sign-in fails silently without them | File present; SHA-1s **not yet registered** |
| iOS | `GoogleService-Info.plist` **referenced by the Xcode project**, and its `REVERSED_CLIENT_ID` registered as a URL scheme in `Info.plist` | File on disk but **not in `project.pbxproj`**, so it isn't bundled. No `REVERSED_CLIENT_ID` in it, and no `CFBundleURLTypes` in `Info.plist` |
| Both | A real bundle/application ID | Still `com.example.mobile` — the Flutter placeholder, also baked into `firebase_options.dart` as `iosBundleId` |
| Emulator | The Android emulator image must include Play Services or Google sign-in won't launch. `10.0.2.2` (`api_service.dart:18`) still reaches the host API — Firebase itself goes over the public internet and is unaffected | — |

Three consequences worth reading twice:

1. **The plist has no `REVERSED_CLIENT_ID` because Google isn't enabled as a provider yet.**
   Enabling it in the Firebase console creates the OAuth client and changes the file —
   re-download it afterwards, don't hand-edit.
2. **Fix the bundle ID before anything depends on it.** Firebase apps are keyed by bundle ID,
   so changing it later means registering a new iOS app and regenerating both the plist and
   `firebase_options.dart`. `com.example.*` also can't be registered to an Apple Developer
   account, which matters the moment an App Store build is on the table.
3. **Android SHA-1 registration is the classic silent failure.** Google sign-in returns a
   generic cancellation with no useful error when the fingerprint is missing. Register the
   debug keystore's SHA-1 *and* the release one.

`google-services.json` and `GoogleService-Info.plist` are **not secrets** — they're extracted
from any shipped app — so committing them is normal, and all three files are already tracked.
The `apiKey` inside them is a client identifier, not a credential; restrict it by bundle ID
in the Google Cloud console so it can't be reused from another app.

## Angular

Out of scope for this pass. `frontend/` is already broken against the current API —
`study-spot.service.ts` still calls `/studyspots`, which no longer exists — so it needs a
rewrite regardless, and doing it under auth means fixing two things at once. When it comes
back: Firebase JS SDK, same bearer token, same three states, and the production CORS policy
in `Program.cs:22` must list its real origin.

Bearer tokens in a header (not cookies) means **no CSRF exposure**, which is a quiet benefit
of this design worth not throwing away later by moving to cookie auth.

## The dev user's data

Local `appdb` has entries owned by `DevUserId`. Once you sign in as yourself, you get a new
row and an empty Spots tab. Either accept that and re-add a few spots, or re-point the data
once:

```sql
-- After registering for real, with <new-id> from: SELECT id, handle FROM users;
UPDATE spot_entries SET user_id = '<new-id>' WHERE user_id = '00000000-0000-0000-0000-0000000000d5';
UPDATE spots SET added_by = '<new-id>' WHERE added_by = '00000000-0000-0000-0000-0000000000d5';
```

**Keep the seeded dev row.** It's what the dev bypass authenticates as, and deleting it
would cascade away exactly the entries you're trying to keep.

Also still true from README: the local `appdb` carries the old `StudySpots` table and will
trip the `__EFMigrationsHistory` snake_case problem on the next `dotnet ef database update`.
Deal with that *before* adding an auth migration, not during — one broken migration at a
time.

## Build order

Each phase leaves the app working.

**Phase 0 — decide.** ✅ Provider decided (Firebase, email/password + Google). The Firebase
project `swift-study-app` exists and `flutterfire configure` has run. Remaining: enable the
**Email/Password** and **Google** providers in the console, set the one-account-per-email
setting (see Gotchas), and answer the open questions below.

**Phase 1 — backend accepts tokens. ✅ Built 2026-08-06.** JwtBearer, `CurrentUser`,
`AddHttpContextAccessor`, dev bypass on. Replaced every `currentUserId` reference.
*Verified: dev bypass still authenticates as the seeded dev user with no token, and a
garbage bearer token gets a real `401`.*

**Phase 2 — registration. ✅ Built 2026-08-06, expanded.** `GET /me`, `POST /me`, the
`RequireRegisteredFilter`, handle validation + reserved list, and the migration adding
the handle format check (`ck_users_handle_format`). **Not built:**
`GET /users/handle-available` — descoped; the client validates the pattern locally and
handles the `409` from `POST /me` instead. **Added beyond the original plan:** guest
auto-provisioning and the 3-entry cap — see [Guest mode](#guest-mode-built-2026-08-06).

**Phase 3 — Flutter signs in. ✅ Built 2026-08-06.** `AuthController`, the boot-time
auth gate in `main.dart` (`ListenableBuilder` at the root, per this plan), sign-in/sign-up
screens, token attachment and 401 retry in `api_service.dart`. **Email/password only**,
as planned. Went further than "signs in" alone: the app is usable *before* signing in
too — see [Guest mode](#guest-mode-built-2026-08-06). **Expanded 2026-08-23**: the
"authenticated, unregistered" state is now its own `AuthPhase.needsRegistration`
instead of falling into `error` — see [Client state](#client-state-refined-2026-08-23).

**Phase 4 — Google Sign-In.** Native config (Xcode target, URL scheme, Android SHA-1s,
bundle ID) is already done as of 2026-08-06; `google_sign_in` is already a dependency.
What's left: the actual provider call and button — `google_sign_in` 7.x's
`initialize()`/`authenticate()`, not the old `signIn()` — and deciding whether it also
links from a guest session the same way email/password sign-up does. Password reset is
also still open; the onboarding screen, Profile tab, and sign out landed early, in
Phase 3, as part of guest mode. *Done when Google sign-in works on a real Android device
and a real iPhone — the simulator hides SHA-1 and URL-scheme problems.*

**Phase 5 — harden.** Bypass off in every non-development configuration, rate limits,
`DELETE /me`, production CORS origins, and the dev-user data decision above.

## Testing

There is **no test project in this repository at all** — but `Microsoft.EntityFrameworkCore.InMemory`
is already referenced in `study-spot-backend.csproj`, which means someone intended one.
Auth is the right moment: it's the first change where a silent regression means *the wrong
user's data*, not a cosmetic bug.

`backend.Tests` with `WebApplicationFactory<Program>` (needs `public partial class Program {}`
at the bottom of `Program.cs` for minimal APIs) and a `TestAuthHandler` that stamps whatever
claims a test asks for. The cases that matter:

- No token → `401` on every endpoint, including `/places/search`.
- Valid token, no `users` row → `403` registration-required, and `GET /me` → `404`.
- `POST /me` with a taken handle → `409`; with `MATT` → creates `matt`; with `me` → rejected.
- **Two users, one spot**: both `PUT /spots/{id}/entry`; each `GET /me/spots` returns only
  their own row, and `spots.entry_count` is 2. This is decision D2 and the whole point of
  the auth work — it's untestable today.
- Deleting user A's entry leaves user B's intact and the spot alive.
- Soft-deleted user (`deleted_at` set) → treated as unregistered, not as themselves.

## Gotchas

**A valid token is not a user.** The single most likely bug in this whole plan is a handler
that trusts `CurrentUser` to be non-null on a path where the filter didn't run. Keep the
nullable `GetAsync` and the non-null `IdAsync` distinct, and only call `IdAsync` behind the
filter.

**`sub` vs `user_id`.** Firebase sets both. Pick one, write it into `auth_subject`, and never
change your mind — it's the login key, and rewriting it means every existing user is a
stranger.

**Don't key on email.** People change emails, and two providers can hand you the same address
for different accounts. `(auth_provider, auth_subject)` is the key; the schema already says
so.

**Account collision is now the most likely real-world bug**, and choosing email/password +
Google is exactly what creates it. Someone registers with `matt@gmail.com` and a password,
comes back a month later, taps "Continue with Google", and picks the same Gmail account.
Firebase's default is **"one account per email address"**, which makes the second attempt
throw `account-exists-with-different-credential` rather than silently creating a second
identity — so the default is the one you want. Confirm it is actually set in the console
during Phase 0.

Handle that error rather than showing a generic failure: the honest message is *"You already
have an account with this email — sign in with your password, then link Google from your
profile."* Actual credential linking (`linkWithCredential`) is **out of scope for v1**; the
error message is the whole feature for now.

If the setting were ever turned off, you'd get two uids for one human — two `users` rows, two
handles, one confused person, and no way to merge them without a migration you haven't
written.

**Startup migration + auth is a bad combination.** `Program.cs:46` runs `db.Database.Migrate()`
on every boot, with a comment already flagging it as a foot-gun. Once real accounts exist,
that's a container restart away from running a destructive migration against real people's
data. Make it a deliberate step in Phase 5, as the comment says.

**Clock skew on real phones.** A device whose clock is minutes off gets `401`s from a
perfectly good token. The 401-retry-with-refresh path handles the common case; anything
beyond that, show the person a real message rather than a spinner.

## Open questions

**Answered (2026-08-06):**

1. ~~**Firebase confirmed?**~~ **Yes.** Firebase Auth. The project `swift-study-app` is
   created and `flutterfire configure` has run against it.
2. ~~**Which providers at launch?**~~ **Email/password + Google Sign-In.** Apple deferred —
   see [Apple is out of scope](#apple-is-out-of-scope) for the App Store condition that
   would force it back on the list.

**Still open:**

3. **Handle changes — allowed?** Recommendation: not in v1. `@mentions` and shared profile
   links break, and there's no redirect table to fix them.
4. **`is_private` at registration?** The column exists and gates follow approval. Simplest:
   default `false`, expose the toggle on the Profile tab in Phase 4, and let it matter when
   `follows` ships in v2.

**Answered (2026-08-06):**

5. ~~**Real bundle ID — what is it?**~~ **`app.studease.mobile`**, on both platforms.
