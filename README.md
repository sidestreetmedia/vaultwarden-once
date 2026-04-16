# Vaultwarden for ONCE

A [Vaultwarden](https://github.com/dani-garcia/vaultwarden) Docker image packaged for [Basecamp's ONCE](https://github.com/basecamp/once) self-hosting platform. Run your own Bitwarden-compatible password vault alongside Campfire, Writebook, Fizzy, or any other ONCE-managed app — managed from a single dashboard with automatic SSL, backups, and updates.

## Why this exists

ONCE makes self-hosting Docker apps dead simple, but it expects apps to follow a specific contract. Vaultwarden doesn't do that out of the box. This image wraps the official `vaultwarden/server` image with the glue needed to make it a first-class ONCE citizen: an nginx reverse proxy for health checks, an entrypoint that translates ONCE's environment variables, and hook scripts for safe SQLite backups.

## How it works

ONCE requires three things from any compatible application:

- **Serve HTTP on port 80.** ONCE's built-in kamal-proxy handles SSL termination and routes traffic to each app container on port 80. It also health-checks each app by sending `GET /up` and expecting a `200` response.
- **Store persistent data in `/storage`.** ONCE mounts a volume here that persists across restarts and gets included in backups.
- **Be a Docker container.** ONCE pulls, runs, and manages the container lifecycle.

Vaultwarden's Rocket web server doesn't serve a `/up` health endpoint, and its base Docker image declares `/data` as a volume mount point (which can't be symlinked or replaced at runtime). This image solves both problems.

### Architecture

```
                    ┌─────────────────────────────────┐
                    │         Docker Container         │
                    │                                  │
  ONCE kamal-proxy  │   ┌─────────┐    ┌────────────┐ │
  ──── port 80 ────►│   │  nginx  │───►│ vaultwarden │ │
                    │   │  :80    │    │   :8080     │ │
                    │   └─────────┘    └────────────┘ │
                    │    /up → 200       DATA_FOLDER   │
                    │    /* → proxy      = /storage    │
                    └─────────────────────────────────┘
```

- **nginx** listens on port 80 inside the container. It returns `200 OK` on `/up` for the kamal-proxy health check and reverse-proxies everything else to Vaultwarden on `127.0.0.1:8080`, including WebSocket upgrades for live sync.
- **Vaultwarden** runs on port 8080 bound to localhost. The `DATA_FOLDER` environment variable points it at `/storage` so all persistent data lands in the ONCE-managed volume.
- **entrypoint.sh** translates ONCE's environment variables (SMTP settings, SSL mode) into their Vaultwarden equivalents, starts nginx, then execs into the Vaultwarden binary.

### Backup integration

Vaultwarden uses SQLite. Copying a live `.db` file while writes are in progress can produce a corrupt backup. ONCE supports optional hook scripts to handle this:

- `/hooks/pre-backup` runs `sqlite3 VACUUM INTO` to create a crash-consistent snapshot (`db.sqlite3.backup`) before ONCE copies the `/storage` volume. If the hook succeeds, ONCE copies files without pausing the container, so there's zero downtime during backups.
- `/hooks/post-restore` promotes the snapshot back to the primary database after a restore, and cleans up stale WAL/SHM files that would belong to the old database state.

## Installing with ONCE

### Prerequisites

- A server running ONCE (see [ONCE install instructions](https://github.com/basecamp/once))
- A DNS A record pointing your chosen hostname to the server's IP address

### Steps

1. Launch ONCE on your server and choose to install a new application.
2. When prompted for an image path, enter:

```
ghcr.io/sidestreetmedia/vaultwarden-once:main
```

3. Enter the hostname you've configured in DNS (e.g. `vault.example.com`).
4. ONCE pulls the image, mounts the `/storage` volume, configures SSL via Let's Encrypt, and boots the container.
5. Open the hostname in a browser. You'll see the Vaultwarden setup screen where you can create your first account.

### After install

- **Email delivery.** In the ONCE dashboard, press `s` on the app to open settings. Configure your SMTP provider under Email Settings. ONCE passes these values through to Vaultwarden automatically.
- **Backups.** Configure a backup location in ONCE settings. The pre-backup hook ensures SQLite snapshots are consistent without pausing the container.
- **Admin panel.** To enable Vaultwarden's admin panel, you'll need to set the `ADMIN_TOKEN` environment variable. This can be done by forking the image and setting it in your Dockerfile, or by passing it through ONCE if your version supports custom env vars.
- **Signups.** By default, Vaultwarden allows open registration. To restrict signups after creating your account, set `SIGNUPS_ALLOWED=false`.

## Building from source

### Automated (GitHub Actions)

Every push to `main` triggers the included GitHub Actions workflow, which builds the image and pushes it to GitHub Container Registry. No secrets to configure — the workflow uses the built-in `GITHUB_TOKEN` for GHCR authentication.

The default workflow tags the image as `:main`. If you want a `:latest` tag, update the tags section in `.github/workflows/docker-publish.yml` (or `build.yml`).

### Manual

```bash
git clone https://github.com/sidestreetmedia/vaultwarden-once.git
cd vaultwarden-once
docker build -t vaultwarden-once .
```

### Forking

To run your own fork with custom configuration:

1. Fork this repo to your own GitHub org.
2. The Actions workflow will build and push to your fork's GHCR namespace automatically.
3. In ONCE, switch the image path to your fork's registry path in the app settings.

## Running standalone (without ONCE)

For local testing or non-ONCE deployments:

```bash
docker run -d \
  --name vaultwarden \
  -p 80:80 \
  -v vaultwarden-data:/storage \
  -e DISABLE_SSL=true \
  -e DOMAIN=http://localhost \
  ghcr.io/sidestreetmedia/vaultwarden-once:main
```

Then open `http://localhost` in a browser.

## Environment variables

ONCE passes several environment variables to application containers. The entrypoint maps these to Vaultwarden's configuration:

| ONCE Variable | Vaultwarden Equivalent | Notes |
|---|---|---|
| `DISABLE_SSL` | `DOMAIN` scheme | When `true`, `DOMAIN` defaults to `http://`. Otherwise `https://`. |
| `SMTP_ADDRESS` | `SMTP_HOST` | SMTP server hostname |
| `SMTP_PORT` | `SMTP_PORT` | Also used to auto-detect `SMTP_SECURITY` (465→force_tls, 25→off, other→starttls) |
| `SMTP_USERNAME` | `SMTP_USERNAME` | Passed through directly |
| `SMTP_PASSWORD` | `SMTP_PASSWORD` | Passed through directly |
| `MAILER_FROM_ADDRESS` | `SMTP_FROM` | Sender address for outbound email |
| `SECRET_KEY_BASE` | — | Generated by ONCE. Not used by Vaultwarden but available if needed. |
| `NUM_CPUS` | — | Available for tuning but not mapped by default. |

Any native Vaultwarden environment variable (`ADMIN_TOKEN`, `SIGNUPS_ALLOWED`, `DOMAIN`, `LOG_LEVEL`, etc.) can be set alongside these and will work as expected. Explicitly set values always take precedence over the auto-mapped defaults.

## File layout

```
/etc/nginx/nginx.conf      ← Reverse proxy config (port 80 → 8080, /up health check)
/entrypoint.sh             ← ONCE env var mapping, starts nginx + vaultwarden
/hooks/pre-backup          ← SQLite VACUUM INTO snapshot before ONCE backup
/hooks/post-restore        ← Promote snapshot after ONCE restore
/storage/                  ← ONCE-managed persistent volume
  ├── db.sqlite3           ← Vaultwarden SQLite database
  ├── db.sqlite3.backup    ← Temporary pre-backup snapshot
  ├── rsa_key.pem          ← RSA private key (generated on first run)
  ├── rsa_key.pub.pem      ← RSA public key
  ├── attachments/         ← File attachments
  ├── sends/               ← Bitwarden Send files
  └── icon_cache/          ← Cached website favicons
```

## Updating

To pull in a newer upstream Vaultwarden release, push any commit to `main` (or trigger a manual workflow run from the Actions tab). The Dockerfile uses `vaultwarden/server:latest` as its base, so each build picks up the most recent stable release.

ONCE checks for new image versions periodically and can apply updates from its dashboard. You can also force an update from the ONCE app settings.

## Compatibility notes

- **Base image.** `vaultwarden/server:latest` is Debian-based (trixie). The Dockerfile installs packages via `apt-get`.
- **Volume mount.** The upstream vaultwarden image declares `/data` as a Docker `VOLUME`. This means `/data` cannot be removed, symlinked, or replaced at runtime. Instead of trying to redirect it, this image sets `DATA_FOLDER=/storage` to tell Vaultwarden to use the ONCE volume path directly.
- **Health checks.** ONCE's kamal-proxy sends `GET /up` to each container and expects a `200` response. Vaultwarden doesn't serve this endpoint natively, so nginx handles it.
- **WebSockets.** The nginx config includes WebSocket upgrade support for Vaultwarden's `/notifications/hub` endpoint, which is used for live sync across Bitwarden clients.
- **SSL.** ONCE handles SSL termination via kamal-proxy and Let's Encrypt. Vaultwarden runs plain HTTP inside the container. The `DOMAIN` variable is set to `https://` so that generated URLs and redirects reference the correct scheme.

## License

This packaging is provided as-is. Vaultwarden is licensed under [AGPL-3.0](https://github.com/dani-garcia/vaultwarden/blob/main/LICENSE.txt). ONCE is licensed under [MIT](https://github.com/basecamp/once/blob/main/MIT-LICENSE).
