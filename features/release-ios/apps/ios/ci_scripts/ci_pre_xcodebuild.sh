#!/bin/sh
set -eu

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
  exit 0
fi

project_dir="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
settings="$(
  xcodebuild \
    -project "$project_dir/Starter.xcodeproj" \
    -scheme Starter \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -showBuildSettings
)"

build_setting() {
  printf '%s\n' "$settings" | awk -F ' = ' -v key="$1" '$1 ~ "^[[:space:]]*" key "$" { print $2; exit }'
}

require_value() {
  key="$1"
  value="$(build_setting "$key")"
  if [ -z "$value" ] || printf '%s' "$value" | grep -Eq 'replace-before-release|replace-with|dev\.starter\.app'; then
    printf 'Archive blocked: configure the Release value for %s.\n' "$key" >&2
    exit 1
  fi
}

require_https() {
  key="$1"
  require_value "$key"
  value="$(build_setting "$key")"
  case "$value" in
    https://*) ;;
    *)
      printf 'Archive blocked: %s must use HTTPS.\n' "$key" >&2
      exit 1
      ;;
  esac
}

require_value PRODUCT_BUNDLE_IDENTIFIER
require_value DEVELOPMENT_TEAM
require_https CONVEX_URL

if [ -f "$project_dir/Starter/Backend/BetterAuthNativeClient.swift" ]; then
  require_https AUTH_SITE_URL
  require_value GOOGLE_AUTH_ENABLED
  case "$(build_setting GOOGLE_AUTH_ENABLED)" in
    YES)
      require_value GOOGLE_IOS_CLIENT_ID
      require_value GOOGLE_REVERSED_CLIENT_ID
      require_value GOOGLE_SERVER_CLIENT_ID
      ;;
    NO) ;;
    *)
      printf 'Archive blocked: GOOGLE_AUTH_ENABLED must be YES or NO.\n' >&2
      exit 1
      ;;
  esac
  require_value AUTH_DELETION_LIFECYCLE_VERIFIED
  if [ "$(build_setting AUTH_DELETION_LIFECYCLE_VERIFIED)" != "YES" ]; then
    printf 'Archive blocked: verify provider revocation and app-data deletion, then set AUTH_DELETION_LIFECYCLE_VERIFIED = YES.\n' >&2
    exit 1
  fi
fi
