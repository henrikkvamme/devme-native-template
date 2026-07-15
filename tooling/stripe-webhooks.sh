#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"

readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="${CONVEX_PORT:-$(devme_convex_port "$slot")}"
readonly site_port="${CONVEX_SITE_PORT:-$(devme_convex_site_port "$slot")}"
readonly config_file="${AUTH_CONFIG_FILE:-$root/.env.auth.local}"
readonly backend_container="starter-$slot-backend-1"
readonly webhook_events="checkout.session.completed,customer.subscription.created,customer.subscription.updated,customer.subscription.deleted"
readonly mode="${1:-listen}"

if [[ "$mode" != "listen" && "$mode" != "doctor" ]]; then
  printf 'Usage: %s [listen|doctor]\n' "$0" >&2
  exit 64
fi

if [[ ! -f "$config_file" ]]; then
  printf 'Stripe webhook forwarding requires %s.\n' "$config_file" >&2
  printf 'Copy .env.auth.example, add STRIPE_SECRET_KEY and STRIPE_PRICE_ID, then run backend::auth-configure.\n' >&2
  exit 1
fi

temporary_env="$(mktemp "${TMPDIR:-/tmp}/starter-stripe.XXXXXX")"
trap 'rm -f "$temporary_env"' EXIT
chmod 600 "$temporary_env"

cd "$root"
bun "$root/tooling/auth-config.ts" prepare --input "$config_file" --output "$temporary_env"
stripe_secret_key="$(
  source "$temporary_env"
  printf '%s' "${STRIPE_SECRET_KEY:-}"
)"
rm -f "$temporary_env"

if [[ -z "$stripe_secret_key" ]]; then
  printf 'STRIPE_SECRET_KEY is required for local webhook forwarding.\n' >&2
  exit 1
fi

webhook_secret="$(STRIPE_API_KEY="$stripe_secret_key" stripe listen --skip-update --print-secret 2>/dev/null)"
if [[ ! "$webhook_secret" =~ ^whsec_[A-Za-z0-9_]+$ ]]; then
  printf 'Stripe CLI did not return a valid webhook signing secret.\n' >&2
  exit 1
fi

admin_key="$(docker exec "$backend_container" ./generate_admin_key.sh 2>/dev/null | tail -n 1)"
if [[ -z "$admin_key" ]]; then
  printf 'Could not generate a Convex admin key for %s.\n' "$backend_container" >&2
  exit 1
fi

cd "$root/backend"
if ! CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
  CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
  bunx convex env set STRIPE_WEBHOOK_SECRET "$webhook_secret" >/dev/null 2>&1; then
  printf 'Could not configure the local Stripe webhook signing secret.\n' >&2
  exit 1
fi

if [[ "$mode" == "doctor" ]]; then
  subscription_json="$(STRIPE_API_KEY="$stripe_secret_key" stripe subscriptions list --status active --limit 1)"
  reference_id="$(jq -r '.data[0].metadata.referenceId // empty' <<<"$subscription_json")"
  stripe_subscription_id="$(jq -r '.data[0].id // empty' <<<"$subscription_json")"
  if [[ -z "$reference_id" || -z "$stripe_subscription_id" ]]; then
    printf 'billing:\n'
    printf '  stripe: no-active-subscription\n'
    printf '  better_auth: unknown\n'
    printf '  synchronized: false\n'
    printf 'help[1]: "Complete one sandbox checkout, then retry."\n'
    exit 1
  fi

  arguments="$(jq -cn --arg referenceId "$reference_id" '{referenceId: $referenceId}')"
  diagnostic_errors="$(mktemp "${TMPDIR:-/tmp}/starter-billing-doctor.XXXXXX")"
  if ! stored="$(
    CONVEX_SELF_HOSTED_URL="http://127.0.0.1:$convex_port" \
      CONVEX_SELF_HOSTED_ADMIN_KEY="$admin_key" \
      bunx convex run auth:subscriptionForDiagnostics "$arguments" 2>"$diagnostic_errors"
  )"; then
    cat "$diagnostic_errors" >&2
    rm -f "$diagnostic_errors"
    exit 1
  fi
  rm -f "$diagnostic_errors"
  stored_status="$(jq -r '.status // "missing"' <<<"$stored")"
  stored_subscription_id="$(jq -r '.stripeSubscriptionId // empty' <<<"$stored")"
  synchronized=false
  if [[ "$stored_status" == "active" && "$stored_subscription_id" == "$stripe_subscription_id" ]]; then
    synchronized=true
  fi

  printf 'billing:\n'
  printf '  stripe: active\n'
  printf '  better_auth: %s\n' "$stored_status"
  printf '  synchronized: %s\n' "$synchronized"
  [[ "$synchronized" == "true" ]]
  exit
fi

printf 'Stripe webhook forwarding is ready for local Convex.\n'
STRIPE_API_KEY="$stripe_secret_key" stripe listen \
  --skip-update \
  --events "$webhook_events" \
  --forward-to "http://127.0.0.1:$site_port/api/auth/stripe/webhook" 2>&1 | \
  sed -E 's/whsec_[A-Za-z0-9_]+/<redacted>/g'
