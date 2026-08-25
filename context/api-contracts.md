# API contracts

What crosses the wire between the .NET API (`backend/`), the Flutter app
(`app-frontend/mobile/`), and the Angular web app (`frontend/`). These shapes are the
contract; see [data-model.md](data-model.md) for what's behind them.

## Wire conventions

- **camelCase** JSON. `System.Text.Json` does this by default — don't fight it.
- **Ids are strings.** They're uuids. `int` ids are gone.
- **Instants** are ISO-8601 UTC with a `Z`: `"2026-07-25T18:03:11Z"`. Never a local
  timestamp — that ambiguity is what forced the `ChangeOpenUntilTimestamp` migration and
  the "DateTime type didn't work" fix.
- **Times of day** are `"HH:mm"` in the *spot's* local time: `"22:00"`. They are not
  instants and must not be parsed as `DateTime`.
- **Nullable means nullable.** Anything marked `| null` below will be null in practice —
  most importantly `openUntil`. Clients must render without it.
- **Errors** are `application/problem+json` (RFC 9457), which ASP.NET Core produces by
  default. Don't invent a second error shape.
- **Auth**: `Authorization: Bearer <firebase-id-token>` on every endpoint; the API
  resolves the caller from `(auth_provider, auth_subject)`. Endpoints under `/me` are
  caller-scoped. **A guest is still authenticated** — the token comes from Firebase
  anonymous sign-in, which the client starts automatically so nobody sees a sign-in wall.
  See [auth-plan.md](auth-plan.md) for the full design and the guest/registration state
  machine.

## Objects

### `UserSummary`

```json
{
  "id": "018f...",
  "handle": "matt",
  "displayName": "Matthew",
  "avatarUrl": "https://cdn.example/av/018f.jpg"
}
```

### `Me`

