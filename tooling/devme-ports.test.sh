#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

actual="$({
  readonly slot=2
  source "$root/tooling/devme-ports.sh"
  devme_convex_port "$slot"
})"

if [[ "$actual" != "3250" ]]; then
  printf 'expected Convex port 3250, got %s\n' "$actual" >&2
  exit 1
fi

actual="$({
  readonly slot=2
  source "$root/tooling/devme-ports.sh"
  devme_tailscale_https_port "$slot"
})"

if [[ "$actual" != "8483" ]]; then
  printf 'expected Tailscale HTTPS port 8483, got %s\n' "$actual" >&2
  exit 1
fi
