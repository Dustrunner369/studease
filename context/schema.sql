-- Studease — target Postgres schema (PostgreSQL 15+)
--
-- REFERENCE ONLY. EF Core migrations in backend/Migrations are the source of truth;
-- this file is what those migrations should produce. Keep them in step.
--
-- STATUS: users, spots, spot_entries, labels, spot_entry_tags, spot_tag_counts and
-- spot_visits are BUILT and verified against Postgres 15. follows, photos and
-- activity_events are DESIGNED ONLY — v2/v3 in the build order.
--
-- Conventions: snake_case, uuid PKs (UUIDv7 minted by the app), timestamptz in UTC,
-- enums as text + CHECK. See data-model.md for the reasoning behind each.

-- ---------------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------------

CREATE TABLE users (
    id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    handle         text        NOT NULL,
    display_name   text        NOT NULL,
    email          text,
    -- Identity comes from an external provider; no password ever lands here.
    auth_provider  text        NOT NULL,
    auth_subject   text        NOT NULL,
    avatar_url     text,
    bio            text,
    is_private     boolean     NOT NULL DEFAULT false,
    -- The schema's first permission field, deliberately minimal: one boolean gating
    -- the label-moderation endpoints. Not a roles table; no self-serve way to become
    -- admin, promotion is a manual UPDATE.
    is_admin       boolean     NOT NULL DEFAULT false,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,

    CONSTRAINT users_handle_format CHECK (handle ~ '^[a-zA-Z0-9_]{3,30}$'),
    CONSTRAINT users_auth_identity_unique UNIQUE (auth_provider, auth_subject)
);

-- Handles are unique case-insensitively. Built as a plain unique index with handles
-- stored already-lowercased, rather than an expression index on lower(handle) — EF
-- can express the former in a migration and not the latter.
CREATE UNIQUE INDEX users_handle_key ON users (handle);

-- ---------------------------------------------------------------------------
-- spots — one row per real-world place, shared by every user
-- ---------------------------------------------------------------------------

