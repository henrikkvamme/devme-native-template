#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly workspace_key="$(printf '%s' "$root" | openssl dgst -sha256 -r | cut -c1-8)"
source "$root/tooling/devme-ports.sh"
readonly compose_file="$root/infrastructure/convex/compose.yaml"
readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="${CONVEX_PORT:-$(devme_convex_port "$slot")}"
readonly site_port="${CONVEX_SITE_PORT:-$(devme_convex_site_port "$slot")}"
readonly dashboard_port="${CONVEX_DASHBOARD_PORT:-$((convex_port + 2))}"
readonly postgres_port="${POSTGRES_PORT:-$((convex_port + 3))}"
readonly instance_secret_file="$root/.devme/convex-instance-secret-$slot"
readonly auth_secret_file="$root/.devme/better-auth-secret-$slot"

resolve_instance_secret() {
  local secret="${CONVEX_INSTANCE_SECRET:-}"
  if [[ -z "$secret" ]]; then
    mkdir -p "$root/.devme"
    if [[ ! -s "$instance_secret_file" ]]; then
      umask 077
      openssl rand -hex 32 >"$instance_secret_file"
    fi
    secret="$(tr -d '\r\n' <"$instance_secret_file")"
  fi
  if [[ ! "$secret" =~ ^[[:xdigit:]]{64}$ ]]; then
    printf 'CONVEX_INSTANCE_SECRET must contain exactly 64 hexadecimal characters.\n' >&2
    return 1
  fi
  printf '%s\n' "$secret"
}

export COMPOSE_PROJECT_NAME="starter-$workspace_key-$slot"
export CONVEX_PORT="$convex_port"
export CONVEX_SITE_PORT="$site_port"
export CONVEX_DASHBOARD_PORT="$dashboard_port"
export POSTGRES_PORT="$postgres_port"
export CONVEX_INSTANCE_NAME="starter-$workspace_key-$slot"
export CONVEX_DATABASE_NAME="starter_${workspace_key}_$slot"
export CONVEX_INSTANCE_SECRET="$(resolve_instance_secret)"

compose() {
  docker compose --file "$compose_file" "$@"
}

admin_key() {
  local key
  key="$(compose exec -T backend ./generate_admin_key.sh 2>/dev/null | tail -n 1)"
  if [[ -z "$key" ]]; then
    printf 'Could not generate a Convex admin key. Is the backend healthy?\n' >&2
    return 1
  fi
  printf '%s\n' "$key"
}

ensure_local_auth_env() {
  local admin_key="$1"
  local auth_secret
  if [[ ! -s "$auth_secret_file" ]]; then
    mkdir -p "$root/.devme"
    umask 077
    openssl rand -base64 32 >"$auth_secret_file"
  fi
  auth_secret="$(tr -d '\r\n' <"$auth_secret_file")"

  set_convex_env "$admin_key" BETTER_AUTH_SECRET "$auth_secret"
  set_convex_env "$admin_key" AUTH_ENABLE_TEST_PASSWORD true
  local environment
  environment="$(
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx convex env list
  )"
  if [[ "$environment" != *'JWKS='* ]]; then
    set_convex_env "$admin_key" JWKS '[]'
  fi
}

set_convex_env() {
  local admin_key="$1"
  local name="$2"
  local value="$3"
  local attempt

  cd "$root/backend"
  for attempt in 1 2 3 4 5; do
    if CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx convex env set "$name" "$value" >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done
  printf 'Could not set the local Convex environment variable %s.\n' "$name" >&2
  return 1
}

run_compose_service() {
  compose up --remove-orphans
}

