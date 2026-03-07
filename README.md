# Zcash Web Gateway

A small containerized gateway intended to sit in front of Zcash-related services and expose a web-friendly interface (for example, via Envoy with a CORS policy).

## Repo layout

- `gateway/` — gateway runtime configuration (Envoy) and Docker build context.
- `proto/` — vendored protobuf definitions (ZIP-307).
- `docker-compose.yml` — base local/dev compose.
- `docker-compose.zaino.yml` — optional compose overlay for running alongside Zaino.

## Quick start

```sh
docker compose up --build
```

With the Zaino overlay:

```sh
docker compose -f docker-compose.yml -f docker-compose.zaino.yml up --build
```

## License

See `LICENSE`.

