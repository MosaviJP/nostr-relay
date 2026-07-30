#!/bin/sh
set -e

# If DATABASE_URL is not set, construct it from POSTGRES_* environment variables:
#   POSTGRES_USER     database user (default: postgres)
#   POSTGRES_PASSWORD plain password, or a JSON object with a "password" field
#                     (e.g. an AWS Secrets Manager secret)
#   POSTGRES_HOST / POSTGRES_PORT / POSTGRES_DB
#   RO_POSTGRES_HOST  optional read-only replica host
#   POSTGRES_OPTIONS  extra connection query string (default: sslmode=require)
if [ -z "$DATABASE_URL" ]; then
    POSTGRES_USER=${POSTGRES_USER:-postgres}
    POSTGRES_OPTIONS=${POSTGRES_OPTIONS:-sslmode=require}
    POSTGRES_PW=$(echo "$POSTGRES_PASSWORD" | jq -r '.password' 2>/dev/null) || POSTGRES_PW="$POSTGRES_PASSWORD"
    if [ -z "$POSTGRES_PW" ] || [ "$POSTGRES_PW" = "null" ]; then
        POSTGRES_PW="$POSTGRES_PASSWORD"
    fi
    export DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PW}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?${POSTGRES_OPTIONS}"
    if [ -n "$RO_POSTGRES_HOST" ]; then
        export RO_DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PW}@${RO_POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?${POSTGRES_OPTIONS}"
    fi
else
    echo "DATABASE_URL is already set, skipping construction."
fi

exec /go/bin/nostr-relay
