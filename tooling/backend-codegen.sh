#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly backend="$root/backend"
readonly overlay="$backend/auth-overlay"

verify_overlay() {
  local template="$1"
  local generated="$2"
  if ! cmp -s "$template" "$generated"; then
    printf 'Auth overlay drifted after formatting: %s\n' "$template" >&2
    printf 'Keep the reviewed template byte-identical to %s.\n' "$generated" >&2
    return 1
  fi
}

cd "$backend"
bunx confect codegen

cp "$overlay/auth.ts.template" "$backend/convex/betterAuth/auth.ts"
cp "$overlay/adapter.ts.template" "$backend/convex/betterAuth/adapter.ts"
cp "$overlay/root-auth.ts.template" "$backend/convex/auth.ts"
cp "$overlay/http.ts.template" "$backend/convex/http.ts"

bun run auth:schema
cd "$root"
bun run format

verify_overlay "$overlay/auth.ts.template" "$backend/convex/betterAuth/auth.ts"
verify_overlay "$overlay/adapter.ts.template" "$backend/convex/betterAuth/adapter.ts"
verify_overlay "$overlay/root-auth.ts.template" "$backend/convex/auth.ts"
verify_overlay "$overlay/http.ts.template" "$backend/convex/http.ts"