CREATE TABLE spots (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- The dedupe key. Two users adding the same cafe resolve to the same Place ID
    -- and therefore the same row.
    --
    -- Nullable (decision D9): a campus study room or a specific library floor isn't a
    -- Google Place at all, so manual entry has to be possible. The uniqueness that
    -- matters is enforced by a partial index below, not by this column.
    google_place_id   text,

    -- Snapshot of Places data, refreshed on a schedule. Stored so a list of spots
    -- renders without one API call per row. NOT a permanent copy — see data-model.md
    -- on Google's caching terms.
    name              text        NOT NULL,
    formatted_address text,
    -- Null for manually entered spots: typed addresses aren't geocoded, so those
    -- spots stay off the Map tab until someone links them to a real place.
    latitude          double precision,
    longitude         double precision,
    price_level       smallint,
    website_url       text,
    phone             text,
    -- Offset from UTC at this place, used to work out its local "now" when deciding
    -- what time it closes today. From Places; null for manual spots.
    utc_offset_minutes integer,
    places_synced_at  timestamptz,

    -- No type column: replaced by the global label/tag system below (decision D10,
    -- 2026-08-06). Tags are per-entry (spot_entry_tags), aggregated onto spot_tag_counts.

    added_by          uuid        REFERENCES users (id) ON DELETE SET NULL,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    -- Cached aggregates over non-private entries. Derived data: recomputed in the
    -- same transaction as any spot_entries write. spot_entries is the truth.
    entry_count       integer     NOT NULL DEFAULT 0,
    avg_score         numeric(3,1),
    avg_wifi          numeric(2,1),
    avg_noise         numeric(2,1),
    avg_outlets       numeric(2,1),
    avg_seating       numeric(2,1),
    avg_table_size    numeric(2,1),
    avg_coffee        numeric(2,1),
    -- No avg_group_study on purpose: it stays one user's verdict, never rolled up.

    -- Total spot_visits rows ever logged here, across all users. Incremented at write
    -- time and decremented on delete (D13), not recomputed from scratch — visits are
    -- never edited in place, only added or removed outright, so there's nothing to
    -- desync it. Not surfaced anywhere yet (D12).
    visit_count       integer     NOT NULL DEFAULT 0,

    -- NOTE: deliberately no opening-hours column. Hours are fetched live from the
    -- Places API at render time (decision D8).

    CONSTRAINT spots_price_range CHECK (price_level IS NULL OR price_level BETWEEN 0 AND 4),
    CONSTRAINT spots_lat_range   CHECK (latitude  IS NULL OR latitude  BETWEEN  -90 AND  90),
    CONSTRAINT spots_lng_range   CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

-- Unique only where present, so Places-backed spots still dedupe exactly while
-- manually entered spots don't all collide on NULL.
CREATE UNIQUE INDEX spots_google_place_id_key ON spots (google_place_id)
    WHERE google_place_id IS NOT NULL;

-- Good enough for bounding-box "spots near me". If the Map tab needs true radius
-- search or distance sorting, add PostGIS: a geography(Point,4326) column with a
-- GiST index. Don't bother until the map is real.
CREATE INDEX spots_lat_lng_idx ON spots (latitude, longitude);

-- ---------------------------------------------------------------------------
-- spot_entries — one user's opinion of one spot
-- ---------------------------------------------------------------------------

CREATE TABLE spot_entries (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    spot_id      uuid        NOT NULL REFERENCES spots (id) ON DELETE CASCADE,

    -- Six required ratings, 1-5, ALL "higher is better".
    -- noise:      5 = quiet. Inverted on purpose — see data-model.md.
    -- table_size: 5 = big shared tables you can spread out on.
    wifi         smallint    NOT NULL,
    noise        smallint    NOT NULL,
    outlets      smallint    NOT NULL,
    seating      smallint    NOT NULL,
    table_size   smallint    NOT NULL,
    coffee       smallint    NOT NULL,

    -- Does this place work for studying with other people? One user's verdict, not a
    -- fact about the place — two people may disagree about the same spot.
    group_study  boolean     NOT NULL DEFAULT false,

    -- 0-10 score, computed by the database so all three clients agree.
    -- Sum of 5..25 maps onto 2.0..10.0.
    --
    -- table_size is rated but deliberately absent here: the 0.4 is what maps FIVE
    -- ratings onto a 10-point ceiling, and a sixth term (divisor 3.0 instead) would
    -- rebase every score already stored. Changing this means DROP and re-ADD of the
    -- column — a generated expression cannot be ALTERed in place.
    score        numeric(3,1) GENERATED ALWAYS AS
                     (ROUND((wifi + noise + outlets + seating + coffee) * 0.4, 1)) STORED,

    -- Optional, free text, never parsed.
    coffee_order text,
    notes        text,

    visibility   text        NOT NULL DEFAULT 'public',
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),

    -- One entry per user per spot: re-rating is an UPDATE, not an INSERT.
    CONSTRAINT spot_entries_user_spot_unique UNIQUE (user_id, spot_id),
    -- Target for the composite FK from photos; keeps a photo's entry and spot in step.
    CONSTRAINT spot_entries_id_spot_unique   UNIQUE (id, spot_id),

    CONSTRAINT spot_entries_visibility_valid CHECK (visibility IN ('public', 'followers', 'private')),
    CONSTRAINT spot_entries_wifi_range    CHECK (wifi    BETWEEN 1 AND 5),
    CONSTRAINT spot_entries_noise_range   CHECK (noise   BETWEEN 1 AND 5),
    CONSTRAINT spot_entries_outlets_range CHECK (outlets BETWEEN 1 AND 5),
    CONSTRAINT spot_entries_seating_range CHECK (seating BETWEEN 1 AND 5),
    CONSTRAINT spot_entries_table_size_range CHECK (table_size BETWEEN 1 AND 5),
    CONSTRAINT spot_entries_coffee_range  CHECK (coffee  BETWEEN 1 AND 5)
);

-- Drives the Spots tab: my entries, ranked.
CREATE INDEX spot_entries_user_score_idx ON spot_entries (user_id, score DESC, updated_at DESC);
-- Drives a spot's detail sheet: who else rated this.
CREATE INDEX spot_entries_spot_idx       ON spot_entries (spot_id) WHERE visibility <> 'private';

-- ---------------------------------------------------------------------------
-- spot_visits — "I'm studying here today", an append-only log layered alongside
-- spot_entries, not replacing it (decision D12, 2026-08-23). "Append-only" means
-- rows are never edited in place, not that they're permanent — a whole row can be
-- deleted outright to undo a mislog (decision D13, 2026-08-24); see the API layer,
-- there's no DB-level cascade or trigger for it.
-- ---------------------------------------------------------------------------

