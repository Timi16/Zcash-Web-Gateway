# =============================================================================
# Zcash Web Gateway — Dockerfile
# =============================================================================
#
# Build:
#   docker compose up --build
#
# Env vars required at runtime:
#   UPSTREAM_HOST  — lightwalletd or Zaino hostname
#   UPSTREAM_PORT  — 9067 (lightwalletd) or 8137 (Zaino)
#
# envoy.yaml.tmpl contains ${UPSTREAM_HOST} and ${UPSTREAM_PORT} placeholders.
# entrypoint.sh runs envsubst at container start, then exec's Envoy as PID 1.
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: config-validator
# Substitutes default values into the template and validates the result.
# Build fails here if envoy.yaml.tmpl is malformed — never ships broken config.
# -----------------------------------------------------------------------------
FROM envoyproxy/envoy:v1.29.4 AS config-validator

# Install envsubst (part of gettext-base)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends gettext-base && \
    rm -rf /var/lib/apt/lists/*

COPY envoy.yaml.tmpl /etc/envoy/envoy.yaml.tmpl
# cors.yaml is a reference document only — Envoy static config has no include
# mechanism so it is not copied into the image. See gateway/cors.yaml for notes.

# Substitute default values for validation only
RUN UPSTREAM_HOST=localhost UPSTREAM_PORT=9067 \
    envsubst '${UPSTREAM_HOST} ${UPSTREAM_PORT}' \
    < /etc/envoy/envoy.yaml.tmpl \
    > /tmp/envoy-validated.yaml

# Validate the substituted config — exits non-zero on any error
RUN envoy \
      --mode validate \
      --config-path /tmp/envoy-validated.yaml \
      --log-level warn


# -----------------------------------------------------------------------------
# Stage 2: runtime
# Minimal image — only what Envoy and entrypoint.sh need.
# -----------------------------------------------------------------------------
FROM envoyproxy/envoy:v1.29.4 AS runtime

# Install envsubst for the entrypoint script
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends gettext-base && \
    rm -rf /var/lib/apt/lists/*

# Non-root user (uid 101 is the envoy user in the official image)
USER 101

# Copy validated template and supporting files
COPY --from=config-validator --chown=101:101 \
     /etc/envoy/envoy.yaml.tmpl /etc/envoy/envoy.yaml.tmpl

COPY --chown=101:101 entrypoint.sh  /entrypoint.sh

# Ports:
#   8080 — gRPC-web listener (browser-facing)
#   9901 — Envoy admin (loopback only, not exposed in compose)
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]