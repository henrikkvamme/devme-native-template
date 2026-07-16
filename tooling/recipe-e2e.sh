#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly devme_bin="${DEVME_BIN:-$(command -v devme)}"
readonly sandbox="$(mktemp -d "${TMPDIR:-/tmp}/devme-native-recipe.XXXXXX")"
readonly project="$sandbox/project"

cleanup() {
  if [[ -f "$project/devme.toml" ]]; then
    "$devme_bin" down --all >/dev/null 2>&1 || true
  fi
  rm -rf "$sandbox"
}
trap cleanup EXIT

mkdir -p "$sandbox/bin"
cat > "$sandbox/bin/stripe" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *" --print-secret "* ]]; then
  printf 'whsec_recipe_e2e\n'
  exit 0
fi
sleep 300
SH
chmod +x "$sandbox/bin/stripe"
export PATH="$sandbox/bin:$PATH"

"$devme_bin" create native "$project" \
  --source "$root" \
  --no-input \
  --output toon

test ! -e "$project/backend/convex/betterAuth"
mkdir -p \
  "$project/.devme/android-sdk/platforms/android-37.0" \
  "$project/.devme/android-sdk/platform-tools"
cat >"$project/.devme/android-sdk/platform-tools/adb" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$project/.devme/android-sdk/platform-tools/adb"

(
  cd "$project"
  "$devme_bin" feature add auth --no-input --output toon
  test -f backend/convex/betterAuth/auth.ts
  ! grep -q '@better-auth/stripe' backend/package.json
  "$devme_bin" run backend::test --output toon

  cat > .env.auth.local <<'ENV'
AUTH_APP_NAME=RecipeE2E
STRIPE_SECRET_KEY=sk_test_recipe_e2e
STRIPE_PRICE_ID=price_recipe_e2e
ENV
  "$devme_bin" feature add stripe --no-input --output toon
  grep -q '@better-auth/stripe' backend/package.json
  "$devme_bin" run backend::test --output toon

  "$devme_bin" feature remove stripe --no-input --output toon
  ! grep -q '@better-auth/stripe' backend/package.json
  test -f backend/convex/betterAuth/auth.ts

  "$devme_bin" feature remove auth --no-input --output toon
  test ! -e backend/convex/betterAuth
)

printf 'Native recipe composition passed: base -> auth -> stripe -> auth -> base.\n'