**Built.** What `GET`/`POST /me` actually return today — narrower than `UserSummary`
above (no `avatarUrl` yet; that's still v2 aspirational).

```json
{
  "id": "018f...",
  "handle": "guest_3f9a21bc",
  "displayName": "Guest",
  "isGuest": true,
  "entryCount": 2
}
```

`isGuest` is true for an auto-provisioned Firebase anonymous session — no registration
screen was ever shown for it. It flips to `false` the moment `POST /me` runs, which for
a former guest is an **upgrade in place**: Firebase account linking keeps the same uid,
so `entryCount` (and every spot it counts) carries straight over, uncapped from then on.
Guests are capped at 3 entries; see `entry-limit-reached` below.

### `Spot`

Place facts plus cached aggregates. `openUntil`/`isOpenNow` are **not stored** — the API
fetches them from Places while handling the request, so they're absent from list
responses where a per-row lookup would be too expensive.

```json
{
  "id": "018f...",
  "googlePlaceId": "ChIJN1t_tDeuEmsRUsoyG83frY4",
  "name": "Brew & Books",
  "address": "123 Library Lane, Booktown",
  "latitude": 51.5072,
  "longitude": -0.1276,
  "priceLevel": 2,
  "websiteUrl": "https://brewandbooks.example",
  "phone": "+44 20 7123 4567",
  "openUntil": "22:00",
  "isOpenNow": true,
  "hoursUnavailable": false,
  "entryCount": 12,
  "avgScore": 8.4,
  "avgRatings": { "wifi": 4.2, "noise": 3.8, "outlets": 4.5, "seating": 3.9, "tableSize": 4.1, "coffee": 4.4 },
  "tags": [ { "slug": "cozy", "count": 8 }, { "slug": "bestforreading", "count": 3 } ],
  "photos": [ { "id": "018f...", "url": "https://...", "width": 1600, "height": 1200 } ]
}
```

`hoursUnavailable: true` distinguishes "Google has no hours for this place / the lookup
failed" from "closed right now". Show "Hours unknown", not "Closed".

**No `type` field** — removed 2026-08-06 (decision D10), replaced by the standardized
tag system. `tags` here is the **spot-wide aggregate**: how many of the spot's entries
carry each label, from `spot_tag_counts`. Everyone's opinion, not just the caller's —
contrast with `SpotEntry.tags` / `MySpotListItem.tags` below, which are one entry's own
tags. See `### Label`.

### `SpotEntry`

One user's opinion. `score` is computed by the database — **read-only**, never sent by a
client.

```json
{
  "id": "018f...",
  "spotId": "018f...",
  "user": { "id": "018f...", "handle": "matt", "displayName": "Matthew", "avatarUrl": null },
  "ratings": { "wifi": 4, "noise": 5, "outlets": 4, "seating": 4, "tableSize": 4, "coffee": 4 },
  "score": 8.4,
  "groupStudy": true,
  "tags": ["cozy", "bestforreading"],
  "coffeeOrder": "Vanilla latte",
  "notes": "Quiet back room with good lighting.",
  "visibility": "public",
  "photos": [],
  "createdAt": "2026-07-20T14:00:00Z",
  "updatedAt": "2026-07-25T18:03:11Z"
}
```

All six ratings are integers 1–5 and all are required. Every one reads "higher is
better": `noise: 5` means **quiet**, and `tableSize: 5` means **big shared tables**.

`score` is derived from **five** of them — wifi, noise, outlets, seating, coffee. It is
`round((sum) * 0.4, 1)`, which puts five 1–5 ratings at exactly 10.0. `tableSize` is
collected and displayed but deliberately left out: folding in a sixth term would rebase
every score already stored. `groupStudy` is a boolean verdict, never scoreable, and stays
one user's opinion — there is no group-study aggregate on `Spot`.

`tags` is this entry's own labels — a flat array of `slug`s, same "one user's opinion"
status as `groupStudy`. Every slug must name an `approved` `Label` or the write is
rejected; see `### Label` and `PUT /spots/{spotId}/entry` below.

### `MySpotListItem`

The Spots tab's list row — a spot joined to my entry, flattened so the row renders
without a second request. This replaces today's `StudySpot` model in both clients.

```json
{
  "spotId": "018f...",
  "entryId": "018f...",
  "name": "Brew & Books",
  "address": "123 Library Lane, Booktown",
  "score": 8.4,
  "ratings": { "wifi": 4, "noise": 5, "outlets": 4, "seating": 4, "tableSize": 4, "coffee": 4 },
  "groupStudy": true,
  "tags": ["cozy", "bestforreading"],
  "priceLevel": 2,
  "coffeeOrder": "Vanilla latte",
  "notes": "Quiet back room with good lighting.",
  "updatedAt": "2026-07-25T18:03:11Z"
}
```

`coffeeOrder` and `notes` ride along so the detail sheet can open straight from a list
row without a second request. (`thumbnailUrl` will join them when photos land in v3.)

No `openUntil` here on purpose: it would cost a Places call per row. The detail sheet
fetches it. If the list must show "open now", add `?includeHours=true` and accept the
latency, or cache hours server-side for a few minutes.

`tags` is this entry's own labels, same as on `SpotEntry` — what drives the client-side
tag filter on the Spots tab (`_buildFilters` in `main.dart`, options derived from the
tags actually present across the loaded list, AND semantics across selected tags).

### `Visit`

**Built.** "I'm studying here today" — a lightweight log entry, separate from
`SpotEntry` (decision D12). Logging is always an insert, never an edit-in-place — but a
whole row is deletable outright, to undo a mislog (decision D13). `spotName` is
flattened in, same reasoning as `MySpotListItem`, so a list of visits renders without a
request per row.

```json
{
  "id": "018f...",
  "spotId": "018f...",
  "spotName": "Brew & Books",
  "studied": "Organic chemistry",
  "drinkOrder": "Vanilla latte",
  "visitedAt": "2026-08-23T18:03:11Z"
}
```

`studied` and `drinkOrder` are optional, same free-text treatment as `SpotEntry`'s
`notes`/`coffeeOrder`. `visitedAt` is stamped by the server at creation and never
accepted from the client — logging is always "today", not backdated.

### `Label`

**Built.** The standardized, global tag vocabulary that replaced `Spot.type` (decision
D10, 2026-08-06). Modeled on Beli's Labels.

```json
{
  "id": "018f...",
  "slug": "bestforreading",
  "displayName": "Best for reading",
  "status": "approved",
  "polarity": "positive"
}
```

`slug` is normalized: **lowercase alphanumeric only, no separators.** "Best for
reading" becomes `bestforreading` — deliberately not kebab-case, since labels render
as `#slug` everywhere (the picker, filter chips, tag pills), and a hyphen breaks that
the way `#best-for-reading` reads as broken on every platform that has hashtags.

`status` is `pending | approved | rejected`. Only `approved` labels appear from
`GET /labels` or validate as a `tagSlugs` entry on `PUT /spots/{spotId}/entry`. A new
label starts `pending` and needs an admin to approve it — see "Labels & moderation"
below. There is no notification when that happens; the requester finds out by checking
`GET /labels` later, same as anyone else.

`polarity` is `positive | negative`, **`null` until approved** (decision D11,
2026-08-17) — a compliment-vs-complaint read on the tag ("Cozy" vs "Too loud") that
the requester never picks; whoever approves the request sets it. `POST /labels` takes
no `polarity` field at all. Not yet rendered anywhere in a client — the tag picker
and filter chips treat every approved label the same regardless of polarity today.

### `ActivityItem`

```json
{
  "id": "018f...",
  "verb": "rated_spot",
  "actor": { "id": "018f...", "handle": "sam", "displayName": "Sam", "avatarUrl": null },
  "spot": { "id": "018f...", "name": "Brew & Books" },
  "entry": { "id": "018f...", "score": 8.4, "notes": "Great back room" },
  "targetUser": null,
  "photos": [],
  "createdAt": "2026-07-25T18:03:11Z"
}
```

`spot`, `entry`, `targetUser`, and `photos` are populated according to `verb`; a
`followed_user` event has `targetUser` and no `spot`.

## Endpoints

### Spots

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/places/search?q=` | Proxies Places Autocomplete. Returns `{ googlePlaceId, name, address }[]`. Proxied so the API key never ships in a client. Pass a session token per search. |
| `POST` | `/spots` | Body `{ "googlePlaceId": "..." }`. **Idempotent**: `201` with the new spot, or `200` with the existing one if that Place ID is already known. Never creates a duplicate. |
| `PUT` | `/spots/{id}` | **Built 2026-08-07.** Body `{ "name": "...", "address": "..." }`. Corrects the shared place record's own name/address — most often filling in an address a manually-entered spot never had. Never touches `googlePlaceId`, `latitude`, or `longitude`; those only ever come from a Places lookup, which this doesn't re-run. `address` may be cleared to `null`; `name` may not be blank. Backs the Flutter edit-spot flow — see [mobile-app.md](mobile-app.md). |
| `GET` | `/spots/{id}` | Full `Spot`, including live hours and the caller's own entry as `myEntry`. |
| `GET` | `/spots/{id}/entries` | **Not built.** Other users' entries for this spot, respecting visibility. Paginated. Blocked on `follows`/visibility being real (v2) — today `SpotDetailDto.MyEntry` is the only per-user entry data a client can see. |

`POST /spots` takes **either** `{ "googlePlaceId": "..." }` — the normal path — **or**
`{ "name": "...", "address": "..." }` for a place Google doesn't know about (decision
D9). What it never accepts is ratings: those arrive separately as an entry, because
they belong to one user and the spot belongs to everyone. No `type` field — spots
aren't categorized anymore, see `### Label`.

When `Places:ApiKey` isn't configured, `GET /places/search` returns `503` with a
problem+json explaining why. The Flutter sheet treats that as "switch to manual entry"
rather than an error, so the add flow works with or without a Google key.

### My entries

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/me/spots` | `MySpotListItem[]`, ranked `score DESC, updatedAt DESC`. Drives the Spots tab. |
| `PUT` | `/spots/{spotId}/entry` | **Upsert** the caller's entry — this is decision D2 on the wire. `201` on create, `200` on update. |
| `DELETE` | `/spots/{spotId}/entry` | Removes the caller's rating. The spot itself survives. |

`PUT /spots/{spotId}/entry` request body:

```json
{
  "ratings": { "wifi": 4, "noise": 5, "outlets": 4, "seating": 4, "tableSize": 4, "coffee": 4 },
  "groupStudy": true,
  "tagSlugs": ["cozy", "bestforreading"],
  "coffeeOrder": "Vanilla latte",
  "notes": "Quiet back room with good lighting.",
  "visibility": "public"
}
```

`ratings` is required and complete — all six, each 1–5. `coffeeOrder` and `notes` are
optional; sending `null` clears them. `score` is rejected if present.

`groupStudy` is optional and defaults to `false`, so a client that predates the field
still saves rather than getting a `400`.

`tagSlugs` is optional and defaults to no tags. Every slug present must name an
`approved` `Label` — an unknown or not-yet-approved slug fails the **whole** write with
`400` (`Results.ValidationProblem`, same status as a bad rating), not just that one tag.
Sending `tagSlugs` replaces the entry's tags wholesale, same as every other field here —
it is not a diff.

**Guests are capped at 3 entries.** The count only includes *new* spots — re-rating one
already rated is always an update, never blocked. Past the cap, `PUT` returns `403` with:

```json
{ "type": "https://studease.app/problems/entry-limit-reached", "title": "Guest entry limit reached", "detail": "Guests can add up to 3 spots. Create an account to add more." }
```

The Flutter client matches on `type`, not the bare `403` — `POST /me` with no `users` row
yet (`registration-required`) is also a `403` and means something different. See
`ApiException.isGuestLimitReached` / `.needsRegistration` in `api_service.dart`.

### Visits

**Built.** "I'm studying here today" — see `### Visit` above and decisions D12/D13.

| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/spots/{id}/visits` | Body `{ "studied": "...", "drinkOrder": "..." }`, both optional. `201` with the new `Visit`. Requires an existing `SpotEntry` for the caller on this spot — `403` with `type: "https://studease.app/problems/rating-required"` otherwise. |
| `GET` | `/spots/{id}/visits` | The caller's own visits to this spot, `Visit[]`, newest first. Backs the spot detail sheet's "Past visits" button. |
| `GET` | `/me/visits` | Every spot the caller has logged a visit at, `Visit[]`, newest first, capped at 50 (no cursor pagination yet — revisit if this list grows). Backs the Profile tab's study history. |
| `DELETE` | `/spots/{id}/visits/{visitId}` | **Built 2026-08-24 (D13).** Removes one visit — undoes a mislog. Ownership checked the same way as `DELETE /spots/{id}/entry`: scoped to `SpotId == id && UserId == userId`, `404` if no match. `204` on success; decrements `spots.visit_count` inline. |

Unlimited visits per `(user, spot)` — logging is always an insert, never an upsert,
the opposite of `PUT /spots/{spotId}/entry` above. Still no edit endpoint — a visit's
`studied`/`drinkOrder`/`visitedAt` can't be changed once created — but as of D13 a whole
row can be deleted outright. "Immutable" turned out to mean "never edited," not "never
removed."

### My account

**Built** (backend + Flutter — email/password with email verification, and the
Google Sign-In provider call; see "Client status" below and [auth-plan.md](auth-plan.md)
Phase 4 for what's still unverified).

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/me` | The caller's `Me` — `200` always for a guest (auto-provisioned), or a real identity that has registered. `404` if authenticated but genuinely unregistered, with the **same** `problems/registration-required` problem `type` as the `403` a `RequireRegisteredFilter`-protected endpoint returns for the identical condition (just a `404` here — "your own profile" 404s rather than forbids). One `ApiException.needsRegistration` check on the client covers both; see [mobile-app.md](mobile-app.md) for how the Flutter boot flow uses it. |
| `POST` | `/me` | Body `{ "handle": "matt", "displayName": "Matthew" }`. Completes registration — for a brand-new identity, or a guest upgrading in place. `201` (new row) or `200` (guest upgraded), `409` if the handle is taken or this identity already has a real account, `422` if the handle fails `^[a-z0-9_]{3,30}$` or is reserved (`me`, `admin`, `api`, `spots`, `places`, `feed`, `users`, `photos`, `support`, `help`, `settings`, `about`). |

**Not built:** `GET /users/handle-available` (client validates the pattern locally and
just handles the `409` from `POST /me`), `PATCH /me`, `DELETE /me`.

### Labels & moderation

**Built** (backend + Flutter tag picker; no Flutter admin UI — see below).

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/labels` | `Label[]`, `status: "approved"` only, ordered by slug. The tag picker's data source. |
| `POST` | `/labels` | Body `{ "name": "..." }`. Idempotent-ish: dedupes to an existing `approved` or `pending` label by slug (`200`, no duplicate created) rather than erroring; a slug matching a `rejected` label is `409`; a new slug is `201` with `status: "pending"`. `400` if the name normalizes to fewer than 2 alphanumeric characters. |
| `GET` | `/admin/labels/pending` | `PendingLabelDto[]` — `{ id, slug, displayName, requestedBy, createdAt }`. **Admin only.** |
| `POST` | `/admin/labels/{id}/approve` | Body `{ "polarity": "positive" }` (or `"negative"`) — **required**, `400` (`Results.ValidationProblem`) if missing or not one of those two values. Flips `status` to `approved` and sets `polarity`. **Admin only.** |
| `POST` | `/admin/labels/{id}/reject` | Flips `status` to `rejected` — permanent, no "reconsider" endpoint. **Admin only.** |

"Admin only" means `users.is_admin = true`; a non-admin caller gets `403`. There is
**no admin UI in the Flutter app** — moderation happens via curl, either against a real
account with `is_admin` hand-set in Postgres, or locally against the dev-bypass
identity (seeded as admin, so these three routes work with no `Authorization` header
at all when `Auth:AllowDevBypass` is on). See `RequireAdminFilter` in the backend,
which checks the resolved `User.IsAdmin`.

### Social

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/feed?cursor=&limit=30` | `ActivityItem[]` from accounts the caller follows. Cursor is the last `id` seen (UUIDv7 sorts chronologically). |
| `POST` | `/users/{id}/follow` | `202` when the target is private (pending approval), `201` when public. |
| `DELETE` | `/users/{id}/follow` | Unfollow, or withdraw a pending request. |
| `GET` | `/users/{handle}` | Public profile plus their entries, respecting visibility. |

### Photos

| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/spots/{spotId}/photos` | `multipart/form-data`, optional `entryId`. Returns the created photo. |
| `DELETE` | `/photos/{id}` | Soft delete; uploader or spot owner only. |

## Client status

See [mobile-app.md](mobile-app.md) for the Flutter app's structure, design system, and
client-only behavior (fuzzy search, directions, edit) that never crosses the wire and so
doesn't belong in this file.

**Flutter — registration gap closed 2026-08-23.** `AuthController` gained a fourth
`AuthPhase`, `needsRegistration`, for when `GET /me` at boot returns the
`registration-required` `404` above — a real, non-anonymous identity with a valid token
but no `users` row (for example, a cached Firebase session that outlived a database
reset). Previously this fell into the generic `error` phase; now `StudySpotApp` routes
straight to `ChooseHandlePage` as the root screen, the same screen the ordinary
guest-links-a-credential flow pushes. See [mobile-app.md](mobile-app.md).

**Flutter — visits built 2026-08-23.** `SpotDetailSheet` has "Log a visit" and "Past
visits" buttons directly under the spot name — `LogVisitDialog` (`showLogVisitDialog`,
a centered dialog, not a bottom sheet — renamed from `LogVisitSheet` once it stopped
being one) and `PastVisitsSheet` in `study_spots/presentation/`. The Profile tab's
`_StudyHistorySection` shows the same data across every spot, Beli-style. See D12.

**Flutter — visit delete built 2026-08-24 (D13).** `PastVisitsSheet` rows swipe left,
iMessage-style, to reveal a pinned delete button (`_SwipeToDeleteRow`, hand-rolled drag
+ `AnimationController`, no new dependency) — tapping it calls the new `DELETE`
endpoint above and removes the row only once that succeeds.

**Flutter — tags built 2026-08-06.** `SpotType` is gone from `theme.dart`; `main.dart`'s
category circle is one fixed neutral icon now (spots no longer have a single category
to color-code by), and the old single-select type filter is a multi-select tag filter
sourced from whatever tags are actually on the loaded list. `add_spot_sheet.dart`'s
type picker is a tag picker (`GET /labels`) plus an inline "suggest a new tag" field
(`POST /labels`). No admin UI — see "Labels & moderation" above.

**Flutter — auth built 2026-08-06, expanded 2026-08-23.** Every request now carries a
Firebase ID token (`api_service.dart`'s `_headers()`), including a guest's anonymous
one, with a single 401-triggered refresh-and-retry. `AuthController` drives boot
(anonymous sign-in → `GET /me`), sign-up/sign-in (`LoginPage`, linking the guest
session), email verification (`VerifyEmailPage`, `AuthPhase.needsEmailVerification` —
password accounts only, gates handle selection), the handle picker
(`ChooseHandlePage`), and the Profile tab's guest-vs-account view. `LoginPage` now has
a "Continue with Google" button (Phase 4 in auth-plan.md) — Google accounts arrive
pre-verified and skip straight past the verification step.

**Flutter — done.** `lib/models/spot.dart` replaced the old flat `StudySpot`, and
`api_service.dart` was rewritten: the `Uri.https('localhost:5001', …)` call (https
against a plaintext dev server) and the unawaited top-level `http.get` that fired at
import time are both gone. The base URL now resolves to `10.0.2.2` on the Android
emulator, which is the only address that reaches the host from there, and
`--dart-define=API_BASE_URL=…` overrides it.

**Angular — broken, not yet updated.** `frontend/src/services/study-spot.service.ts`
still calls `/studyspots`, which no longer exists. It needs the same split, and the
`db.json` import with its `openUntil: new Date(spot.openUntil)` mapping should go; the
API is the only source now.
