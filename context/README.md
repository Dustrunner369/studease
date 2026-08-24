# Studease — context

Design docs that describe the *intended* data model, as agreed 2026-07-25. These are
specs, not generated output: when the code and these docs disagree, one of them is a bug.

| File | What it covers |
| --- | --- |
| [data-model.md](data-model.md) | Entities, relationships, invariants, build order, migration off today's schema |
| [schema.sql](schema.sql) | Postgres DDL for the target model (reference — EF migrations stay the source of truth) |
| [api-contracts.md](api-contracts.md) | JSON shapes on the wire, shared by the .NET API, Flutter app, and Angular web app |
| [auth-plan.md](auth-plan.md) | Sign-in and registration — Firebase Auth with email/password + Google, endpoints, client work, build order (**decided, mostly built**) |
| [mobile-app.md](mobile-app.md) | The Flutter app's structure, design system, illustrations, and client-only behavior that doesn't cross the wire |
| [infra.md](infra.md) | Hosting (Neon), local dev, environment variables, connection-string plumbing |

## The shape of the app, in one paragraph

Studease is a **social** app. A `spot` is a real-world place, identified by its Google
Place ID and shared by everyone. A `spot_entry` is **one user's opinion of one spot** —
five 1–5 ratings, an optional coffee order, optional notes. One entry per user per spot,
edited in place. Separately, a `spot_visit` log lets you say "I'm studying here today" —
unlimited entries, no rating, optional notes on what you studied and ordered — building a
personal study history (D12). Users follow each other and see an activity feed of their
friends' entries. Opening hours are **not stored** — they're fetched live from the
Places API when a spot is rendered.

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
| D10 | `spots.type` replaced by a standardized, moderated tag system (2026-08-06) | `labels` + `spot_entry_tags` + `spot_tag_counts`; tags are per-entry (like `group_study`), aggregated onto the spot; new labels need `users.is_admin` approval before they're usable |
| D11 | Labels carry a positive/negative polarity, set by the admin at approval, not the requester (2026-08-17) | `labels.polarity`, nullable, `CHECK` restricted to `positive`/`negative`; `POST /admin/labels/{id}/approve` now requires it in the body |
| D12 | A separate, append-only `spot_visits` log, layered alongside D2, not replacing it (2026-08-23) | `spot_visits`: many rows per (user, spot), no uniqueness constraint; requires an existing `spot_entries` row to create one |

### Why D9 exists

D4 originally said `NOT NULL UNIQUE`. That would have made half the app's own use case
unaddable: a campus study room, a specific library floor, or the quiet corner of a
building simply isn't a Google Place — that kind of spot still has to fit the schema.

The unique index is partial (`WHERE google_place_id IS NOT NULL`), so every
Places-backed spot still dedupes exactly as designed, while manually entered spots don't
all collide on `NULL`. Verified against Postgres 15: two manual spots coexist, a repeated
Place ID is rejected.

A manual spot has no coordinates — we don't geocode typed addresses — so it won't appear
on the Map tab until someone links it to a real place.

### Why D12 exists

