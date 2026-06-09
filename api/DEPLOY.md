# Deploying the API (Fly.io + Turso)

The hosted API runs as a **stateless container on Fly.io** backed by **Turso**
(distributed SQLite). No volume — Turso is the durable store. Local development
still uses a SQLite file (see `README.md` / `docker-compose.yml`); only the
hosted path uses Turso.

```
local dev   →  sqlite        (pysqlite file on a Docker volume)
hosted/prod →  sqlite+libsql (Turso, remote)
```

## Prerequisites

- [Turso CLI](https://docs.turso.tech/cli/installation) (`turso`)
- [Fly CLI](https://fly.io/docs/flyctl/install/) (`flyctl` / `fly`)
- Accounts on both (free tiers are fine for this project)

## 1. Create the Turso database

```bash
turso auth login
turso db create volunteerly --location syd     # pick a region near your users
turso db show volunteerly --url                # → libsql://volunteerly-<org>.turso.io
turso db tokens create volunteerly             # → a long auth token
```

Build the SQLAlchemy URL from those two values (note `sqlite+libsql` scheme):

```
sqlite+libsql://volunteerly-<org>.turso.io/?authToken=<token>&secure=true
```

## 2. Create the Fly app

```bash
cd api
fly launch --no-deploy        # reuses fly.toml; pick a unique app name + region
```

If the app name in `fly.toml` is taken, change `app = "..."` to something unique.

## 3. Set the database secret

`DATABASE_URL` carries the auth token, so it must be a **secret**, not a plain
env var:

```bash
fly secrets set DATABASE_URL='sqlite+libsql://volunteerly-<org>.turso.io/?authToken=<token>&secure=true'
```

## 3a. Set the Cloudflare R2 image storage secrets

Image uploads use Cloudflare R2 (`volunteerly-media` bucket, APAC region).
Public URL: `https://pub-33ddcaa8fd164c628cabe79a0c47c85c.r2.dev`

Create an R2 API token in the Cloudflare dashboard (R2 → Manage R2 API Tokens →
Object Read & Write, scoped to `volunteerly-media`), then register the secrets
via the Render API or dashboard:

```bash
SERVICE_ID="srv-d8h1p77lk1mc73du96fg"
RENDER_API_KEY="<your-render-api-key>"   # Account Settings → API Keys

curl -X PUT "https://api.render.com/v1/services/$SERVICE_ID/env-vars" \
  -H "Authorization: Bearer $RENDER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '[
    {"key":"R2_ACCOUNT_ID",        "value":"d4fb1e522dd02b4f362c049b6580b064"},
    {"key":"R2_ACCESS_KEY_ID",     "value":"<r2-access-key-id>"},
    {"key":"R2_SECRET_ACCESS_KEY", "value":"<r2-secret-access-key>"},
    {"key":"R2_BUCKET",            "value":"volunteerly-media"},
    {"key":"R2_PUBLIC_URL",        "value":"https://pub-33ddcaa8fd164c628cabe79a0c47c85c.r2.dev"}
  ]'
```

Then trigger a redeploy: Render dashboard → Manual Deploy, or via API:

```bash
curl -X POST "https://api.render.com/v1/services/$SERVICE_ID/deploys" \
  -H "Authorization: Bearer $RENDER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"clearCache":"do_not_clear"}'
```

Use a **write-only** token (no list/delete permissions) to limit blast radius if
the key is ever leaked.

## 4. Deploy

```bash
fly deploy
```

On deploy Fly:
1. builds the `prod` image (compiles the libSQL Rust driver remotely),
2. runs `release_command = "alembic upgrade head"` against Turso (creates tables),
3. starts the container.

Get the public URL:

```bash
fly status        # https://volunteerly-api.fly.dev
curl https://<app>.fly.dev/health
```

## 5. (Optional) Seed demo data

To load the same fixtures the iOS app mocks, run the seed script once on a
machine:

```bash
fly ssh console -C "python scripts/seed.py"
```

(or run it locally with `DATABASE_URL` pointed at Turso). Skip this for real data.

## 6. Point the iOS app at it

In `volunteerly/Core/Networking/HTTPClient.swift`, set
`LiveHTTPClient.baseURL` to `https://<app>.fly.dev` and switch the app from
`MockHTTPClient` to `LiveHTTPClient`.

## Notes

- **Cold starts:** `fly.toml` scales to zero when idle (`min_machines_running = 0`)
  to save the free allowance — the first request after a nap is slow. Before a
  demo, set `min_machines_running = 1` (or `fly scale count 1`) to keep it warm.
- **Migrations on every deploy:** the release command runs `alembic upgrade head`
  automatically. Create new migrations locally with `mise run "migrate:create"`.
- **Logs:** `fly logs` (structured JSON in non-local envs).
- **/docs:** reachable because `PROJECT_ENV=staging`. Set it to `prod` in
  `fly.toml` to hide docs and generic-ify error messages.
