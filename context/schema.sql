-- Studease — target Postgres schema (PostgreSQL 15+)
--
-- REFERENCE ONLY. EF Core migrations in backend/Migrations are the source of truth;
-- this file is what those migrations should produce. Keep them in step.
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
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,

    CONSTRAINT users_handle_format CHECK (handle ~ '^[a-zA-Z0-9_]{3,30}$'),
    CONSTRAINT users_auth_identity_unique UNIQUE (auth_provider, auth_subject)
);

-- Handles are unique case-insensitively: @Matt and @matt are the same person.
CREATE UNIQUE INDEX users_handle_lower_key ON users (lower(handle));
CREATE UNIQUE INDEX users_email_lower_key  ON users (lower(email)) WHERE email IS NOT NULL;

-- ---------------------------------------------------------------------------
-- spots — one row per real-world place, shared by every user
-- ---------------------------------------------------------------------------

CREATE TABLE spots (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- The dedupe key. Two users adding the same cafe resolve to the same Place ID
    -- and therefore the same row.
    google_place_id   text        NOT NULL UNIQUE,

    -- Snapshot of Places data, refreshed on a schedule. Stored so a list of spots
    -- renders without one API call per row. NOT a permanent copy — see data-model.md
    -- on Google's caching terms.
    name              text        NOT NULL,
    formatted_address text,
    latitude          double precision NOT NULL,
    longitude         double precision NOT NULL,
    price_level       smallint,
    website_url       text,
    phone             text,
    places_synced_at  timestamptz,

    -- Derived from Places `types` at creation, then user-editable.
    type              text        NOT NULL DEFAULT 'cafe',

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
    avg_coffee        numeric(2,1),

    -- NOTE: deliberately no opening-hours column. Hours are fetched live from the
    -- Places API at render time (decision D8).

    CONSTRAINT spots_type_valid  CHECK (type IN ('cafe', 'library', 'campus', 'other')),
    CONSTRAINT spots_price_range CHECK (price_level BETWEEN 0 AND 4),
    CONSTRAINT spots_lat_range   CHECK (latitude  BETWEEN  -90 AND  90),
    CONSTRAINT spots_lng_range   CHECK (longitude BETWEEN -180 AND 180)
);

CREATE INDEX spots_type_idx    ON spots (type);
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

    -- Five required ratings, 1-5, ALL "higher is better".
    -- noise: 5 = quiet. Inverted on purpose — see data-model.md.
    wifi         smallint    NOT NULL,
    noise        smallint    NOT NULL,
    outlets      smallint    NOT NULL,
    seating      smallint    NOT NULL,
    coffee       smallint    NOT NULL,

    -- 0-10 score, computed by the database so all three clients agree.
    -- Sum of 5..25 maps onto 2.0..10.0.
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
    CONSTRAINT spot_entries_coffee_range  CHECK (coffee  BETWEEN 1 AND 5)
);

-- Drives the Spots tab: my entries, ranked.
CREATE INDEX spot_entries_user_score_idx ON spot_entries (user_id, score DESC, updated_at DESC);
-- Drives a spot's detail sheet: who else rated this.
CREATE INDEX spot_entries_spot_idx       ON spot_entries (spot_id) WHERE visibility <> 'private';

-- ---------------------------------------------------------------------------
-- follows
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
-- photos — metadata only; bytes live in object storage
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
-- activity_events — append-only feed source, fanned out on read
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

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at        BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER spots_updated_at        BEFORE UPDATE ON spots
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER spot_entries_updated_at BEFORE UPDATE ON spot_entries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