D2 keeps a `spot_entry` a single, edited-in-place row — that's the right shape for "what
do I currently think of this place", where a second opinion should overwrite the first,
not pile up. But "when did I study here" is a different question with a different
shape: it's inherently many rows per (user, spot), one per occasion, and none of them
should overwrite another. Rather than stretch `spot_entries` to cover both — which would
mean giving up the `UNIQUE (user_id, spot_id)` constraint D2 relies on — visits get their
own table. Requiring an existing rating to log a visit (enforced in the API, not a DB
constraint — a cross-table CHECK isn't expressible) keeps the two concepts linked without
merging them: you can't log a visit to somewhere you've never rated.

### Why D10 exists

A single required category per spot doesn't support the two things tags are meant to
do: filtering ("show me quiet spots"), which needs multiple values per spot, not one;
and eventually recommending, which needs a signal that comes from many users'
opinions, not one person's category pick at add-spot time. Modeling tags the same way
as `group_study` — one user's call per entry, aggregated onto the spot — fits both
without inventing a new pattern.

Moderation (`users.is_admin`, `labels.status`) exists because "standardized" is the
whole point — an unmoderated free-text field gives you `#cozy`, `#Cozy`, and
`#cozyvibes` as three different tags, which defeats filtering and recommending just as
completely as no tags at all.

### Why D11 exists

A tag reads as either a compliment or a complaint — "Cozy" vs "Too loud" — and letting
the requester pick which is a hole in the same moderation story D10 just closed:
nothing stops someone submitting a negative-sounding tag labeled positive, or the
reverse. Moving that call to whoever approves the request (`POST
/admin/labels/{id}/approve` now takes `polarity` as a required argument) keeps it
consistent with the rest of the standardization story instead of trusting the
requester's own framing.

## What's built

v1 is in. `users`, `spots`, and `spot_entries` exist, with the add-spot, edit-spot
(`PUT /spots/{id}`, 2026-08-07), and delete-my-rating flows working end to end. Auth
(see "Still open" #1) and the `labels`/tag system (D10, plus polarity D11) are also
built. `spot_visits` (D12, 2026-08-23) is built too — log/list-per-spot/list-mine
endpoints, the Flutter "Log a visit"/"Past visits" buttons on the spot detail sheet, and
the Profile tab's study history. Postgres itself has been hosted on Neon since
2026-08-20 — see [infra.md](infra.md).

`follows`, `photos`, and `activity_events` are designed in this folder but **not built**
— they're v2/v3 in the build order below. [schema.sql](schema.sql) marks which is which.

**Client-only, not on the wire at all**: fuzzy search on the Spots tab and the
detail sheet's directions button are pure Flutter behavior with no server endpoint
behind them — see [mobile-app.md](mobile-app.md).

**Deferred fast-follows on the tag system, tracked here so they aren't silently
dropped**: an admin UI in the Flutter app (moderation is curl-only today, see
[api-contracts.md](api-contracts.md)), a spot-wide tag-cloud in the detail sheet (the
sheet shows my-own tags only), a server-side filter-by-tag endpoint (filtering is
100% client-side today, same as the old `type` filter was), a way to reopen a
`rejected` label slug (currently a manual DB edit), and any client-side use of a
label's `polarity` (D11) — the picker and filter chips don't distinguish it yet.

## Still open

These block specific pieces of work, not the schema as a whole:

1. ~~**Auth provider**~~ — **decided 2026-08-06: Firebase Auth, with email/password and
   Google Sign-In.** `auth_provider` + `auth_subject` on `users`, so the API never stores a
   password. Sign in with Apple is deferred; see the App Store condition in
   [auth-plan.md](auth-plan.md), which carries the full design — endpoints, client work,
   build order. **Built 2026-08-06: Phases 1-3** — every endpoint requires a valid
   Firebase token (or the fenced dev bypass), `GET`/`POST /me`, and the Flutter app
   signs in. Also built, ahead of the original plan: **guest mode** — the app starts an
   anonymous Firebase session automatically so nobody sees a sign-in wall, capped at 3
   spot entries, upgraded to a real account in place (same uid, same spots) via
   `POST /me`. **Refined 2026-08-23**: a real (non-guest) identity that reaches boot
   with a valid token but no `users` row — e.g. a cached session outliving a database
   reset — now gets its own `AuthPhase.needsRegistration` instead of a generic error
   screen; see [mobile-app.md](mobile-app.md). **Also built 2026-08-23**: email
   verification (a password-provider account must click its emailed link before
   choosing a handle — `AuthPhase.needsEmailVerification`, `VerifyEmailPage`) and the
   Google Sign-In provider call (`LoginPage`'s "Continue with Google", links from a
   guest session the same way email/password sign-up does) — **not yet verified
   end-to-end on a real device**. Still unbuilt: password reset, rate limiting, and
   the bypass-off hardening (Phase 5).
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
verified on a separate throwaway database instead. **Predates Neon hosting
(2026-08-20, see [infra.md](infra.md))** — whether the Neon project started from a
clean schema or inherited this same state hasn't been checked.
