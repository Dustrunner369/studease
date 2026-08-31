# Data model

Target model for Studease. See [schema.sql](schema.sql) for the DDL and
[api-contracts.md](api-contracts.md) for what crosses the wire.

## Entity relationship

```mermaid
erDiagram
    users ||--o{ spot_entries : writes
    users ||--o{ spot_visits : logs
    users ||--o{ spots : "added"
    users ||--o{ photos : uploads
    users ||--o{ follows : follower
    users ||--o{ follows : followee
    users ||--o{ activity_events : actor
    users ||--o{ labels : requests
    users ||--o{ labels : approves
    spots ||--o{ spot_entries : "is rated by"
    spots ||--o{ spot_visits : "studied at"
    spots ||--o{ photos : has
    spots ||--o{ spot_tag_counts : aggregates
    spot_entries ||--o{ photos : "attached to"
    spot_entries ||--o{ activity_events : announces
    spot_entries }o--o{ labels : "tagged with"
    labels ||--o{ spot_tag_counts : "counted in"

    users {
        uuid id PK
        text handle UK
        text display_name
        text auth_subject UK
        bool is_private
        bool is_admin
    }
    spots {
        uuid id PK
        text google_place_id UK
        text name
        float latitude
        float longitude
        int price_level
        int entry_count "cached"
        numeric avg_score "cached"
        int visit_count "cached"
    }
    spot_entries {
        uuid id PK
        uuid user_id FK
        uuid spot_id FK
        int wifi
        int noise
        int outlets
        int seating
        int table_size
        int coffee
        bool group_study
        numeric score "generated"
        text coffee_order
        text notes
    }
    spot_visits {
        uuid id PK
        uuid user_id FK
        uuid spot_id FK
        text studied
        text drink_order
        timestamptz visited_at
    }
    labels {
        uuid id PK
        text slug UK
        text display_name
        text status
        text polarity "nullable until approved"
        uuid requested_by FK
        uuid approved_by FK
    }
    spot_tag_counts {
        uuid spot_id PK,FK
        uuid label_id PK,FK
        int entry_count "cached"
    }
    follows {
        uuid follower_id PK
        uuid followee_id PK
        text status
    }
    photos {
        uuid id PK
        uuid spot_id FK
        uuid entry_id FK
        text storage_key
    }
    activity_events {
        uuid id PK
        uuid actor_id FK
        text verb
        timestamptz created_at
    }
```

`spot_entry_tags` (the join table behind `spot_entries }o--o{ labels`) is omitted from
the diagram, same convention as every other pure join in this file — no columns of
its own beyond the two foreign keys.

## The central split

The single most important thing about this model, and the thing today's code gets wrong:

> **`spots` = facts about a place. `spot_entries` = one person's opinion of it.**

A café's address doesn't change because you rated it. Your rating doesn't change because
someone else rated it. Today these live in one table, which means two users can't both
rate the same café, and "Brew & Books" would exist twice in a social app.

Which side does a field belong on? Ask: *if two users both add this place, do they need
different values?* Address → no, it's a fact, put it on `spots`. Drink order → yes, put
it on `spot_entries`.

## Entities

### `users`

Identity only. No passwords — the API stores `(auth_provider, auth_subject)` from an
external identity provider and treats that pair as the login key.

- `handle` is the public `@name`. Unique **case-insensitively** — enforced by a unique
  index on `lower(handle)`, not by the column type.
- `is_private` gates whether follows need approval. See `follows.status`.
- `is_admin` gates the label-moderation endpoints (`labels.status` below). The
  schema's first permission field, deliberately minimal — one boolean, no roles
  table. No self-serve way to become admin; promotion is a manual `UPDATE`.
- `deleted_at` is a soft delete: a deleted user's spots survive (`spots.added_by` goes
  NULL), their entries cascade away.

### `spots`

One row per real-world place. **Globally shared** — not owned by whoever added it.

- `google_place_id` carries a **partial** unique index (`WHERE google_place_id IS NOT
  NULL`). This is what stops duplicates: adding a Places-backed spot is "resolve a Place
  ID, then insert-or-return", never "insert whatever the user typed". It's nullable
  because manual entry has to stay possible — see decision D9 in the README.
