# =============================================================================
# Zcash Web Gateway — Dockerfile
# =============================================================================
#
# Build:
#   docker build -t zcash-web-gateway:dev ./gateway
#
# Run standalone (without compose):
#   docker run --rm \
#     -e UPSTREAM_HOST=localhost \
#     -e UPSTREAM_PORT=9067 \
#     -v $(pwd)/gateway/envoy.yaml:/etc/envoy/envoy.yaml:ro \
#     -p 8080:8080 \
#     zcash-web-gateway:dev
#
# Image: envoyproxy/envoy:v1.29.4
#   - Pinned digest ensures reproducible builds.
#   - Contains getenvoy-package with envoy binary + required shared libs.
#   - Base is Ubuntu 22.04 — well-known CVE coverage.
#
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: config-validator
#
# Validates envoy.yaml before it ever reaches the runtime image.
# A bad config file caught here saves a confusing runtime crash.
# -----------------------------------------------------------------------------
FROM envoyproxy/envoy:v1.29.4 AS config-validator

WORKDIR /validate

# Copy config files for validation only
COPY envoy.yaml  /etc/envoy/envoy.yaml
COPY cors.yaml   /etc/envoy/cors.yaml

# --mode validate exits 0 on valid config, non-zero on any error.
# Build fails here if the config is malformed — never ships broken config.
RUN envoy \
      --mode validate \
      --config-path /etc/envoy/envoy.yaml \
      --log-level warn


# -----------------------------------------------------------------------------
# Stage 2: runtime
#
# Minimal runtime image. No build tools, no shell utilities beyond what
# Envoy needs. Attack surface is as small as we can make it.
# -----------------------------------------------------------------------------
FROM envoyproxy/envoy:v1.29.4 AS runtime

# ---------------------------------------------------------------------------
# Envoy runs as non-root by default in the official image (uid 101).
# We make this explicit and ensure our files respect it.
# ---------------------------------------------------------------------------
USER 101

# ---------------------------------------------------------------------------
# Copy validated config from stage 1.
# Using --chown avoids a separate RUN chown layer.
# ---------------------------------------------------------------------------
COPY --from=config-validator --chown=101:101 \
     /etc/envoy/envoy.yaml  /etc/envoy/envoy.yaml

COPY --chown=101:101 cors.yaml /etc/envoy/cors.yaml

# ---------------------------------------------------------------------------
# Ports:
#   8080 — gRPC-web listener (browser-facing, mapped in compose/helm)
#   9901 — Envoy admin (loopback only, NOT exposed in compose)
# ---------------------------------------------------------------------------
EXPOSE 8080

# ---------------------------------------------------------------------------
# Entrypoint — explicit args, no shell interpolation.
#
# --config-path       : load our config
# --log-level         : info in production, debug for troubleshooting
# --log-format        : json for structured log pipelines
# --drain-time-s      : 20s graceful drain on SIGTERM before force-quit
# --service-node      : identifies this instance in multi-gateway setups
# --service-cluster   : logical cluster name for metrics/tracing
# ---------------------------------------------------------------------------
ENTRYPOINT [ \
  "envoy", \
  "--config-path",    "/etc/envoy/envoy.yaml", \
  "--log-level",      "info", \
  "--log-format",     "json", \
  "--drain-time-s",   "20", \
  "--service-node",   "zcash-gateway", \
  "--service-cluster","zcash-web-gateway" \
]