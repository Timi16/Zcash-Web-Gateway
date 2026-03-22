# Zcash Web Gateway

> A production-ready gRPC-web proxy stack that bridges browser-based Zcash wallets to lightwalletd and Zaino — open-source, self-hostable, and operator-ready in under 20 minutes.

---

## Why This Exists

Browsers cannot speak native gRPC. lightwalletd and Zaino require it. That gap means every browser-based Zcash wallet needs a translation layer — a gRPC-web proxy — to function at all.

The [WebZjs documentation](https://github.com/ChainSafe/WebZjs) is explicit:

> "To work in the web these need to be a special gRPC-web proxy to a regular lightwalletd instance. Using an unproxied URL will NOT work."

Before this project, teams either depended on ChainSafe's hosted endpoints (a single point of failure) or built fragile one-off setups with inconsistent security and no monitoring. Zcash Web Gateway solves this with a standardised, hardened, and fully documented stack that any operator can run.

---

## What's in the Stack

```
Browser (WebZjs)
    │  gRPC-web / HTTP 1.1
    ▼
Envoy Proxy  ←── this repo
    │  native gRPC / HTTP 2
    ▼
lightwalletd  or  Zaino
    │  JSON-RPC
    ▼
zebrad (Zcash full node)
```

| Component | Role |
|---|---|
| **Envoy** | gRPC-web ↔ gRPC translation, TLS termination, CORS, rate limiting, health checks |
| **lightwalletd** | ZIP-307 gRPC server, connects to zebrad |
| **zebrad** | Zcash full node (regtest / mainnet) |
| **WebZjs demo** | Browser smoke test — confirms the full path works end to end |

---

## Quick Start — Local Regtest (5 minutes)

**Prerequisites:** Docker, Docker Compose

```bash
git clone https://github.com/ZeroIQ/zcash-web-gateway.git
cd zcash-web-gateway
cp .env.example .env
docker compose up
```

When all services are healthy:

```bash
curl http://localhost:8080/healthz
# → 200 OK
```

Gateway is live at `http://localhost:8080`. Point any WebZjs instance at it.

---

## Quick Start — Mainnet (public lightwalletd upstream)

```bash
docker compose up gateway-mainnet
```

Default upstream: `mainnet.lightwalletd.com:9067` (TLS enabled). Override via `.env`:

```env
UPSTREAM_MAINNET_HOST=mainnet.lightwalletd.com
UPSTREAM_MAINNET_PORT=9067
```

---

## Quick Start — Zaino Upstream

```bash
docker compose -f docker-compose.yml -f docker-compose.zaino.yml up
```

Default upstream: `zaino.zfnd.org:8137`. Override `UPSTREAM_HOST` and `UPSTREAM_PORT` in `.env`.

---

## Configuration

All runtime config is driven by environment variables. Copy `.env.example` to `.env` and adjust.

| Variable | Default | Description |
|---|---|---|
| `UPSTREAM_HOST` | `lightwalletd` (internal) | Upstream hostname |
| `UPSTREAM_PORT` | `9067` | Upstream port |
| `UPSTREAM_TLS` | `true` for mainnet, `false` for regtest | Enable TLS to upstream |
| `GATEWAY_REGTEST_PORT` | `8080` | Host port for regtest gateway |
| `GATEWAY_MAINNET_PORT` | `8081` | Host port for mainnet gateway |

---

## Security Defaults

These are on by default. You don't have to configure them.

- **Zero IP logging** — `%DOWNSTREAM_REMOTE_ADDRESS%` is deliberately absent from the access log format. Client IPs are never written to disk.
- **Rate limiting** — configured at the Envoy filter layer to protect against abuse.
- **CORS** — allows gRPC-web required headers (`x-grpc-web`, `grpc-timeout`, `content-type`) with correct `expose_headers` for trailers.
- **Circuit breakers** — `max_connections: 1000`, `max_requests: 5000`, `max_retries: 3`.
- **TCP keepalive** — probes every 10s, 3 probes before disconnect, 30s idle threshold.
- **TLS to upstream** — SNI-aware, uses system CA bundle. Disabled only for local regtest plaintext.

The Envoy admin interface binds to `127.0.0.1:9901` only — never exposed publicly.

---

## Route Timeouts (ZIP-307 aligned)

| Method | Timeout | Reason |
|---|---|---|
| `GetLatestBlock`, `GetBlock`, `GetTreeState`, `GetLatestTreeState` | 10s | Fast unary reads |
| `GetTransaction`, `GetAddressUtxos` | 15s | Medium unary |
| `SendTransaction` | 30s | Broadcast propagation time |
| `GetTaddressTxids`, `GetAddressUtxosStream`, `GetSubtreeRoots` | 30s | Bounded streaming |
| `GetBlockRange`, `GetMempoolTx`, `GetMempoolStream` | 0s (no timeout) | Long-lived sync streams |
| All others | 20s | Catch-all |

---

## WebZjs Demo

A minimal browser app that exercises the full stack — useful for smoke testing any gateway endpoint.

```bash
cd demo-webzjs
npm install
npm run dev
```

Open `http://localhost:5173`. Point the Gateway URL at your running instance and click **Get Latest Block**. A block height response confirms the entire chain — browser → Envoy → lightwalletd → zebrad — is working.

> **Note:** Building WebZjs from source requires Rust nightly, `wasm-pack`, and `just`. Run `bootstrap-webzjs.sh` once before `npm run dev`. Pre-built packages are used by default.

---

## Repository Layout

```
zcash-web-gateway/
├── gateway/
│   ├── Dockerfile          # Two-stage build: validates config before shipping it
│   ├── entrypoint.sh       # envsubst + Envoy startup
│   └── envoy.yaml.tmpl     # Envoy config template (upstream injected at runtime)
├── config/
│   ├── zebrad.toml         # zebrad regtest config
│   └── zcash.conf          # lightwalletd connection config
├── proto/
│   └── service.proto       # ZIP-307 CompactTxStreamer (vendored, do not edit)
├── demo-webzjs/            # Browser smoke test app (TypeScript + Vite)
├── docker-compose.yml      # Regtest stack (zebrad + lightwalletd + gateway)
├── docker-compose.zaino.yml # Zaino upstream override
├── .env.example
└── README.md
```

---

## Upstream Compatibility

| Upstream | Port | TLS | Status |
|---|---|---|---|
| lightwalletd (ECC) | 9067 | Yes (mainnet), No (regtest) | Fully tested |
| Zaino (Zcash Foundation) | 8137 | Yes | Tested against `zaino.zfnd.org` |

---

## ZIP Compliance

- **ZIP-307** — All CompactTxStreamer RPC methods are routed with purpose-tuned timeouts
- **ZIP-316** — Unified Address payloads pass through Envoy without truncation (buffer limits validated)
- **ZIP-317** — `RawTransaction.data` is never modified in transit (Envoy passes bytes through unmodified)

---

## Health Check

```bash
# Gateway health
curl http://localhost:8080/healthz

# lightwalletd direct (bypass gateway)
grpcurl -plaintext localhost:9067 cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLightdInfo
```

---

## Contributing

Issues, PRs, and operator registrations are welcome. If you run a public gateway endpoint, open a PR to add it to the registry.

<!-- For bugs in Zaino or lightwalletd integration, see the upstream issue trackers:
- [zingolabs/zaino](https://github.com/zingolabs/zaino)
- [zcash/lightwalletd](https://github.com/zcash/lightwalletd) -->

---

## License

MIT — see [LICENSE](./LICENSE).

---

## Acknowledgements

Built with support from a Zcash Community . Depends on [Zebra](https://github.com/ZcashFoundation/zebra) and [lightwalletd](https://github.com/zcash/lightwalletd).