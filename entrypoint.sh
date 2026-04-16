#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# ONCE mounts persistent storage at /storage. The base vaultwarden image
# declares /data as a VOLUME so it can't be removed or symlinked. Instead,
# just point Vaultwarden at /storage directly via DATA_FOLDER.
# ---------------------------------------------------------------------------
export DATA_FOLDER="/storage"

# ---------------------------------------------------------------------------
# Map ONCE environment variables to Vaultwarden equivalents
# ---------------------------------------------------------------------------

# DISABLE_SSL — tell vaultwarden whether the external URL uses HTTPS
if [ "$DISABLE_SSL" = "true" ]; then
    export DOMAIN="${DOMAIN:-http://localhost}"
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

# Vaultwarden listens on 8080; nginx fronts it on port 80
export ROCKET_PORT="8080"
export ROCKET_ADDRESS="127.0.0.1"

# ---------------------------------------------------------------------------
# Launch nginx (port 80) then vaultwarden (port 8080)
# ---------------------------------------------------------------------------
nginx
exec /vaultwarden
