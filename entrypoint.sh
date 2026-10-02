#!/bin/sh
set -e

# If DATABASE_URL is not set, construct it from POSTGRES_* environment variables:
#   POSTGRES_USER     database user (default: postgres)
#   POSTGRES_PASSWORD plain password, or a JSON object with a "password" field
#                     (e.g. an AWS Secrets Manager secret)
#   POSTGRES_HOST / POSTGRES_PORT / POSTGRES_DB
#   RO_POSTGRES_HOST  optional read-only replica host
#   POSTGRES_OPTIONS  extra connection query string (default: sslmode=require)
#   RELAY_EVENT_SCHEMA  schema for the `event` table; appended as search_path
#
# Schemas: this service uses two, and both should be explicit entries in the
# deployment configuration — do not hand-write search_path into
# POSTGRES_OPTIONS:
#
#   RELAY_EVENT_SCHEMA  the event table (this script turns it into the
#                       connection string's search_path)
#   GROUP_MGMT_SCHEMA   group-management and disappearing-message tables
#                       (read directly by relay and relayer)
#
# They are configured separately on purpose: the two are not necessarily the
# same. The event table belongs to the relay itself, while the
# group-management tables are shared with the API service (which owns
# dismsg_user_status; the relay only reads it), so GROUP_MGMT_SCHEMA points
# at that service's schema.
if [ -z "$DATABASE_URL" ]; then
    POSTGRES_USER=${POSTGRES_USER:-postgres}
    POSTGRES_OPTIONS=${POSTGRES_OPTIONS:-sslmode=require}

    # Turn RELAY_EVENT_SCHEMA into search_path. If search_path is already
    # hand-written, the hand-written value wins and we warn — silently
    # overriding on conflict makes it hard to tell where the tables went.
    if [ -n "$RELAY_EVENT_SCHEMA" ]; then
        case "$POSTGRES_OPTIONS" in
            *search_path=*)
                echo "warn: POSTGRES_OPTIONS already contains search_path; ignoring RELAY_EVENT_SCHEMA=$RELAY_EVENT_SCHEMA" >&2
                ;;
            *)
                POSTGRES_OPTIONS="${POSTGRES_OPTIONS}&search_path=${RELAY_EVENT_SCHEMA}"
                ;;
        esac
    fi
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
