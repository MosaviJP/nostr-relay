# nostr-relay

A [Nostr](https://nostr.com/) relay built on the [relayer](https://github.com/MosaviJP/relayer) framework with an [eventstore](https://github.com/MosaviJP/eventstore) storage backend. PostgreSQL is the primary supported backend; SQLite, MySQL, and OpenSearch backends are also available.

Forked from [mattn/nostr-relay](https://github.com/mattn/nostr-relay).

## Quick start (Docker Compose)

```
$ docker compose up --build
```

This starts a PostgreSQL container and the relay on port 7447. Verify it is running:

```
$ curl -H 'Accept: application/nostr+json' http://localhost:7447
```

Data is persisted in the `db-data` volume. `docker compose down -v` removes it.

## Configuration

The relay is configured through environment variables (or the corresponding command-line flags):

| Variable | Default | Description |
|---|---|---|
| `DRIVER` | `postgresql` | Storage backend: `postgresql`, `sqlite3`, `mysql`, `opensearch` |
| `DATABASE_URL` | `nostr-relay.sqlite` | Connection string for the selected backend |
| `RO_DATABASE_URL` | (empty) | Optional read-only replica connection string (postgresql) |
| `SERVICE_URL` | (empty) | Public URL of the relay |

If `DATABASE_URL` is not set, the container entrypoint constructs one from `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` (plain text, or a JSON object with a `password` field such as an AWS Secrets Manager secret), and optional `RO_POSTGRES_HOST` / `POSTGRES_OPTIONS`.

## Build from source

```
$ go build -o nostr-relay .
$ DRIVER=sqlite3 DATABASE_URL=nostr-relay.sqlite ./nostr-relay
```

## License

MIT

## Author

Yasuhiro Matsumoto (a.k.a. mattn)
