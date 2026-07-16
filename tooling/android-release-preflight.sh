#!/usr/bin/env bash
set -euo pipefail

required=(
  ANDROID_UPLOAD_KEYSTORE_PATH
  ANDROID_UPLOAD_KEYSTORE_PASSWORD
  ANDROID_UPLOAD_KEY_ALIAS
  ANDROID_UPLOAD_KEY_PASSWORD
)

for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'Release builds must be signed. Set all ANDROID_UPLOAD_KEYSTORE_* variables.\n' >&2
    exit 1
  fi
done

if [[ "${RELEASE_APPLICATION_ID:-}" == "dev.starter.app" || -z "${RELEASE_APPLICATION_ID:-}" ]]; then
  printf 'Replace dev.starter.app before building a release.\n' >&2
  exit 1
fi

for name in RELEASE_CONVEX_URL; do
  value="${!name:-}"
  if [[ "$value" != https://* || "$value" == *replace-before-release* ]]; then
    printf '%s must be a production HTTPS URL.\n' "$name" >&2
    exit 1
  fi
done

if [[ -n "${RELEASE_AUTH_SITE_URL:-}" ]]; then
  if [[ "$RELEASE_AUTH_SITE_URL" != https://* || "$RELEASE_AUTH_SITE_URL" == *replace-before-release* ]]; then
    printf 'RELEASE_AUTH_SITE_URL must be a production HTTPS URL.\n' >&2
    exit 1
  fi
  for name in GOOGLE_WEB_CLIENT_ID ANDROID_ACCOUNT_DELETION_URL AUTH_DELETION_LIFECYCLE_VERIFIED; do
    if [[ -z "${!name:-}" ]]; then
      printf 'Auth-enabled release is missing %s.\n' "$name" >&2
      exit 1
    fi
  done
  if [[ "$ANDROID_ACCOUNT_DELETION_URL" != https://* ]]; then
    printf 'ANDROID_ACCOUNT_DELETION_URL must be a public HTTPS URL.\n' >&2
    exit 1
  fi
  if [[ "$AUTH_DELETION_LIFECYCLE_VERIFIED" != true ]]; then
    printf 'Verify provider revocation and app-data deletion, then set AUTH_DELETION_LIFECYCLE_VERIFIED=true.\n' >&2
    exit 1
  fi
fi
