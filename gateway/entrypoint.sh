#!/bin/sh
# =============================================================================
# entrypoint.sh — substitute env vars into Envoy config then start Envoy
# =============================================================================

set -e

TEMPLATE=/etc/envoy/envoy.yaml.tmpl
RESOLVED=/tmp/envoy.yaml

if [ -z "${UPSTREAM_HOST}" ]; then
  echo "ERROR: UPSTREAM_HOST is not set" >&2
  exit 1
fi

if [ -z "${UPSTREAM_PORT}" ]; then
  echo "ERROR: UPSTREAM_PORT is not set" >&2
  exit 1
fi

envsubst '${UPSTREAM_HOST} ${UPSTREAM_PORT}' < "${TEMPLATE}" > "${RESOLVED}"

echo "Starting Envoy with upstream ${UPSTREAM_HOST}:${UPSTREAM_PORT}"

exec envoy \
  --config-path    "${RESOLVED}" \
  --log-level      info \
  --drain-time-s   20 \
  --service-node   zcash-gateway \
  --service-cluster zcash-web-gateway