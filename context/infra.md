# Infra & deployment

Hosting, local dev environment, and the connection-string plumbing between them. None
of this changes the data model or the wire contract — see [data-model.md](data-model.md)
and [api-contracts.md](api-contracts.md) for those.

## Database: Neon

**Built 2026-08-20.** Postgres is hosted on [Neon](https://neon.tech) — branchable,
serverless Postgres — rather than a local-only database. `.neon` holds the project
pointer (`orgId`, `projectId`; not secrets, just Neon's own project id) and `.mcp.json`
wires up Neon's MCP server; `.agents/skills/neon/SKILL.md` and
`.agents/skills/neon-postgres/SKILL.md` are Neon's own agent-skill docs, checked into
the repo so an agent picks them up automatically for anything Postgres-shaped.

**Two connection strings, not one** — `Program.cs` reads both:

| Env var | `appsettings` key | Used for |
| --- | --- | --- |
| `DATABASE_URL` | `ConnectionStrings:DefaultConnection` | Pooled — every request the running app serves |
| `DATABASE_URL_UNPOOLED` | `ConnectionStrings:Migrations` | Direct/unpooled — `Database.Migrate()` at startup, nothing else |

The split exists because Neon pools through PgBouncer, and PgBouncer's transaction
pooling mode doesn't reliably support the advisory locks and session state EF's
migrator relies on. Migrations run over the unpooled connection specifically to avoid
that failure mode; the app's normal request traffic stays on the pooled one.

Neon hands out `postgres://` URIs; Npgsql only understands keyword=value ADO.NET
connection strings. `Program.cs`'s `NormalizeConnectionString` parses the URI (when it
sees one — a local dev override in ADO.NET format passes through unchanged) and rebuilds
it via `NpgsqlConnectionStringBuilder`, forcing `SslMode.Require`. This runs on both
connection strings before either is used, so `DefaultConnection` and `Migrations` are
both Neon-shaped in this codebase, but the function itself doesn't assume that.

## Environment variables (`.env`, gitignored)

| Variable | Purpose |
| --- | --- |
| `PLACES_API_KEY` | Google Places API key, proxied server-side — see `GET /places/search` in [api-contracts.md](api-contracts.md). Never shipped to a client. |
| `NEON_BRANCH` | Which Neon branch this environment points at. |
| `DATABASE_URL` | Pooled Postgres connection (see above). |
| `DATABASE_URL_UNPOOLED` | Direct Postgres connection, migrations only (see above). |
| `NEON_AI_GATEWAY_TOKEN` / `NEON_AI_GATEWAY_BASE_URL` | Part of the Neon project scaffold. **Unused** — nothing in this codebase calls the AI Gateway. |

## Local dev: `docker-compose.yaml`

Runs two services: `frontend` (Angular, port `4200`) and `backend` (.NET, port `5001`
mapped to the container's `8080`). **There is no `db` service** — `backend`'s
`ConnectionStrings__DefaultConnection`/`Migrations` point at Neon over the network even
in local dev, so there's no local Postgres container to keep in sync. `PLACES_API_KEY`
is passed through from the host `.env`.

## Migration-on-boot risk

`Program.cs` runs `db.Database.Migrate()` (over the unpooled connection above) on every
process start. Fine while this is a one-person project against a throwaway branch; once
real user data lives on Neon, a container restart is one bad migration away from running
against it unattended. [auth-plan.md](auth-plan.md) Phase 5 calls for making this a
deliberate step — a manual/CI `dotnet ef database update` — instead of an implicit boot
action. Still open.

## Open question carried over from before Neon hosting

[README.md](README.md)'s original gotcha about a local `appdb` still carrying the old
`StudySpots` table (and tripping the `__EFMigrationsHistory` snake_case rename problem
on the next `dotnet ef database update`) predates this move. Whether Neon's project
started from a clean schema and applied every migration in order from scratch, or
inherited that same local database's state, hasn't been checked — worth confirming
before relying on either assumption.
