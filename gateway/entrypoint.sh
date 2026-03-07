#!/bin/sh
# =============================================================================
# entrypoint.sh — substitute env vars into Envoy config then start Envoy
# =============================================================================
# Envoy does not natively expand shell-style ${VAR} in YAML config.
# envsubst processes the template first, writing a resolved config,
# then exec replaces this shell process with Envoy (PID 1).
#
# Required env vars:
#   UPSTREAM_HOST  — hostname of lightwalletd or Zaino upstream
#   UPSTREAM_PORT  — port of the upstream (9067 lightwalletd / 8137 Zaino)
# =============================================================================

set -e

TEMPLATE=/etc/envoy/envoy.yaml.tmpl
RESOLVED=/tmp/envoy.yaml

# Validate required vars are set and non-empty
if [ -z "${UPSTREAM_HOST}" ]; then
  echo "ERROR: UPSTREAM_HOST is not set" >&2
  exit 1
fi

if [ -z "${UPSTREAM_PORT}" ]; then
  echo "ERROR: UPSTREAM_PORT is not set" >&2
  exit 1
fi

# Substitute only our two variables — leave any other ${...} in the config untouched
envsubst '${UPSTREAM_HOST} ${UPSTREAM_PORT}' < "${TEMPLATE}" > "${RESOLVED}"

echo "Starting Envoy with upstream ${UPSTREAM_HOST}:${UPSTREAM_PORT}"

# exec replaces the shell process — Envoy becomes PID 1
# This ensures SIGTERM from Docker reaches Envoy directly for graceful drain
exec envoy \
  --config-path    "${RESOLVED}" \
  --log-level      info \
  --log-format     json \
  --drain-time-s   20 \
  --service-node   zcash-gateway \
  --service-cluster zcash-web-gateway