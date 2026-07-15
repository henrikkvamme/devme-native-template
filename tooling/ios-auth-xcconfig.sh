#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly input="${AUTH_CONFIG_FILE:-$root/.env.auth.local}"
readonly output="${IOS_AUTH_XCCONFIG:-$root/.devme/Auth.local.xcconfig}"

if [[ ! -f "$input" ]]; then
  printf 'error: "Native iOS auth is not configured."\n'
  printf 'help[1]: "Copy .env.auth.example to .env.auth.local and configure the Google web and iOS OAuth clients."\n'
  exit 1
fi

mkdir -p "$root/.devme"
bun "$root/tooling/auth-config.ts" ios-xcconfig --input "$input" --output "$output"
printf '%s\n' "$output"
