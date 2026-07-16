#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly devme_bin="${DEVME_BIN:-$(command -v devme)}"
readonly sandbox="$(mktemp -d "${TMPDIR:-/tmp}/devme-native-recipe.XXXXXX")"
readonly project="$sandbox/project"

cleanup() {
  local status=$?
  local secret_file slot
  trap - EXIT
  if [[ -f "$project/devme.toml" ]]; then
    if [[ "$status" -ne 0 ]]; then
      (
        cd "$project"
        "$devme_bin" doctor --output json >&2 || true
      )
    fi
    "$devme_bin" down --all >/dev/null 2>&1 || true
    for secret_file in "$project"/.devme/convex-instance-secret-*; do
      [[ -e "$secret_file" ]] || continue
      slot="${secret_file##*-}"
      DEVME_SLOT="$slot" "$project/tooling/convex.sh" down >/dev/null 2>&1 || true
    done
  fi
  rm -rf "$sandbox"
  exit "$status"
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