CREATE TABLE spot_visits (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    spot_id      uuid        NOT NULL REFERENCES spots (id) ON DELETE CASCADE,

    -- Optional, free text, never parsed — same treatment as spot_entries.notes /
    -- coffee_order (D6).
    studied      text,
    drink_order  text,

    -- Stamped server-side at creation, never client-supplied — logging is always
    -- "today", not backdated. No updated_at: rows are never edited.
    visited_at   timestamptz NOT NULL DEFAULT now()

    -- No UNIQUE (user_id, spot_id) — the opposite of spot_entries on purpose. Unlimited
    -- rows per (user, spot); every visit is an insert, never an update.
    --
    -- "Requires an existing spot_entries row for the same (user, spot)" is enforced in
    -- the API, not here — a cross-table CHECK referencing another table isn't
    -- expressible in Postgres the way the photos.entry_id/spot_id composite FK is.
);

-- Drives "my study history" (/me/visits): mine, newest first.
CREATE INDEX spot_visits_user_visited_idx ON spot_visits (user_id, visited_at DESC);
-- Drives "past visits at this spot" (/spots/{id}/visits): mine, at this spot, newest first.
CREATE INDEX spot_visits_spot_user_visited_idx ON spot_visits (spot_id, user_id, visited_at DESC);

-- ---------------------------------------------------------------------------
-- labels — the standardized, global tag vocabulary that replaced spots.type
-- (decision D10, 2026-08-06)
-- ---------------------------------------------------------------------------

CREATE TABLE labels (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Lowercase alphanumeric only, no separators — hashtag-shaped ("#cozy",
    -- "#bestforreading"), deliberately not kebab-case. A hyphen breaks the #slug
    -- rendering everywhere this shows up, the way #best-for-reading reads as broken
    -- on every platform that has hashtags. "Best for reading" -> "bestforreading".
    slug          text        NOT NULL,
    -- The human-readable form, as typed — can't be losslessly reconstructed from
    -- slug, so stored separately. Mainly seen in the moderation queue.
    display_name  text        NOT NULL,

    -- pending until an admin reviews it. Only approved labels are usable — in the
    -- picker, or as a tagSlugs value on PUT .../entry.
    status        text        NOT NULL DEFAULT 'pending',

    -- Null until approved. A tag reads as either a compliment or a complaint
    -- ("Cozy" vs "Too loud") — the requester never picks this (see
    -- RequestLabelRequest), it's decided by whoever approves the request
    -- (decision D11, 2026-08-17), which stops a requester sneaking a
    -- negative-sounding tag in as positive or vice versa.
    polarity      text,

    requested_by  uuid        REFERENCES users (id) ON DELETE SET NULL,
    -- Set on rejection too, not only approval — "who reviewed this".
    approved_by   uuid        REFERENCES users (id) ON DELETE SET NULL,

    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT labels_slug_format    CHECK (slug ~ '^[a-z0-9]{2,30}$'),
    CONSTRAINT labels_status_valid   CHECK (status IN ('pending', 'approved', 'rejected')),
    CONSTRAINT labels_polarity_valid CHECK (polarity IN ('positive', 'negative'))
);

-- A rejected slug is permanently blocked from being re-requested — no "reconsider"
-- endpoint; an admin re-opens it by hand-editing the row if it ever matters.
CREATE UNIQUE INDEX labels_slug_key ON labels (slug);

-- ---------------------------------------------------------------------------
-- spot_entry_tags — join table: which entries carry which labels. One user's
-- opinion, like group_study — see spot_entries.group_study above. No columns
-- beyond the two foreign keys; an entry's own user_id already answers "who tagged
-- it".
-- ---------------------------------------------------------------------------

CREATE TABLE spot_entry_tags (
    spot_entry_id uuid NOT NULL REFERENCES spot_entries (id) ON DELETE CASCADE,
    label_id      uuid NOT NULL REFERENCES labels (id)       ON DELETE CASCADE,

    PRIMARY KEY (spot_entry_id, label_id)
);

CREATE INDEX spot_entry_tags_label_idx ON spot_entry_tags (label_id);

-- ---------------------------------------------------------------------------
-- spot_tag_counts — cached rollup: how many of a spot's (non-private) entries
-- carry each label. Rebuilt from scratch (delete everything for the spot,
-- re-derive) in the same recompute pass as spots.avg_*, whenever an entry is
-- written or deleted. spot_entries (via spot_entry_tags) is the source of truth;
-- this is derived data, same rule as every other cached aggregate in this file.
--
-- Doubles as the feature matrix a future recommender would want (spot x label
-- weights) — not used for that yet, just a free byproduct of following the
-- existing aggregate pattern rather than a live JOIN.
-- ---------------------------------------------------------------------------

