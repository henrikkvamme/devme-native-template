#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"

readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="$(devme_convex_port "$slot")"
readonly derived_data="$root/.devme/DerivedData-device-$slot"
readonly build_log="$root/.devme/ios-device-build-$slot.log"
readonly result_bundle="$root/.devme/ios-device-e2e-$slot.xcresult"
readonly e2e_log="$root/.devme/ios-device-e2e-$slot.log"
readonly attachments="$root/.devme/ios-device-e2e-attachments-$slot"
readonly xcrun_bin="${XCRUN_BIN:-xcrun}"
readonly xcodebuild_bin="${XCODEBUILD_BIN:-xcodebuild}"
readonly defaults_bin="${DEFAULTS_BIN:-defaults}"
readonly plist_buddy_bin="${PLIST_BUDDY_BIN:-/usr/libexec/PlistBuddy}"
readonly bun_bin="${BUN_BIN:-bun}"

mkdir -p "$root/.devme"

fail() {
  local message="$1"
  local help="$2"
  printf 'error: "%s"\n' "$message"
  printf 'help[1]: "%s"\n' "$help"
  exit 1
}

toon_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

resolve_device() {
  local record device_json
  device_json="$(mktemp)"
  if ! "$xcrun_bin" devicectl list devices \
    --json-output "$device_json" >/dev/null 2>&1; then
    rm -f "$device_json"
    fail \
      'CoreDevice could not list connected physical iOS devices.' \
      'Reconnect and unlock the iPhone, verify pairing, then retry.'
  fi
  if ! record="$({
    SELECTED_IOS_DEVICE="${IOS_DEVICE_UDID:-}" \
      "$bun_bin" -e '
        const payload = await Bun.stdin.json();
        const selected = process.env.SELECTED_IOS_DEVICE ?? "";
        const physical = (payload.result?.devices ?? []).filter((device) =>
          device.hardwareProperties?.reality === "physical" &&
          device.hardwareProperties?.platform === "iOS"
        );
        const matches = selected
          ? physical.filter((device) => device.hardwareProperties?.udid === selected)
          : physical;
        if (matches.length !== 1) process.exit(1);
        console.log(`${matches[0].hardwareProperties.udid}\t${matches[0].deviceProperties.name}`);
      ' <"$device_json"
  })"; then
    rm -f "$device_json"
    fail \
      'Could not select exactly one connected physical iOS device.' \
      'Connect one unlocked iPhone, or set IOS_DEVICE_UDID to a device identifier, then retry.'
  fi
  rm -f "$device_json"
  printf '%s\n' "$record"
}

resolve_development_team() {
  local team="${IOS_DEVELOPMENT_TEAM:-${DEVELOPMENT_TEAM:-}}"
  if [[ -z "$team" ]]; then
    team="$("$defaults_bin" read com.apple.dt.Xcode IDEProvisioningTeamManagerLastSelectedTeamID 2>/dev/null || true)"
  fi
  if [[ -z "$team" ]]; then
    fail \
      'No Xcode development team could be resolved.' \
      'Select a team in Xcode Accounts, or set IOS_DEVELOPMENT_TEAM, then retry.'
  fi
  printf '%s\n' "$team"
}

build_app() {
  local device_id="$1"
  local development_team="$2"
  local backend_url="$3"
  local auth_site_url="$4"

  if ! "$xcodebuild_bin" build \
    -quiet \
    -project "$root/apps/ios/Starter.xcodeproj" \
    -scheme Starter \
    -configuration Debug \
    -destination "platform=iOS,id=$device_id" \
    -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$root/.devme/SourcePackages" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$development_team" \
    CODE_SIGN_STYLE=Automatic \
    CONVEX_URL="$backend_url" \
    AUTH_SITE_URL="$auth_site_url" >"$build_log" 2>&1; then
    tail -n 80 "$build_log" >&2
    fail \
      'Xcode could not build and sign Starter for the selected iPhone.' \
      'Inspect the build diagnostics above, fix Xcode signing or compilation, then retry ios-device.'
  fi
}

launch_app() {
  local device_id="$1"
  local device_name="$2"
  local development_team="$3"
  local backend_url="$4"
  local auth_site_url="$5"
  local app="$derived_data/Build/Products/Debug-iphoneos/Starter.app"

  build_app "$device_id" "$development_team" "$backend_url" "$auth_site_url"
  if [[ ! -d "$app" ]]; then
    fail \
      'Xcode reported success without producing Starter.app.' \
      'Inspect the Xcode build output and the configured DerivedData path.'
  fi

  local bundle_id
  bundle_id="$("$plist_buddy_bin" -c 'Print :CFBundleIdentifier' "$app/Info.plist")"
  local install_output
  if ! install_output="$("$xcrun_bin" devicectl device install app --device "$device_id" "$app" 2>&1)"; then
    printf '%s\n' "$install_output" >&2
    fail \
      'CoreDevice could not install Starter on the selected iPhone.' \
      'Reconnect and unlock the iPhone, verify Developer Mode, then retry ios-device.'
  fi

  local launch_output
  if ! launch_output="$("$xcrun_bin" devicectl device process launch \
    --device "$device_id" \
    --terminate-existing \
    "$bundle_id" 2>&1)"; then
    printf '%s\n' "$launch_output" >&2
    if [[ "$launch_output" == *'reason: Locked'* || "$launch_output" == *'FBSOpenApplicationErrorDomain error 7'* ]]; then
      fail \
        'Starter was installed, but the iPhone locked before it could launch.' \
        'Unlock the iPhone, keep its screen awake, then retry ios-device.'
    fi
    fail \
      'Starter was installed, but CoreDevice could not launch it.' \
      'Reconnect and unlock the iPhone, verify Developer Mode, then retry ios-device.'
  fi

  printf 'result:\n'
  printf '  status: launched\n'
  printf '  device: %s\n' "$(toon_quote "$device_name")"
  printf '  bundle_id: %s\n' "$(toon_quote "$bundle_id")"
  printf '  backend_url: %s\n' "$(toon_quote "$backend_url")"
  printf '  auth_site_url: %s\n' "$(toon_quote "$auth_site_url")"
}

