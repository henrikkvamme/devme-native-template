#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"
readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="$(devme_convex_port "$slot")"
readonly derived_data="$root/.devme/DerivedData-$slot"
readonly result_bundle="$root/.devme/ios-e2e-$slot.xcresult"
readonly attachments="$root/.devme/ios-e2e-attachments-$slot"
readonly simulator_udid="$(
  xcrun simctl list devices available |
    sed -nE 's/^[[:space:]]*iPhone 17 Pro \(([A-F0-9-]+)\).*/\1/p' |
    tail -n 1
)"

if [[ -z "$simulator_udid" ]]; then
  printf 'No available iPhone 17 Pro simulator was found.\n' >&2
  exit 1
fi

IFS=$'\t' read -r before_id _ < <(
  CONVEX_URL="http://127.0.0.1:$convex_port" \
    bun "$root/backend/test/latest-event.ts"
)

rm -rf "$result_bundle"
# Unit tests and UI tests share the same named simulator. Reboot it between
# phases so SpringBoard has completed its previous test-runner teardown before
# Xcode asks it to launch the UI runner.
xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
xcrun simctl boot "$simulator_udid"
xcrun simctl bootstatus "$simulator_udid" -b

xcodebuild test \
  -project "$root/apps/ios/Starter.xcodeproj" \
  -scheme Starter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$root/.devme/SourcePackages" \
  -resultBundlePath "$result_bundle" \
  -only-testing:StarterUITests \
  CODE_SIGNING_ALLOWED=NO \
  CONVEX_URL="http://127.0.0.1:$convex_port"

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
