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
# 关于 schema：本服务用到两个，都应当是部署配置里的显式条目，不要把
# search_path 手写进 POSTGRES_OPTIONS ——
#
#   RELAY_EVENT_SCHEMA  event 表（本脚本转成连接串的 search_path）
#   GROUP_MGMT_SCHEMA   群管理与消失消息相关表（由 relay 与 relayer 直接读取）
#
# 分开配置是有意的：两者未必相同。event 是 relay 自有的表，而群管理表与
# Moss-api 共用（dismsg_user_status 由 Moss-api 建、relay 只读），
# 所以 GROUP_MGMT_SCHEMA 要指向 Moss-api 的 schema。
if [ -z "$DATABASE_URL" ]; then
    POSTGRES_USER=${POSTGRES_USER:-postgres}
    POSTGRES_OPTIONS=${POSTGRES_OPTIONS:-sslmode=require}

    # RELAY_EVENT_SCHEMA 转成 search_path。已经手写了 search_path 的场合
    # 以手写的为准并告警 —— 两者冲突时静默覆盖会让人查不出表去了哪。
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
