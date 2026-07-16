#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"
readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="$(devme_convex_port "$slot")"
readonly auth_site_port="$(devme_convex_site_port "$slot")"
readonly derived_data="$root/.devme/DerivedData-$slot"
readonly result_bundle="$root/.devme/ios-e2e-$slot.xcresult"
readonly attachments="$root/.devme/ios-e2e-attachments-$slot"
readonly simulator_name="Starter E2E $slot"
readonly simulator_device_type="$(
  xcrun simctl list devicetypes -j |
    jq -r '.devicetypes[] | select(.name == "iPhone 17 Pro") | .identifier' |
    head -n 1
)"
readonly simulator_runtime="$(
  xcrun simctl list runtimes available -j |
    jq -r '
      [
        .runtimes[]
        | select(.isAvailable and (.name | startswith("iOS ")))
        | { identifier, version: (.version | split(".") | map(tonumber)) }
      ]
      | sort_by(.version)
      | last
      | .identifier // empty
    '
)"

if [[ -z "$simulator_device_type" || -z "$simulator_runtime" ]]; then
  printf 'No available iPhone 17 Pro simulator runtime was found.\n' >&2
  exit 1
fi

while IFS= read -r existing_udid; do
  [[ -z "$existing_udid" ]] && continue
  xcrun simctl shutdown "$existing_udid" >/dev/null 2>&1 || true
  xcrun simctl delete "$existing_udid"
done < <(
  xcrun simctl list devices -j |
    jq -r --arg name "$simulator_name" '.devices[][] | select(.name == $name) | .udid'
)

readonly simulator_udid="$(
  xcrun simctl create "$simulator_name" "$simulator_device_type" "$simulator_runtime"
)"

cleanup_simulator() {
  xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
  xcrun simctl delete "$simulator_udid" >/dev/null 2>&1 || true
}
trap cleanup_simulator EXIT INT TERM

IFS=$'\t' read -r before_id _ < <(
  CONVEX_URL="http://127.0.0.1:$convex_port" \
    bun "$root/backend/test/latest-event.ts"
)

rm -rf "$result_bundle"
xcrun simctl boot "$simulator_udid"
xcrun simctl bootstatus "$simulator_udid" -b

xcodebuild test \
  -project "$root/apps/ios/Starter.xcodeproj" \
  -scheme Starter \
  -destination "platform=iOS Simulator,id=$simulator_udid" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$root/.devme/SourcePackages" \
  -resultBundlePath "$result_bundle" \
  -only-testing:StarterUITests \
  CONVEX_URL="http://127.0.0.1:$convex_port" \
  AUTH_SITE_URL="http://127.0.0.1:$auth_site_port"

IFS=$'\t' read -r latest_id latest_client < <(
  CONVEX_URL="http://127.0.0.1:$convex_port" \
    bun "$root/backend/test/latest-event.ts"
)

if [[ "$latest_id" == "$before_id" || "$latest_client" != "ios" ]]; then
  printf 'The iOS UI test did not publish a new native Convex event.\n' >&2
  exit 1
fi

rm -rf "$attachments"
xcrun xcresulttool export attachments \
  --path "$result_bundle" \
  --output-path "$attachments" >/dev/null

printf 'iOS native mutation and reactive UI verified. Result: %s Attachments: %s\n' \
  "$result_bundle" \
  "$attachments"
