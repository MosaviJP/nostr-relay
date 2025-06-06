#!/bin/sh
set -e

POSTGRES_PW=$(echo "$POSTGRES_PASSWORD" | jq -r .password)
export DATABASE_URL="postgres://mosavi_admin:${POSTGRES_PW}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=require&timezone=Asia/Tokyo&search_path=relay"
exec /go/bin/nostr-relay