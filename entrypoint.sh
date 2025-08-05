#!/bin/sh
set -e

# if DATABASE_URL is set, do nothing, otherwise construct it from environment variables
if [ -n "$DATABASE_URL" ]; then
    echo "DATABASE_URL is already set, skipping construction."
else
    POSTGRES_PW=$(echo "$POSTGRES_PASSWORD" | jq -r .password)
    export DATABASE_URL="postgres://mosavi_admin:${POSTGRES_PW}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=require&timezone=Asia/Tokyo&search_path=relay"
    export RO_DATABASE_URL="postgres://mosavi_admin:${POSTGRES_PW}@${RO_POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=require&timezone=Asia/Tokyo&search_path=relay"
fi

exec /go/bin/nostr-relay