- `name`, `formatted_address`, `latitude`, `longitude`, `price_level`, `website_url`,
  `phone` are all snapshots from Places, refreshed on a schedule; `places_synced_at`
  records when. They're stored so lists render without an API call per row.
- `utc_offset_minutes` is also a Places snapshot, but it isn't rendered anywhere —
  it exists so the API can work out the spot's *local* "now" when deciding what time
  it closes today. Null for manual spots, same as the other Places-sourced fields.
- **No hours column** (D8). Hours are fetched live from Places when a single spot is
  rendered. See "Places data and caching" below.
- **No `type` column** (removed 2026-08-06, decision D10). Spots used to carry a
  single required category (`cafe | library | campus | other`); that's gone,
  replaced by the standardized, moderated tag/label system — see `### labels` below.
- `entry_count`, `avg_score`, and `avg_wifi`…`avg_coffee` — which includes
  `avg_table_size` — are **cached aggregates**. They are derived data, recomputed when an
  entry is written. Never treat them as the source of truth; `spot_entries` is. There is
  no cached column for `group_study`; see `spot_entries` below. Tag aggregation is a
  separate table (`spot_tag_counts`), not inline columns here, because tag cardinality
  is variable — unlike the six fixed rating categories, there's no fixed set of
  `avg_*`-shaped columns to add.
- `visit_count` is also cached, but recomputed differently: it's incremented at write
  time rather than recomputed from scratch, because `spot_visits` rows are never edited
  or deleted (see `### spot_visits` below), so there's nothing to desync it. Not
  surfaced in any client yet — stored ahead of the future activity feed and spot
  popularity.

### `spot_entries`

The heart of the app. One row per (user, spot) — enforced by `UNIQUE (user_id, spot_id)`.
Rating a spot you've already rated is an **update**, not an insert (D2).

Six required 1–5 ratings:

| Column | 1 means | 5 means | Scored |
| --- | --- | --- | --- |
| `wifi` | unusable or none | fast and reliable | yes |
| `noise` | **loud** | **quiet** | yes |
| `outlets` | no outlets | outlet at every seat | yes |
| `seating` | never a free table | always somewhere to sit | yes |
| `table_size` | cramped two-tops only | big shared tables, room to spread out | **no** |
| `coffee` | bad | excellent | yes |

> **`noise` is inverted on purpose.** 5 = quietest. Every category must be
> "higher is better" or the score formula and the green/amber/coral `Level` colors in
> `theme.dart` silently mean the opposite of what they show. If you ever add a category
> where high is bad (crowdedness, price), store it inverted too.

> **`table_size` is rated but not scored.** It's collected, displayed, and averaged into
> `avg_table_size` like any other rating, but it is absent from the generated `score`
> expression below. See "Entry score" for why.

`group_study` is a required boolean, defaulting to `false`: does this place work for
studying with other people? It is **one user's verdict, not a fact about the place** —
two people can disagree about the same spot, and that's the point. There is deliberately
no group-study aggregate on `spots`.

Each entry can also carry zero or more **tags**, through the `spot_entry_tags` join to
`labels` — same shape as `group_study`, one user's opinion, not a fact set once on the
spot. Unlike `group_study`, tags *do* aggregate: `spot_tag_counts` rolls up how many of
a spot's entries carry each label, exactly the way `avg_wifi` etc. roll up the six
ratings. Only `approved` labels may be attached — enforced by the API at write time,
not a DB constraint (that would need a cross-table trigger). See `### labels` below.

`coffee_order` and `notes` are optional free text (D6) — purely for your own recall,
never validated, never parsed.

`visibility` is `public | followers | private`, defaulting to `public`. Private entries
are excluded from the feed and from a spot's aggregates.

### `spot_visits`

A lightweight, append-only log — "I'm studying here today" — layered alongside
`spot_entries` rather than folded into it (decision D12, 2026-08-23; see the README for
why). Unlimited rows per `(user_id, spot_id)`, unlike the `UNIQUE` constraint on
`spot_entries`: logging a visit is never an update, always an insert. Rows are never
edited in place once created, but can be deleted outright to undo a mislog (decision
D13, 2026-08-24) — the one mutation D12's append-only design allows — which
decrements `spots.visit_count` inline rather than triggering a recompute.

