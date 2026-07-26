# Studease — context

Design docs that describe the *intended* data model, as agreed 2026-07-25. These are
specs, not generated output: when the code and these docs disagree, one of them is a bug.

| File | What it covers |
| --- | --- |
| [data-model.md](data-model.md) | Entities, relationships, invariants, build order, migration off today's schema |
| [schema.sql](schema.sql) | Postgres DDL for the target model (reference — EF migrations stay the source of truth) |
| [api-contracts.md](api-contracts.md) | JSON shapes on the wire, shared by the .NET API, Flutter app, and Angular web app |

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
| D4 | Google Places-backed identity | `spots.google_place_id` is `NOT NULL UNIQUE` — the dedupe key |
| D5 | Five 1–5 categories: wifi, noise, outlets, seating, coffee | Score is derived from them, not entered |
| D6 | Coffee order + notes are optional free text | Nullable columns on the entry, no validation |
| D7 | Follows + activity feed, photos on spots and entries | Modeled; want-to-go lists and likes/comments are **not** |
| D8 | Hours pulled live from Places, never stored | No `hours` column anywhere; `openUntil` is a response field, not a database field |

## Still open

These block specific pieces of work, not the schema as a whole:

1. **Auth provider** — blocks `users` landing. Recommendation: an external IdP
   (Auth0/Clerk/Supabase/Firebase) with `auth_provider` + `auth_subject` on `users`, so
   the API never stores a password. ASP.NET Core Identity is the alternative if you'd
   rather keep it in-process.
2. **Photo storage** — blocks the `photos` table being useful. Recommendation: S3-compatible
   object storage (R2, Supabase Storage) with `storage_key` in Postgres and the URL derived
   at read time. A local Docker volume works for development.
3. **Places API cost controls** — Autocomplete is billed per keystroke-session. Use session
   tokens on the add-spot search. Not a schema concern, but it will surprise you otherwise.
4. **Ranked list tie-breaking** — the Spots tab is ranked by score; two 8.4s need a stable
   order. Recommendation: `score DESC, updated_at DESC, id`.
