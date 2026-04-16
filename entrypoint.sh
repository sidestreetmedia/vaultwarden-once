#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# ONCE mounts persistent storage at /storage. Vaultwarden expects /data.
# Create /data as a symlink so vaultwarden reads/writes to the ONCE volume.
# ---------------------------------------------------------------------------
if [ -d /storage ]; then
    # If /data already exists as a real directory, move any seed content over
    if [ -d /data ] && [ ! -L /data ]; then
        cp -rn /data/* /storage/ 2>/dev/null || true
        rm -rf /data
    fi
    ln -sfn /storage /data
else
    # Fallback: no ONCE volume, just use /data directly (standalone mode)
    mkdir -p /data
fi

# ---------------------------------------------------------------------------
# Map ONCE environment variables to Vaultwarden equivalents
# ---------------------------------------------------------------------------

# DISABLE_SSL — tell vaultwarden whether the external URL uses HTTPS
if [ "$DISABLE_SSL" = "true" ]; then
    export DOMAIN="${DOMAIN:-http://localhost}"
    export ROCKET_TLS=""
else
    # When ONCE handles SSL, vaultwarden still serves plain HTTP on port 80,
    # but outbound links/redirects should reference https.
    export DOMAIN="${DOMAIN:-https://localhost}"
fi

# SMTP settings — ONCE passes these from its Email Settings UI
if [ -n "$SMTP_ADDRESS" ]; then
    export SMTP_HOST="${SMTP_HOST:-$SMTP_ADDRESS}"
    export SMTP_FROM="${SMTP_FROM:-${MAILER_FROM_ADDRESS:-vaultwarden@example.com}}"

    # Map port to a sensible security setting if not already set
    if [ -z "$SMTP_SECURITY" ]; then
        case "${SMTP_PORT:-587}" in
            465) export SMTP_SECURITY="force_tls" ;;
            25)  export SMTP_SECURITY="off" ;;
            *)   export SMTP_SECURITY="starttls" ;;
        esac
    fi
    export SMTP_PORT="${SMTP_PORT:-587}"
    export SMTP_USERNAME="${SMTP_USERNAME:-}"
    export SMTP_PASSWORD="${SMTP_PASSWORD:-}"
fi

# Vaultwarden listens on port 80 by default via ROCKET_PORT
export ROCKET_PORT="${ROCKET_PORT:-80}"
export ROCKET_ADDRESS="${ROCKET_ADDRESS:-0.0.0.0}"

# Data folder (now points to /storage via symlink)
export DATA_FOLDER="${DATA_FOLDER:-/data}"

# ---------------------------------------------------------------------------
# Launch vaultwarden
# ---------------------------------------------------------------------------
exec /vaultwarden
