# Authentication plan

How a person becomes a `users` row, and how the API knows which row is calling.

This is a **plan, not a record** — nothing here is built yet. It resolves "Still open #1"
in [README.md](README.md). See [data-model.md](data-model.md) for the `users` table and
[api-contracts.md](api-contracts.md) for the wire shapes it plugs into.

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

## Decision A1 — Firebase Authentication

**Recommendation: Firebase Auth.** The API validates Firebase-issued ID tokens as ordinary
OIDC JWTs and stores `auth_provider = 'firebase'`, `auth_subject = <firebase uid>`.

| Option | Flutter DX | Backend work | Cost | Verdict |
| --- | --- | --- | --- | --- |
| **Firebase Auth** | First-class. `firebase_auth` handles Google, Apple, email/password, refresh, persistence | One `AddJwtBearer` block | Free to 50k MAU | **Pick this** |
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

A valid Firebase token proves *someone owns an email or an Apple/Google account*. It does
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
choose them. It also makes the client's state machine honest, and it sidesteps a genuine
Apple gotcha (below) for free.

So every client is in exactly one of three states:

| State | How the client knows | What it shows |
| --- | --- | --- |
| **Signed out** | `FirebaseAuth.currentUser == null` | Sign-in screen |
| **Authenticated, unregistered** | Token valid, `GET /me` → `404` | "Pick your handle" onboarding |
| **Registered** | `GET /me` → `200` | The app |

The middle state is the one that gets forgotten and then causes a blank screen on a fresh
install. Model it explicitly from the start.

### The Apple gotcha this happens to solve

Sign in with Apple returns the user's name **only on the very first authorization, ever** —
reinstall the app, sign in again, and `givenName`/`familyName` come back null. Apps that
auto-provision a display name from the Apple payload get one shot at it. Because we ask for
the display name in onboarding, we never depend on that field.

Related: Apple's "Hide My Email" gives you a `@privaterelay.appleid.com` proxy address. It's
a real, deliverable address, but it isn't the person's email. `users.email` is nullable and
is **display/convenience only** — never a lookup key, never a merge key.

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
firebase_core: ^4.x
firebase_auth: ^6.x
google_sign_in: ^7.x
sign_in_with_apple: ^7.x   # required by App Store guideline 4.8 if you ship Google sign-in
```

Pin the versions `flutter pub add` actually resolves — the Firebase plugins move fast and
must be mutually compatible; take whatever `firebase_core` pulls in rather than pinning by
hand.

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
bool get needsRegistration => statusCode == 403;  // match on the problem `type`, not bare 403
```

### Screens

Four new surfaces, all currently missing:

1. **Sign in** — Continue with Google / Continue with Apple / email + password, plus a link
   to sign up and one to reset the password.
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

| Platform | Needed |
| --- | --- |
| Android | `google-services.json` in `android/app/`, Gradle plugin, **debug and release SHA-1 fingerprints registered in the Firebase console** — Google sign-in fails silently without them |
| iOS | `GoogleService-Info.plist`, reversed-client-id URL scheme in `Info.plist`, Sign in with Apple capability, a paid Apple Developer account |
| Emulator | The Android emulator image must include Play Services or Google sign-in won't launch. `10.0.2.2` (`api_service.dart:18`) still reaches the host API — Firebase itself goes over the public internet and is unaffected |

`google-services.json` and `GoogleService-Info.plist` are **not secrets** (they're extracted
from any shipped app), so committing them is normal. Check `.gitignore` doesn't already
exclude them by pattern.

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

**Phase 0 — decide.** Answer the open questions below. Create the Firebase project, enable
Google, Apple, and Email/Password providers.

**Phase 1 — backend accepts tokens.** JwtBearer, `CurrentUser`, `AddHttpContextAccessor`,
dev bypass on. Replace every `currentUserId` reference. Nothing else changes: with the
bypass on, the app behaves exactly as it does today. *Done when the existing Flutter app
still works untouched and a real Firebase token also authenticates.*

**Phase 2 — registration.** `GET /me`, `POST /me`, `GET /users/handle-available`, the
`RequireRegistered` filter, handle validation + reserved list, and the migration adding the
handle format check. *Done when a fresh identity can register over curl and immediately
read `/me/spots`.*

**Phase 3 — Flutter signs in.** `firebase_core` + `firebase_auth`, `AuthController`, auth
gate, sign-in screen, token attachment and 401 retry in `api_service.dart`. Email/password
only — one provider at a time. *Done when you sign in on a device and see your spots.*

**Phase 4 — the rest of the client.** Onboarding screen, Google and Apple providers,
Profile tab, sign out, password reset.

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

**Don't key on email.** People change emails, Apple hands out relay addresses, and two
providers can hand you the same address for different accounts. `(auth_provider,
auth_subject)` is the key; the schema already says so.

**Account linking is out of scope.** Sign in with Google, then later with Apple on the same
email, and Firebase gives you two uids — so two `users` rows, two handles, and one confused
person. Firebase's "one account per email address" setting mitigates it. Decide it now,
knowingly, rather than discovering it from a support message.

**Startup migration + auth is a bad combination.** `Program.cs:46` runs `db.Database.Migrate()`
on every boot, with a comment already flagging it as a foot-gun. Once real accounts exist,
that's a container restart away from running a destructive migration against real people's
data. Make it a deliberate step in Phase 5, as the comment says.

**Clock skew on real phones.** A device whose clock is minutes off gets `401`s from a
perfectly good token. The 401-retry-with-refresh path handles the common case; anything
beyond that, show the person a real message rather than a spinner.

## Open questions

These block Phase 0, not the rest of the design:

1. **Firebase confirmed?** If you'd rather not add a Google dependency, Auth0 changes only
   the issuer string and the Flutter package — everything else in this document stands.
2. **Which providers at launch?** Recommendation: email/password + Google in Phase 3–4;
   Apple when there's an iOS build, since it needs the $99 developer account and is only
   *required* once you ship to the App Store with Google sign-in enabled.
3. **Handle changes — allowed?** Recommendation: not in v1. `@mentions` and shared profile
   links break, and there's no redirect table to fix them.
4. **`is_private` at registration?** The column exists and gates follow approval. Simplest:
   default `false`, expose the toggle on the Profile tab in Phase 4, and let it matter when
   `follows` ships in v2.