latest_event() {
  local output
  if ! output="$(CONVEX_URL="http://127.0.0.1:$convex_port" \
    "$bun_bin" "$root/backend/test/latest-event.ts" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail \
      'The latest Convex event could not be queried.' \
      'Verify the local Convex service and deployed functions, then retry ios-device-e2e.'
  fi
  if [[ "$output" != *$'\t'* ]]; then
    fail \
      'The latest Convex event response had an unexpected shape.' \
      'Run backend-live-smoke, inspect the backend contract, then retry ios-device-e2e.'
  fi
  printf '%s\n' "$output"
}

run_e2e() {
  local device_id="$1"
  local device_name="$2"
  local development_team="$3"
  local backend_url="$4"
  local auth_site_url="$5"
  local before_event before_id latest_event_record latest_id latest_client

  if ! before_event="$(latest_event)"; then
    printf '%s\n' "$before_event"
    exit 1
  fi
  IFS=$'\t' read -r before_id _ <<<"$before_event"

  rm -rf "$result_bundle" "$attachments"
  printf 'Keep %s unlocked with its screen awake while XCTest runs.\n' "$device_name" >&2
  if ! "$xcodebuild_bin" test \
    -quiet \
    -project "$root/apps/ios/Starter.xcodeproj" \
    -scheme Starter \
    -configuration Debug \
    -destination "platform=iOS,id=$device_id" \
    -destination-timeout 30 \
    -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$root/.devme/SourcePackages" \
    -resultBundlePath "$result_bundle" \
    -only-testing:StarterUITests \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$development_team" \
    CODE_SIGN_STYLE=Automatic \
    CONVEX_URL="$backend_url" \
    AUTH_SITE_URL="$auth_site_url" >"$e2e_log" 2>&1; then
    tail -n 100 "$e2e_log" >&2
    fail \
      'The physical iOS UI test did not complete successfully.' \
      'Keep the phone unlocked, inspect the result bundle and diagnostics above, then retry ios-device-e2e.'
  fi

  if ! latest_event_record="$(latest_event)"; then
    printf '%s\n' "$latest_event_record"
    exit 1
  fi
  IFS=$'\t' read -r latest_id latest_client <<<"$latest_event_record"
  if [[ "$latest_id" == "$before_id" || "$latest_client" != "ios" ]]; then
    fail \
      'The physical iOS UI test did not publish a new Convex event.' \
      'Keep the phone unlocked, inspect the result bundle, then retry ios-device-e2e.'
  fi

  if ! "$xcrun_bin" xcresulttool export attachments \
    --path "$result_bundle" \
    --output-path "$attachments" >/dev/null; then
    fail \
      'XCTest passed, but its screenshot attachments could not be exported.' \
      'Inspect the result bundle under .devme and retry ios-device-e2e.'
  fi

  printf 'result:\n'
  printf '  status: passed\n'
  printf '  device: %s\n' "$(toon_quote "$device_name")"
  printf '  backend_url: %s\n' "$(toon_quote "$backend_url")"
  printf '  auth_site_url: %s\n' "$(toon_quote "$auth_site_url")"
  printf '  result_bundle: %s\n' "$(toon_quote "$result_bundle")"
  printf '  attachments: %s\n' "$(toon_quote "$attachments")"
}

case "${1:-}" in
  launch | e2e)
    "$root/tooling/tailscale-convex.sh" require-ios-peer
    if ! backend_url="$("$root/tooling/tailscale-convex.sh" url)"; then
      printf '%s\n' "$backend_url"
      exit 1
    fi
    if ! auth_site_url="$("$root/tooling/tailscale-convex.sh" site-url)"; then
      printf '%s\n' "$auth_site_url"
      exit 1
    fi
    if ! device_record="$(resolve_device)"; then
      printf '%s\n' "$device_record"
      exit 1
    fi
    IFS=$'\t' read -r device_id device_name <<<"$device_record"
    if ! development_team="$(resolve_development_team)"; then
      printf '%s\n' "$development_team"
      exit 1
    fi

    if [[ "$1" == "launch" ]]; then
      launch_app "$device_id" "$device_name" "$development_team" "$backend_url" "$auth_site_url"
    else
      run_e2e "$device_id" "$device_name" "$development_team" "$backend_url" "$auth_site_url"
    fi
    ;;
  *)
    printf 'error: "Expected one of: launch, e2e."\n'
    printf 'help[1]: "Run this helper through ios-device or ios-device-e2e in Devme."\n'
    exit 2
    ;;
esac
