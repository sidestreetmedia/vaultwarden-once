# Vaultwarden for ONCE

A [Vaultwarden](https://github.com/dani-garcia/vaultwarden) Docker image packaged for [Basecamp's ONCE](https://github.com/basecamp/once) self-hosting platform.

## What this does

ONCE expects any compatible application to:

1. **Serve HTTP on port 80** — Vaultwarden's Rocket server already does this.
2. **Store persistent data in `/storage`** — The entrypoint symlinks `/data → /storage` so Vaultwarden reads and writes to the ONCE-managed volume.
3. **Be a Docker container** — This wraps the official `vaultwarden/server` image.

On top of the bare minimum, this image also integrates with ONCE's optional features:

- **Backup hooks** — `/hooks/pre-backup` uses `sqlite3 VACUUM INTO` to create a crash-consistent snapshot before ONCE copies the volume. `/hooks/post-restore` promotes that snapshot back to the primary DB after a restore.
- **Environment variable mapping** — ONCE's `SMTP_*`, `DISABLE_SSL`, and `MAILER_FROM_ADDRESS` variables are translated to their Vaultwarden equivalents at startup.

## Building

### Automated (GitHub Actions)

Push this repo to `github.com/sidestreetmedia/vaultwarden-once` and the included workflow will automatically build multi-arch images (amd64 + arm64) and push them to `ghcr.io/sidestreetmedia/vaultwarden-once:latest`.

No secrets to configure — the workflow uses the built-in `GITHUB_TOKEN` for GHCR auth.

### Manual

```bash
docker build -t vaultwarden-once .
```

## Installing with ONCE

When ONCE prompts you for an image path, enter the registry path where you pushed the built image. For example:

```
ghcr.io/youruser/vaultwarden-once:latest
```

ONCE will handle the rest — pulling the image, mounting `/storage`, generating `SECRET_KEY_BASE`, and configuring SSL and email if you set those up in the ONCE UI.

## Running standalone (without ONCE)

You can also run this image directly with Docker for testing:

```bash
docker run -d \
  --name vaultwarden \
  -p 80:80 \
  -v vaultwarden-data:/storage \
  -e DISABLE_SSL=true \
  -e DOMAIN=http://localhost \
  vaultwarden-once
```

## Environment variables

| Variable | Source | Effect |
|---|---|---|
| `DISABLE_SSL` | ONCE | When `true`, `DOMAIN` defaults to `http://` instead of `https://` |
| `SMTP_ADDRESS` | ONCE | Mapped to Vaultwarden's `SMTP_HOST` |
| `SMTP_PORT` | ONCE | Passed through; also used to infer `SMTP_SECURITY` |
| `SMTP_USERNAME` | ONCE | Passed through |
| `SMTP_PASSWORD` | ONCE | Passed through |
| `MAILER_FROM_ADDRESS` | ONCE | Mapped to Vaultwarden's `SMTP_FROM` |
| `DOMAIN` | User/override | Full external URL (e.g. `https://vault.example.com`) |

Any other Vaultwarden environment variable (like `SIGNUPS_ALLOWED`, `ADMIN_TOKEN`, etc.) can still be passed through and will work as normal.

## File layout inside the container

```
/storage/              ← ONCE-managed persistent volume
  db.sqlite3           ← Vaultwarden SQLite database
  db.sqlite3.backup    ← Pre-backup snapshot (temporary)
  attachments/         ← File attachments
  sends/               ← Bitwarden Send files
  icon_cache/          ← Cached website icons
/data → /storage       ← Symlink so vaultwarden finds its data
/hooks/pre-backup      ← Safe SQLite snapshot before backup
/hooks/post-restore    ← Promote snapshot after restore
/entrypoint.sh         ← Env var mapping + launch
```