CREATE TABLE spot_tag_counts (
    spot_id     uuid    NOT NULL REFERENCES spots (id)  ON DELETE CASCADE,
    label_id    uuid    NOT NULL REFERENCES labels (id) ON DELETE CASCADE,
    entry_count integer NOT NULL,

    PRIMARY KEY (spot_id, label_id)
);

CREATE INDEX spot_tag_counts_label_idx ON spot_tag_counts (label_id);

-- ---------------------------------------------------------------------------
-- follows                                                    (DESIGNED, NOT BUILT)
-- ---------------------------------------------------------------------------

CREATE TABLE follows (
    follower_id uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    followee_id uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    -- Public accounts go straight to 'accepted'; private accounts approve a 'pending' row.
    status      text        NOT NULL DEFAULT 'accepted',
    created_at  timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (follower_id, followee_id),
    CONSTRAINT follows_no_self   CHECK (follower_id <> followee_id),
    CONSTRAINT follows_status_valid CHECK (status IN ('pending', 'accepted'))
);

-- "Who follows me" / pending-request list. The PK already covers "who I follow".
CREATE INDEX follows_followee_idx ON follows (followee_id, status);

-- ---------------------------------------------------------------------------
-- photos — metadata only; bytes live in object storage      (DESIGNED, NOT BUILT)
-- ---------------------------------------------------------------------------

CREATE TABLE photos (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id      uuid        NOT NULL REFERENCES spots (id) ON DELETE CASCADE,
    -- NULL = a photo of the place. Set = a photo taken with someone's rating.
    entry_id     uuid,
    uploaded_by  uuid        REFERENCES users (id) ON DELETE SET NULL,

    -- Object key in blob storage. The public URL is derived at read time so the
    -- bucket or CDN can change without a migration.
    storage_key  text        NOT NULL UNIQUE,
    content_type text        NOT NULL,
    width        integer,
    height       integer,
    byte_size    integer,
    caption      text,

    created_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz,

    -- Makes it structurally impossible to attach a photo to an entry for a
    -- different spot. NULL entry_id skips the check (MATCH SIMPLE).
    CONSTRAINT photos_entry_matches_spot
        FOREIGN KEY (entry_id, spot_id) REFERENCES spot_entries (id, spot_id) ON DELETE CASCADE
);

CREATE INDEX photos_spot_idx  ON photos (spot_id) WHERE deleted_at IS NULL;
CREATE INDEX photos_entry_idx ON photos (entry_id) WHERE entry_id IS NOT NULL AND deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- activity_events — append-only feed source                 (DESIGNED, NOT BUILT)
-- ---------------------------------------------------------------------------

CREATE TABLE activity_events (
    -- UUIDv7 from the app: time-ordered, so this doubles as the pagination cursor.
    id             uuid        PRIMARY KEY,
    actor_id       uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    verb           text        NOT NULL,

    -- Which of these is set depends on the verb.
    spot_id        uuid        REFERENCES spots (id)        ON DELETE CASCADE,
    entry_id       uuid        REFERENCES spot_entries (id) ON DELETE CASCADE,
    photo_id       uuid        REFERENCES photos (id)       ON DELETE CASCADE,
    target_user_id uuid        REFERENCES users (id)        ON DELETE CASCADE,

    visibility     text        NOT NULL DEFAULT 'public',
    created_at     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT activity_verb_valid CHECK (verb IN (
        'rated_spot', 'updated_rating', 'added_spot', 'added_photo', 'followed_user')),
    CONSTRAINT activity_visibility_valid CHECK (visibility IN ('public', 'followers', 'private'))
);

CREATE INDEX activity_actor_idx ON activity_events (actor_id, id DESC) WHERE visibility <> 'private';

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
--
-- NOT BUILT AS TRIGGERS. AppDbContext.StampTimestamps() sets created_at/updated_at
-- in SaveChanges instead, which keeps the behaviour visible in C# rather than hidden
-- in SQL a reader of the entity classes would never think to look for.
--
-- The trigger version is kept here for anyone who'd rather push it into the database
-- — if you switch, delete StampTimestamps() so the two don't fight.
--
-- CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
-- BEGIN
--     NEW.updated_at = now();
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE TRIGGER users_updated_at        BEFORE UPDATE ON users
--     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- CREATE TRIGGER spots_updated_at        BEFORE UPDATE ON spots
--     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- CREATE TRIGGER spot_entries_updated_at BEFORE UPDATE ON spot_entries
--     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
