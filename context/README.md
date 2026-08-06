# Studease — context

Design docs that describe the *intended* data model, as agreed 2026-07-25. These are
specs, not generated output: when the code and these docs disagree, one of them is a bug.

| File | What it covers |
| --- | --- |
| [data-model.md](data-model.md) | Entities, relationships, invariants, build order, migration off today's schema |
| [schema.sql](schema.sql) | Postgres DDL for the target model (reference — EF migrations stay the source of truth) |
| [api-contracts.md](api-contracts.md) | JSON shapes on the wire, shared by the .NET API, Flutter app, and Angular web app |
| [auth-plan.md](auth-plan.md) | Sign-in and registration — Firebase Auth with email/password + Google, endpoints, client work, build order (**decided, not built**) |

## The shape of the app, in one paragraph

Studease is a **social** app. A `spot` is a real-world place, identified by its Google
Place ID and shared by everyone. A `spot_entry` is **one user's opinion of one spot** —
five 1–5 ratings, an optional coffee order, optional notes. One entry per user per spot,
edited in place; there is no visit history. Users follow each other and see an activity
feed of their friends' entries. Opening hours are **not stored** — they're fetched live
from the Places API when a spot is rendered.

## Decisions already made

| # | Decision | Consequence |
| --- | --- | --- |
| D1 | Full social model from the start | `users`, `follows`, `activity_events` are in the schema now, not retrofitted |
| D2 | One record per user per spot, edited in place | `UNIQUE (user_id, spot_id)` on `spot_entries`; no visits table |
| D3 | Place facts split from personal opinion | `spots` holds name/address/geo; `spot_entries` holds ratings/notes/coffee order |
| D4 | Google Places-backed identity | `spots.google_place_id` is the dedupe key — unique, but see D9 |
| D5 | Five 1–5 categories: wifi, noise, outlets, seating, coffee | Score is derived from them, not entered |
| D6 | Coffee order + notes are optional free text | Nullable columns on the entry, no validation |
| D7 | Follows + activity feed, photos on spots and entries | Modeled; want-to-go lists and likes/comments are **not** |
| D8 | Hours pulled live from Places, never stored | No `hours` column anywhere; `openUntil` is a response field, not a database field |
| D9 | Manual entry is allowed alongside Places | `google_place_id` is **nullable** with a unique index only where present; `latitude`/`longitude` are nullable too |

### Why D9 exists

D4 originally said `NOT NULL UNIQUE`. That would have made half the app's own use case
unaddable: a campus study room, a specific library floor, or the quiet corner of a
building simply isn't a Google Place. `SpotType.campus` exists in the theme, so the
schema has to be able to hold one.

The unique index is partial (`WHERE google_place_id IS NOT NULL`), so every
Places-backed spot still dedupes exactly as designed, while manually entered spots don't
all collide on `NULL`. Verified against Postgres 15: two manual spots coexist, a repeated
Place ID is rejected.

A manual spot has no coordinates — we don't geocode typed addresses — so it won't appear
on the Map tab until someone links it to a real place.

## What's built

v1 is in. `users`, `spots`, and `spot_entries` exist, with the add-spot and
delete-my-rating flows working end to end.

`follows`, `photos`, and `activity_events` are designed in this folder but **not built**
— they're v2/v3 in the build order below. [schema.sql](schema.sql) marks which is which.

## Still open

These block specific pieces of work, not the schema as a whole:

1. ~~**Auth provider**~~ — **decided 2026-08-06: Firebase Auth, with email/password and
   Google Sign-In.** `auth_provider` + `auth_subject` on `users`, so the API never stores a
   password. Sign in with Apple is deferred; see the App Store condition in
   [auth-plan.md](auth-plan.md), which carries the full design — endpoints, client work,
   build order. Still unbuilt: every request runs as the seeded dev user.
2. **Photo storage** — blocks the `photos` table being useful. Recommendation: S3-compatible
   object storage (R2, Supabase Storage) with `storage_key` in Postgres and the URL derived
   at read time. A local Docker volume works for development.
3. **Places API cost controls** — Autocomplete is billed per keystroke-session. Use session
   tokens on the add-spot search. Not a schema concern, but it will surprise you otherwise.
4. **Ranked list tie-breaking** — the Spots tab is ranked by score; two 8.4s need a stable
   order. Currently `score DESC, updated_at DESC`.

## Gotchas found while building

**Adding snake_case naming to an existing database breaks EF's own bookkeeping.**
`UseSnakeCaseNamingConvention()` renames the columns of `__EFMigrationsHistory` too, so
EF looks for `migration_id` in a table that has `MigrationId` and fails before any
migration runs — you can't fix it *in* a migration, because EF reads that table first.
On a fresh database it's a non-issue. On an existing one, either rename those two
columns by hand or drop the schema and re-migrate:

```sql
ALTER TABLE "__EFMigrationsHistory" RENAME COLUMN "MigrationId" TO migration_id;
ALTER TABLE "__EFMigrationsHistory" RENAME COLUMN "ProductVersion" TO product_version;
```

**The local `appdb` still has the old `StudySpots` table** and will hit exactly this on
the next `dotnet ef database update`. Nothing has touched it — the new schema was
verified on a separate throwaway database instead.