case "${1:-}" in
  up)
    run_compose_service
    ;;
  down)
    compose down --remove-orphans
    ;;
  deploy)
    admin_key="$(admin_key)"
    ensure_local_auth_env "$admin_key"
    cd "$root/backend"
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      CONVEX_SITE_URL="http://127.0.0.1:$site_port" \
      bun run codegen
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      CONVEX_SITE_URL="http://127.0.0.1:$site_port" \
      bunx convex deploy --yes
    current_jwks="$(
      CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
        CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
        bunx convex env get JWKS
    )"
    if [[ "$current_jwks" == '[]' ]]; then
      jwks="$(
        CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
          CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
          bunx convex run auth:getLatestJwks
      )"
      set_convex_env "$admin_key" JWKS "$jwks"
      CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
        CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
        CONVEX_SITE_URL="http://127.0.0.1:$site_port" \
        bunx convex deploy --yes
    fi
    cd "$root"
    bun run format
    ;;
  function-spec)
    admin_key="$(admin_key)"
    cd "$root/backend"
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx convex function-spec | bun -e '
        const spec = await Bun.stdin.json();
        spec.url = "";
        spec.functions.sort((left, right) => {
          const leftKey = `${left.identifier ?? left.path}:${left.method ?? ""}`;
          const rightKey = `${right.identifier ?? right.path}:${right.method ?? ""}`;
          return leftKey.localeCompare(rightKey);
        });
        console.log(JSON.stringify(spec, null, 2));
      ' >"$root/contracts/function-spec.json"
    ;;
  function-spec-check)
    admin_key="$(admin_key)"
    temporary_spec="$(mktemp)"
    trap 'rm -f "$temporary_spec"' EXIT
    cd "$root/backend"
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx convex function-spec | bun -e '
        const spec = await Bun.stdin.json();
        spec.url = "";
        spec.functions.sort((left, right) => {
          const leftKey = `${left.identifier ?? left.path}:${left.method ?? ""}`;
          const rightKey = `${right.identifier ?? right.path}:${right.method ?? ""}`;
          return leftKey.localeCompare(rightKey);
        });
        console.log(JSON.stringify(spec, null, 2));
      ' >"$temporary_spec"
    if ! cmp -s "$root/contracts/function-spec.json" "$temporary_spec"; then
      diff -u "$root/contracts/function-spec.json" "$temporary_spec" || true
      printf 'Convex function spec changed. Run devme run contract-export and review it.\n' >&2
      exit 1
    fi
    ;;
  live-smoke)
    CONVEX_URL="http://127.0.0.1:$convex_port" \
      bun "$root/backend/test/live-smoke.ts"
    ;;
  auth-live-smoke)
    CONVEX_URL="http://127.0.0.1:$convex_port" \
      AUTH_SITE_URL="http://127.0.0.1:$site_port" \
      bun "$root/backend/test/auth-live-smoke.ts"
    ;;
  auth-configure)
    shift
    if [[ "$#" -gt 0 ]]; then
      printf 'error: "auth-configure does not accept arguments"\n'
      printf 'help[1]: "Edit .env.auth.local, then run the Devme task again."\n'
      exit 2
    fi
    admin_key="$(admin_key)"
    config_file="${AUTH_CONFIG_FILE:-$root/.env.auth.local}"
    temporary_env="$(mktemp "${TMPDIR:-/tmp}/starter-auth.XXXXXX")"
    trap 'rm -f "$temporary_env"' EXIT
    chmod 600 "$temporary_env"
    bun "$root/tooling/auth-config.ts" prepare --input "$config_file" --output "$temporary_env"
    cd "$root/backend"
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx convex env set --force --from-file "$temporary_env" >&2
    "$root/tooling/convex.sh" deploy >&2
    cd "$root"
    bun "$root/tooling/auth-config.ts" applied --input "$config_file"
    ;;
  auth-doctor)
    shift
    admin_key="$(admin_key)"
    cd "$root/backend"
    environment="$(
      CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
        CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
        bunx convex env list
    )"
    printf '%s\n' "$environment" | \
      CONVEX_URL="http://127.0.0.1:$convex_port" \
      AUTH_SITE_URL="http://127.0.0.1:$site_port" \
      bun "$root/tooling/auth-config.ts" doctor "$@"
    ;;
  auth-host)
    shift
    if [[ "$#" -ne 1 ]]; then
      printf 'error: "auth-host requires one HTTPS URL"\n'
      exit 2
    fi
    auth_host="$(AUTH_URL="$1" bun -e '
      const url = new URL(process.env.AUTH_URL);
      if (url.protocol !== "https:" || !url.hostname.endsWith(".ts.net")) process.exit(1);
      console.log(url.host);
    ')" || {
      printf 'error: "auth-host only accepts a Tailscale HTTPS URL"\n'
      exit 2
    }
    admin_key="$(admin_key)"
    set_convex_env "$admin_key" BETTER_AUTH_ALLOWED_HOSTS "$auth_host"
    ;;
  *)
    printf 'Usage: %s {up|down|deploy|function-spec|function-spec-check|live-smoke|auth-live-smoke|auth-configure|auth-doctor|auth-host}\n' "$0" >&2
    exit 64
    ;;
esac
