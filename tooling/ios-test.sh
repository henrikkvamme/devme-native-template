#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"
source "$root/tooling/ios-simulator-ready.sh"
readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="$(devme_convex_port "$slot")"
readonly auth_site_port="$(devme_convex_site_port "$slot")"
readonly derived_data="$root/.devme/DerivedData-$slot"
readonly xcrun_bin="${XCRUN_BIN:-xcrun}"
readonly xcodebuild_bin="${XCODEBUILD_BIN:-xcodebuild}"
readonly simulator_name="Starter Unit $slot"
readonly simulator_device_type="$(
  "$xcrun_bin" simctl list devicetypes -j |
    jq -r '.devicetypes[] | select(.name == "iPhone 17 Pro") | .identifier' |
    head -n 1
)"
readonly simulator_runtime="$(
  "$xcrun_bin" simctl list runtimes available -j |
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
  "$xcrun_bin" simctl shutdown "$existing_udid" >/dev/null 2>&1 || true
  "$xcrun_bin" simctl delete "$existing_udid"
done < <(
  "$xcrun_bin" simctl list devices -j |
    jq -r --arg name "$simulator_name" '.devices[][] | select(.name == $name) | .udid'
)

readonly simulator_udid="$(
  "$xcrun_bin" simctl create "$simulator_name" "$simulator_device_type" "$simulator_runtime"
)"

cleanup_simulator() {
  "$xcrun_bin" simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
  "$xcrun_bin" simctl delete "$simulator_udid" >/dev/null 2>&1 || true
}
trap cleanup_simulator EXIT INT TERM

devme_boot_ios_simulator "$xcrun_bin" "$simulator_udid"

"$xcodebuild_bin" test \
  -project "$root/apps/ios/Starter.xcodeproj" \
  -scheme Starter \
  -destination "platform=iOS Simulator,id=$simulator_udid" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$root/.devme/SourcePackages" \
  -only-testing:StarterTests \
  CODE_SIGNING_ALLOWED=NO \
  CONVEX_URL="http://127.0.0.1:$convex_port" \
  AUTH_SITE_URL="http://127.0.0.1:$auth_site_port"