`studied` and `drink_order` are optional free text, same treatment as `spot_entries`'
`notes`/`coffee_order` (D6) — never validated, never parsed. `visited_at` is stamped
server-side at creation and never client-supplied; logging is always "today", not
backdated.

Creating a visit **requires an existing `spot_entries` row** for the same
`(user_id, spot_id)` — you can't log a visit to somewhere you haven't rated. Enforced in
the API (`Program.cs`), not a database constraint: a cross-table CHECK referencing
`spot_entries` isn't expressible the way the `photos.entry_id`/`spot_id` composite FK is.

### `labels`

The standardized, global tag vocabulary that replaced `spots.type` (decision D10,
2026-08-06). Modeled on Beli's Labels: anyone can apply an existing label to their own
entry; anyone can propose a new one, but it's unusable — by anyone, including whoever
proposed it — until an admin reviews it.

- `slug` is normalized: **lowercase kebab-case.** "Best for reading" becomes
  `best-for-reading`. Originally alphanumeric-only (no hyphens), on the theory that
  labels are hashtag-shaped (`#cozy`) everywhere they render and a hyphen breaks that
  the way `#best-for-reading` reads as broken on real hashtag platforms — reversed by
  decision D14 (2026-08-31): the `#slug` pill in this app's own picker/filter chips is
  plain text (`Text('#${slug}')`), not a real hashtag parser, so a hyphen renders fine
  there. Enforced by `CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug)
  BETWEEN 2 AND 30)` and a unique index.
- `display_name` is the human-readable form, stored separately since it can't be
  losslessly reconstructed from `slug`. Mainly seen in the moderation queue.
- `status` is `pending | approved | rejected`. Only `approved` labels appear in the
  picker or validate on a `PUT .../entry` write. A request that dedupes to an existing
  `pending` or `approved` label returns that row rather than creating a duplicate.
- `polarity` is `positive | negative`, **null until approved** (decision D11,
  2026-08-17). A tag reads as either a compliment or a complaint — "Cozy" vs "Too
  loud" — and the requester never picks which: `POST /labels` takes only a name,
  and polarity is set by whoever approves the request (`POST
  /admin/labels/{id}/approve`, which now requires it in the body). That keeps a
  requester from sneaking a negative-sounding tag in as positive, or the reverse.
  Not yet surfaced anywhere in a client UI — see api-contracts.md.
