#!/usr/bin/env bash

# Keep these values aligned with service.convex in devme.toml until Devme task
# templates can inject a service's resolved port directly.
readonly DEVME_CONVEX_BASE_PORT=3210
readonly DEVME_SLOT_PORT_OFFSET=20
readonly DEVME_TAILSCALE_HTTPS_BASE_PORT=8443
readonly DEVME_AUTH_PORT_OFFSET=1

devme_convex_port() {
  local slot_index="${1:-0}"
  printf '%s\n' "$((DEVME_CONVEX_BASE_PORT + slot_index * DEVME_SLOT_PORT_OFFSET))"
}

devme_convex_site_port() {
  local slot_index="${1:-0}"
  printf '%s\n' "$((DEVME_CONVEX_BASE_PORT + slot_index * DEVME_SLOT_PORT_OFFSET + DEVME_AUTH_PORT_OFFSET))"
}

devme_tailscale_https_port() {
  local slot_index="${1:-0}"
  printf '%s\n' "$((DEVME_TAILSCALE_HTTPS_BASE_PORT + slot_index * DEVME_SLOT_PORT_OFFSET))"
}

devme_tailscale_auth_https_port() {
  local slot_index="${1:-0}"
  printf '%s\n' "$((DEVME_TAILSCALE_HTTPS_BASE_PORT + slot_index * DEVME_SLOT_PORT_OFFSET + DEVME_AUTH_PORT_OFFSET))"
}
