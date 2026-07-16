#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly workspace_key="$(printf '%s' "$root" | openssl dgst -sha256 -r | cut -c1-8)"
source "$root/tooling/devme-ports.sh"
readonly compose_file="$root/infrastructure/convex/compose.yaml"
readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="${CONVEX_PORT:-$(devme_convex_port "$slot")}"
readonly site_port="${CONVEX_SITE_PORT:-$((convex_port + 1))}"
readonly dashboard_port="${CONVEX_DASHBOARD_PORT:-$((convex_port + 2))}"
readonly postgres_port="${POSTGRES_PORT:-$((convex_port + 3))}"
readonly instance_secret_file="$root/.devme/convex-instance-secret-$slot"

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

run_compose_service() {
  local compose_pid
  compose up --remove-orphans &
  compose_pid=$!

  cleanup_compose_service() {
    trap - EXIT INT TERM
    kill "$compose_pid" 2>/dev/null || true
    wait "$compose_pid" 2>/dev/null || true
    compose down --remove-orphans --timeout 1
  }
  trap cleanup_compose_service EXIT INT TERM
  wait "$compose_pid"
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
    cd "$root/backend"
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx confect codegen
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx convex deploy --yes
    ;;
  function-spec)
    admin_key="$(admin_key)"
    cd "$root/backend"
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx convex function-spec >"$root/contracts/function-spec.json"
    ;;
  function-spec-check)
    admin_key="$(admin_key)"
    temporary_spec="$(mktemp)"
    trap 'rm -f "$temporary_spec"' EXIT
    cd "$root/backend"
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx convex function-spec >"$temporary_spec"
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
  *)
    printf 'Usage: %s {up|down|deploy|function-spec|function-spec-check|live-smoke}\n' "$0" >&2
    exit 64
    ;;
esac