- `requested_by` / `approved_by` are nullable FKs to `users`, `SET NULL` on delete —
  provenance, not ownership. `approved_by` is set on rejection too ("who reviewed
  this"), not only on approval.
- **Known limitation**: the unique index on `slug` means a `rejected` slug is
  permanently blocked from being re-requested. There's no "reconsider" endpoint — an
  admin re-opens it by hand-editing the row if it ever matters.

### `spot_tag_counts`

A cached rollup: how many of a spot's (non-private) entries carry a given label.
Composite primary key `(spot_id, label_id)`. Rebuilt from scratch — delete everything
for the spot, re-derive — inside the same recompute pass as `spots.avg_*`, whenever an
entry is written or deleted. `spot_entries` (via `spot_entry_tags`) is the source of
truth; this is derived data, same rule as every other cached aggregate in this file.

Doubles as the feature matrix a future recommender would want (spot × label weights) —
not used for that yet, just a free byproduct of following the existing aggregate
pattern rather than a live JOIN.

### `follows`

Composite primary key `(follower_id, followee_id)` — you can't follow someone twice, and
a `CHECK` stops you following yourself.

`status` is `pending | accepted`. Public accounts jump straight to `accepted`; private
accounts (`users.is_private`) create a `pending` row that the followee approves. Feed
queries filter on `status = 'accepted'`.

### `photos`

Attached to a spot always, and to an entry optionally:

- `entry_id IS NULL` → a photo of the place itself.
- `entry_id IS NOT NULL` → a photo someone took with their rating.

The composite foreign key `(entry_id, spot_id) → spot_entries (id, spot_id)` makes it
impossible to attach a photo to an entry for a *different* spot. That's a real bug class
closed off in the schema rather than in application code.

Postgres stores metadata only. Bytes live in object storage under `storage_key`; the
public URL is derived at read time so you can move buckets or add a CDN without a
migration.

### `activity_events`

An append-only log of things worth showing in a feed: `rated_spot`, `updated_rating`,
`added_spot`, `added_photo`, `followed_user`.

The feed is **fan-out on read** — query events by the actors you follow:

```sql
SELECT e.* FROM activity_events e
JOIN follows f ON f.followee_id = e.actor_id
WHERE f.follower_id = $1 AND f.status = 'accepted'
  AND e.visibility <> 'private'
  AND e.id < $2                      -- cursor
ORDER BY e.id DESC LIMIT 30;
```

This is the right choice at your scale and stays fine into the thousands of users. If
one user ever follows thousands of accounts, the fix is a per-recipient inbox table
(fan-out on write) — but don't build that now.

Give `id` a **UUIDv7** (`Guid.CreateVersion7()`, .NET 9). Because v7 is time-ordered, the
id doubles as a stable pagination cursor, which `created_at` can't be — two events in the
same millisecond would make a timestamp cursor skip or repeat rows.

## Derived values

Nothing computes a score in the UI. Two of these live in the database so all three
clients agree by construction.

### Entry score (0–10)

A `GENERATED ALWAYS AS ... STORED` column — the database computes it on every write, and
it cannot drift from the ratings:

```text
score = ROUND((wifi + noise + outlets + seating + coffee) * 0.4, 1)
```

Equal weights, sum of 5..25 mapped onto **2.0–10.0**. The floor is 2.0, not 0.0: a spot
you bothered to rate at all is never a zero, and the `scoreColor` thresholds in
`theme.dart` (9.0 / 8.0 / 7.0) already assume the interesting range is the top half.

**`table_size` is not in this expression**, even though it's a required 1–5 rating. The
`0.4` is what maps five ratings onto a 10-point ceiling; a sixth term needs `/ 3.0`
instead, which changes the number every existing entry scores. Adding the column was
worth doing on its own, rebasing everyone's scores was not. If that trade is ever worth
making, it's a `DROP` and re-`ADD` of the generated column in a migration — you cannot
`ALTER` a generated expression in place.

To weight categories later, change the expression and add a migration — do *not* start
computing it client-side.

In EF Core: `.HasComputedColumnSql("...", stored: true)` and map the property as
read-only (`ValueGeneratedOnAddOrUpdate()`), or EF will try to INSERT into it.

### Spot aggregates

`avg_score`, `avg_wifi`…`avg_coffee`, `entry_count` — averages over non-private entries,
recomputed on entry insert/update/delete. Two options, pick one and be consistent:
recompute in the same transaction as the entry write (simple, correct, fine at this
scale), or a Postgres trigger. Application-side recompute-in-transaction is recommended
so the logic is visible in C#.

### Amenity levels

`Level.good / ok / rough` in `theme.dart` maps from a raw 1–5 rating: `>= 4` good,
`>= 3` ok, else rough. That already matches the 1–5 scale — no change needed, and the
`_levelFor` helper in `main.dart:43` is correct as written.

## Places data and caching

Hours come from the Places API at render time (D8), so a spot's detail response can
include today's `openUntil` and `isOpenNow` without any stored schedule going stale.

Two consequences to design around:

1. **Hours can be missing.** The API returns `null` when Places has no hours or the call
   fails. Every client must render a spot with no hours. Today `StudySpot.fromJson`
   (`lib/models/studyspot.dart`) *requires* `openUntil` to be a `String` and throws
   `FormatException` otherwise — that will crash on the first spot Google has no hours
   for. It needs to become nullable.
2. **Google's terms limit caching.** Place IDs may be stored indefinitely; other Places
   content may only be cached for a limited window (~30 days at time of writing). That's
   why `spots` stores a name/address/geo snapshot with `places_synced_at` and a refresh
   job, rather than treating the snapshot as permanent. Re-check the current Google Maps
   Platform terms before shipping.

A short-lived server-side cache (minutes) in front of the hours lookup is worth adding
when the Spots list starts showing "open now" for many spots at once.

## Conventions

- **Primary keys**: `uuid`, generated app-side with `Guid.CreateVersion7()` so they're
  time-ordered and index-friendly. Clients can mint an entry's id before it reaches the
  server, which makes optimistic UI and offline creation possible later.
- **Timestamps**: `timestamptz`, always UTC. Never `timestamp without time zone` — that's
  what the `ChangeOpenUntilTimestamp` migration papered over.
- **Naming**: `snake_case` tables and columns. EF's default is PascalCase; configure
  `UseSnakeCaseNamingConvention()` (via `EFCore.NamingConventions`) once rather than
  annotating every property.
- **Enums**: modeled as `text` + `CHECK` constraints, not native Postgres enum types.
  Native enums need `NpgsqlDataSourceBuilder.MapEnum` wiring and a migration to add a
  value; `text` + `CHECK` is a one-line change. If you'd rather have real enums, this is
  the place to switch.
- **Soft delete**: `deleted_at` on `users` and `photos` only. Entries and follows are
  hard-deleted.

## Build order

Full model documented, built in slices (D-scope):

**v1 — make the current UI correct.** `users` (minimal: id, handle, display_name, auth
columns; a single dev user is fine), `spots`, `spot_entries`. Endpoints: place search →
create-or-return spot, upsert my entry, list my entries ranked by score. This alone fixes
the score bug, the duplicate-spot problem, and the frozen `OpenUntil`.

**v1.5 — visits.** `spot_visits`, `spots.visit_count`. Independent of v2/v3 — no
dependency on `follows` or `photos`.

**v2 — social.** `follows`, `activity_events`, the feed endpoint, real auth. The Profile
tab in the bottom nav becomes real.

**v3 — photos.** `photos` plus object storage and an upload endpoint.

Nothing in v2 or v3 changes a v1 table, which is the point of designing them now.

## Migrating off today's schema

Today: one `StudySpots` table, `int` identity, 10 columns, five seed rows.

**Recommendation: don't write a data migration.** The five rows in `frontend/db.json` are
fixtures, not data. Add one EF migration that drops `StudySpots` and creates the new
tables, then re-seed by resolving the five names through Places. `Program.cs` already
calls `db.Database.Migrate()` at startup, so it applies on the next run.

Field-by-field, for when you re-seed:

| Today | Becomes | Note |
| --- | --- | --- |
| `Id` (int) | `spots.id` (uuid) | New ids; nothing references the old ones |
| `Name` | `spots.name` | |
| `Address` | `spots.formatted_address` + `latitude`/`longitude` | From Places, not the typed string |
| `HasCharging` (bool) | `spot_entries.outlets` (1–5) | true → 4, false → 2 |
| `Seating` (int, a **seat count**: 15–40) | `spot_entries.seating` (1–5) | Not a rescale — it's a different question ("are seats available?"). Re-enter by hand |
| `CoffeeQuality` (int, 1–10 in the fixtures) | `spot_entries.coffee` (1–5) | `ROUND(q / 2)` |
| `GeneralPrice` (`"$$"`) | `spots.price_level` (0–4) | Length of the string; sourced from Places going forward |
| `OpenUntil` (DateTime) | *dropped* | Live from Places (D8) |
| `DrinkOrder` | `spot_entries.coffee_order` | |
| `ExtraNotes` | `spot_entries.notes` | |
| — | `spot_entries.wifi`, `noise` | New; no source data, enter by hand |

Client-side fallout — **done for Flutter, still outstanding for Angular**:

- ~~`lib/models/studyspot.dart`~~ — replaced by `lib/models/spot.dart` with `Ratings`,
  `MySpotListItem`, `SpotEntry`, `SpotDetail` and `PlaceSuggestion`. `openUntil` is
  nullable, ids are `String`, and the local score calculation is gone.
- ~~`main.dart` `SpotType` hardcoded to `cafe`~~ — read `spot.type` off the wire for a
  while, then `SpotType`/`type` were removed entirely (decision D10, 2026-08-06),
  replaced by the label/tag system. See `### labels` above.
- ~~`main.dart` `score` getter~~ — deleted; Postgres computes the score.
- **`frontend/src/services/study-spot.service.ts` is now broken.** The Angular app still
  calls `/studyspots`, which no longer exists. Its `StudySpot` interface needs the same
  split, and the `db.json` import with its `openUntil: new Date(...)` mapping should go.
  Untouched so far — the Flutter app was the one being built.
