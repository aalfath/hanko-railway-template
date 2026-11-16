#!/bin/sh
# Writes Hanko's config.yaml from Railway variables, runs the database
# migrations, then starts the Hanko API (public on 127.0.0.1:8000 behind Caddy,
# admin on :8001 for the private network only) and Caddy on $PORT.
set -eu

: "${DATABASE_URL:?DATABASE_URL is not set (expected \${{Postgres.DATABASE_URL}})}"
: "${SECRET_KEY:?SECRET_KEY is not set (expected \${{secret(32)}})}"
if [ "${#SECRET_KEY}" -lt 16 ]; then
  echo "SECRET_KEY must be at least 16 characters" >&2; exit 1
fi

PORT="${PORT:-8080}"
SERVICE_NAME="${SERVICE_NAME:-Hanko}"
if [ -z "${APP_URL:-}" ]; then
  if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"; else APP_URL="http://localhost:${PORT}"; fi
fi
APP_URL="${APP_URL%/}"
# Host part of APP_URL (no scheme, port or path) is the default passkey relying party ID.
APP_HOST="$(printf '%s' "$APP_URL" | sed -E 's#^[A-Za-z]+://##; s#[/:?].*$##')"
RP_ID="${RP_ID:-$APP_HOST}"

# Origins allowed to call the API (CORS) and to use passkeys: APP_URL, this
# service's own domain (the demo page) and any extra ALLOWED_ORIGINS.
ORIGINS="$APP_URL"
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then ORIGINS="$ORIGINS,https://${RAILWAY_PUBLIC_DOMAIN}"; fi
if [ -n "${ALLOWED_ORIGINS:-}" ]; then ORIGINS="$ORIGINS,${ALLOWED_ORIGINS}"; fi

q() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
list() {
  printf '%s' "$1" | tr ',' '\n' | sed 's/^ *//; s/ *$//; s#/*$##' | awk 'NF && !seen[$0]++' | while read -r o; do
    printf '      - %s\n' "$(q "$o")"
  done
}

CFG=/tmp/hanko-config.yaml
umask 077
{
  cat <<YAML
database:
  url: $(q "$DATABASE_URL")
secret_keys:
  - $(q "$SECRET_KEY")
server:
  public:
    address: "127.0.0.1:8000"
  admin:
    address: ":8001"
  management:
    address: "127.0.0.1:8002"
  ip:
    extractor: x_forwarded_for
    trusted_proxies:
      - "127.0.0.0/8"
      - "10.0.0.0/8"
      - "172.16.0.0/12"
      - "192.168.0.0/16"
      - "100.64.0.0/10"
      - "::1/128"
      - "fc00::/7"
service:
  name: $(q "$SERVICE_NAME")
webauthn:
  relying_party:
    id: $(q "$RP_ID")
    display_name: $(q "$SERVICE_NAME")
    origins:
$(list "$ORIGINS")
cors:
  allow_origins:
$(list "$ORIGINS")
session:
  enable_auth_token_header: true
YAML
  if [ -n "${SMTP_HOST:-}" ]; then
    cat <<YAML
email_delivery:
  enabled: true
  from_address: $(q "${SMTP_FROM:-noreply@${APP_HOST}}")
  from_name: $(q "$SERVICE_NAME")
  smtp:
    host: $(q "$SMTP_HOST")
    port: $(q "${SMTP_PORT:-587}")
    user: $(q "${SMTP_USER:-}")
    password: $(q "${SMTP_PASSWORD:-}")
YAML
  else
    # No SMTP server: Hanko can't send passcodes, so sign-up and login use
    # email + password and passkeys, without email verification.
    cat <<YAML
email_delivery:
  enabled: false
email:
  require_verification: false
  use_for_authentication: false
password:
  enabled: true
  recovery: false
YAML
  fi
} > "$CFG"

echo "Hanko: app URL $APP_URL, passkey RP ID $RP_ID, email delivery $([ -n "${SMTP_HOST:-}" ] && echo on || echo off)"

echo "Hanko: running database migrations"
i=0
until /hanko --config "$CFG" migrate up; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then echo "Hanko: migrations failed" >&2; exit 1; fi
  echo "Hanko: database not ready, retrying in 3 s ($i/30)"
  sleep 3
done

/hanko serve --config "$CFG" all &
HANKO_PID=$!
caddy run --config /app/Caddyfile --adapter caddyfile &
CADDY_PID=$!

trap 'kill -TERM $HANKO_PID $CADDY_PID 2>/dev/null; wait; exit 0' TERM INT
# Exit (and let Railway restart the container) if either process stops.
while kill -0 "$HANKO_PID" 2>/dev/null && kill -0 "$CADDY_PID" 2>/dev/null; do
  sleep 5
done
echo "Hanko: a process stopped, exiting" >&2
kill -TERM "$HANKO_PID" "$CADDY_PID" 2>/dev/null || true
exit 1
