#!/bin/sh
# =============================================================================
# entrypoint.sh — substitute env vars into Envoy config then start Envoy
# =============================================================================

set -e

TEMPLATE=/etc/envoy/envoy.yaml.tmpl
RESOLVED=/tmp/envoy.yaml

# Required vars
if [ -z "${UPSTREAM_HOST}" ]; then
  echo "ERROR: UPSTREAM_HOST is not set" >&2
  exit 1
fi

if [ -z "${UPSTREAM_PORT}" ]; then
  echo "ERROR: UPSTREAM_PORT is not set" >&2
  exit 1
fi

# UPSTREAM_TLS — controls whether Envoy uses TLS to the upstream.
#
#   true  (default) — TLS with SNI. Required for public endpoints like
#                     mainnet.lightwalletd.com and zaino.zfnd.org.
#
#   false           — plaintext HTTP/2. Use when the upstream is a local
#                     container running with --no-tls-very-insecure
#                     (e.g. docker-compose.testnet.yml local stack).
#
UPSTREAM_TLS="${UPSTREAM_TLS:-true}"

if [ "${UPSTREAM_TLS}" = "true" ]; then
  UPSTREAM_TLS_BLOCK="      transport_socket:
        name: envoy.transport_sockets.tls
        typed_config:
          \"@type\": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
          sni: \"${UPSTREAM_HOST}\""
else
  # Plaintext to upstream — emit empty string.
  UPSTREAM_TLS_BLOCK=""
fi

export UPSTREAM_TLS_BLOCK

envsubst '${UPSTREAM_HOST} ${UPSTREAM_PORT} ${UPSTREAM_TLS_BLOCK}' \
  < "${TEMPLATE}" > "${RESOLVED}"

echo "Starting Envoy — upstream=${UPSTREAM_HOST}:${UPSTREAM_PORT} tls=${UPSTREAM_TLS}"

exec envoy \
  --config-path    "${RESOLVED}" \
  --log-level      info \
  --drain-time-s   20 \
  --service-node   zcash-gateway \
  --service-cluster zcash-web-gateway