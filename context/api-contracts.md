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
- **Auth**: `Authorization: Bearer <token>`; the API resolves the caller from
  `(auth_provider, auth_subject)`. Endpoints under `/me` are caller-scoped.

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
  "type": "cafe",
  "priceLevel": 2,
  "websiteUrl": "https://brewandbooks.example",
  "phone": "+44 20 7123 4567",
  "openUntil": "22:00",
  "isOpenNow": true,
  "hoursUnavailable": false,
  "entryCount": 12,
  "avgScore": 8.4,
  "avgRatings": { "wifi": 4.2, "noise": 3.8, "outlets": 4.5, "seating": 3.9, "coffee": 4.4 },
  "photos": [ { "id": "018f...", "url": "https://...", "width": 1600, "height": 1200 } ]
}
```

`hoursUnavailable: true` distinguishes "Google has no hours for this place / the lookup
failed" from "closed right now". Show "Hours unknown", not "Closed".

`type` is one of `cafe | library | campus | other` and maps to `SpotType` in
`lib/design/theme.dart`.

### `SpotEntry`

One user's opinion. `score` is computed by the database — **read-only**, never sent by a
client.

```json
{
  "id": "018f...",
  "spotId": "018f...",
  "user": { "id": "018f...", "handle": "matt", "displayName": "Matthew", "avatarUrl": null },
  "ratings": { "wifi": 4, "noise": 5, "outlets": 4, "seating": 4, "coffee": 4 },
  "score": 8.4,
  "coffeeOrder": "Vanilla latte",
  "notes": "Quiet back room with good lighting.",
  "visibility": "public",
  "photos": [],
  "createdAt": "2026-07-20T14:00:00Z",
  "updatedAt": "2026-07-25T18:03:11Z"
}
```

All five ratings are integers 1–5 and all are required. `noise: 5` means **quiet**.

### `MySpotListItem`

The Spots tab's list row — a spot joined to my entry, flattened so the row renders
without a second request. This replaces today's `StudySpot` model in both clients.

```json
{
  "spotId": "018f...",
  "entryId": "018f...",
  "name": "Brew & Books",
  "address": "123 Library Lane, Booktown",
  "type": "cafe",
  "score": 8.4,
  "ratings": { "wifi": 4, "noise": 5, "outlets": 4, "seating": 4, "coffee": 4 },
  "priceLevel": 2,
  "thumbnailUrl": null,
  "updatedAt": "2026-07-25T18:03:11Z"
}
```

No `openUntil` here on purpose: it would cost a Places call per row. The detail sheet
fetches it. If the list must show "open now", add `?includeHours=true` and accept the
latency, or cache hours server-side for a few minutes.

### `ActivityItem`

```json
{
  "id": "018f...",
  "verb": "rated_spot",
  "actor": { "id": "018f...", "handle": "sam", "displayName": "Sam", "avatarUrl": null },
  "spot": { "id": "018f...", "name": "Brew & Books", "type": "cafe" },
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
| `GET` | `/spots/{id}` | Full `Spot`, including live hours and the caller's own entry as `myEntry`. |
| `GET` | `/spots/{id}/entries` | Other users' entries for this spot, respecting visibility. Paginated. |

Note what `POST /spots` does *not* accept: no name, address, hours, or ratings. A spot is
created from a Place ID and nothing else. Ratings arrive separately, as an entry.

### My entries

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/me/spots` | `MySpotListItem[]`, ranked `score DESC, updatedAt DESC`. Drives the Spots tab. |
| `PUT` | `/spots/{spotId}/entry` | **Upsert** the caller's entry — this is decision D2 on the wire. `201` on create, `200` on update. |
| `DELETE` | `/spots/{spotId}/entry` | Removes the caller's rating. The spot itself survives. |

`PUT /spots/{spotId}/entry` request body:

```json
{
  "ratings": { "wifi": 4, "noise": 5, "outlets": 4, "seating": 4, "coffee": 4 },
  "coffeeOrder": "Vanilla latte",
  "notes": "Quiet back room with good lighting.",
  "visibility": "public"
}
```

`ratings` is required and complete — all five, each 1–5. `coffeeOrder` and `notes` are
optional; sending `null` clears them. `score` is rejected if present.

### Social

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/feed?cursor=&limit=30` | `ActivityItem[]` from accounts the caller follows. Cursor is the last `id` seen (UUIDv7 sorts chronologically). |
| `POST` | `/users/{id}/follow` | `202` when the target is private (pending approval), `201` when public. |
| `DELETE` | `/users/{id}/follow` | Unfollow, or withdraw a pending request. |
| `GET` | `/users/{handle}` | Public profile plus their entries, respecting visibility. |
| `GET` | `/me` | The caller's own `UserSummary` and counts. |

### Photos

| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/spots/{spotId}/photos` | `multipart/form-data`, optional `entryId`. Returns the created photo. |
| `DELETE` | `/photos/{id}` | Soft delete; uploader or spot owner only. |

## What this breaks in the current clients

Both frontends model a single flat `StudySpot`. That type splits in two.

**Flutter** (`lib/models/studyspot.dart`) — `StudySpot.fromJson` currently pattern-matches
on `{'id': int, 'hasCharging': bool, 'seating': int, 'coffeeQuality': int, 'openUntil':
String}` and throws `FormatException` on anything else. Every one of those five keys
changes: `id` becomes a `String`, `hasCharging` becomes the `outlets` rating,
`coffeeQuality` becomes `coffee`, and `openUntil` becomes nullable and moves to the
detail response. Replace the model with `Spot`, `SpotEntry`, and `MySpotListItem`.

`lib/services/api_service.dart` also has a live bug worth fixing in the same pass:
`Uri.https('localhost:5001', 'studyspots')` requests **https** against a plaintext dev
server, and the top-level `http.get(url)` at line 6 fires an unawaited request at import
time. Use `Uri.http` (or a configurable base URL) and delete the module-level call.

**Angular** (`frontend/src/services/study-spot.service.ts`) — the `StudySpot` interface
splits the same way, and the `db.json` import with its `openUntil: new Date(spot.openUntil)`
mapping goes away entirely; the API is the only source now.
