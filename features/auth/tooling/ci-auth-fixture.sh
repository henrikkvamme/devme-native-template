#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temp_root="${RUNNER_TEMP:-$root/.devme}"
readonly private_key="$temp_root/devme-ci-auth-key.p8"

mkdir -p "$temp_root"
umask 077
openssl genpkey   -algorithm EC   -pkeyopt ec_paramgen_curve:P-256   -out "$private_key"

cat >"$root/.env.auth.local" <<ENV
AUTH_APP_NAME=Devme CI
GOOGLE_WEB_CLIENT_ID=ci-web.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=ci-ios.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=ci-android.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=ci-google-client-secret
APPLE_CLIENT_ID=dev.devme.ci
APPLE_TEAM_ID=DEVME12345
APPLE_KEY_ID=DEVME12345
APPLE_PRIVATE_KEY_FILE=$private_key
APPLE_APP_BUNDLE_IDENTIFIER=dev.starter.app
ENV

if [[ "${DEVME_CI_WITH_STRIPE:-0}" == "1" ]]; then
  cat >>"$root/.env.auth.local" <<'ENV'
STRIPE_SECRET_KEY=sk_test_devme_ci_fixture
STRIPE_WEBHOOK_SECRET=whsec_devme_ci_fixture
STRIPE_PRICE_ID=price_devme_ci_fixture
ENV
fi
