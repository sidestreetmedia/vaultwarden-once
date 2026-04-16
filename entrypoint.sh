#!/bin/sh
set -e

export DATA_FOLDER="/storage"

if [ "$DISABLE_SSL" = "true" ]; then
    export DOMAIN="${DOMAIN:-http://localhost}"
else
    export DOMAIN="${DOMAIN:-https://localhost}"
fi

if [ -n "$SMTP_ADDRESS" ]; then
    export SMTP_HOST="${SMTP_HOST:-$SMTP_ADDRESS}"
    export SMTP_FROM="${SMTP_FROM:-${MAILER_FROM_ADDRESS:-vaultwarden@example.com}}"
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

export ROCKET_PORT="8080"
export ROCKET_ADDRESS="127.0.0.1"

nginx
exec /vaultwarden