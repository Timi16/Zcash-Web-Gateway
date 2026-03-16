# Zcash Web Gateway

Local/dev gateway that exposes a browser-friendly gRPC-web interface in front
of Zcash services. This repo intentionally avoids production hosting concerns.

## Repo layout

- `gateway/` — Envoy config and Docker build context.
- `proto/` — ZIP-307 protobuf definitions.
- `docker-compose.yml` — local regtest stack (zebrad + lightwalletd + gateway).
- `docker-compose.zaino.yml` — optional overlay to point the gateway at a public Zaino endpoint.

## Quick start (regtest + mainnet gateways)

Create an `.env` from the example (optional but recommended):

```sh
cp .env.example .env
```

```sh
docker compose up --build
```

Health check:

```sh
curl http://localhost:8080/healthz
```

Mainnet gateway (runs in parallel on a different port by default):

```sh
curl http://localhost:8081/healthz
```

## Optional: Zaino upstream (external)

```sh
docker compose -f docker-compose.yml -f docker-compose.zaino.yml up --build
```

This swaps the **mainnet** gateway upstream to Zaino while keeping the local
regtest stack running.

## WebZjs demo (Vite)

This demo connects to the **mainnet** gateway (`http://localhost:8081`) using
WebZjs in the browser.

Bootstrap WebZjs from source (required because the package is not on npm):

```sh
cd demo-webzjs
./bootstrap-webzjs.sh
```

```sh
cd demo-webzjs
npm run dev
```

Open the URL shown by Vite (usually `http://localhost:5173`), then click:
1. `Initialize Wallet`
2. `Get Latest Block`

Note: the demo enables `Cross-Origin-Opener-Policy` and
`Cross-Origin-Embedder-Policy` headers so WebZjs can initialize its WASM thread
pool in the browser.

## Milestone self-test (local)

1. Start the stack: `docker compose up --build`
2. Confirm regtest gateway health: `curl http://localhost:8080/healthz`
3. Confirm mainnet gateway health: `curl http://localhost:8081/healthz`
4. Confirm gRPC-web endpoints are listening:
   - regtest gateway: `http://localhost:8080`
   - mainnet gateway: `http://localhost:8081`
   - direct lightwalletd (bypass regtest): `http://127.0.0.1:9067`

Regtest requires manual block generation to advance height. Once blocks exist,
browser clients can query `GetLatestBlock` through the gateway.

## License

See `LICENSE`.
