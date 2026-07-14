#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"

readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="$(devme_convex_port "$slot")"
readonly derived_data="$root/.devme/DerivedData-simulator-$slot"
readonly build_log="$root/.devme/ios-simulator-build-$slot.log"
readonly xcrun_bin="${XCRUN_BIN:-xcrun}"
readonly xcodebuild_bin="${XCODEBUILD_BIN:-xcodebuild}"
readonly plist_buddy_bin="${PLIST_BUDDY_BIN:-/usr/libexec/PlistBuddy}"

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

resolve_simulator() {
  if [[ -n "${SIMULATOR_UDID:-}" ]]; then
    printf '%s\t%s\n' "$SIMULATOR_UDID" "Selected iOS Simulator"
    return
  fi

  local record
  record="$({
    "$xcrun_bin" simctl list devices available |
      sed -nE 's/^[[:space:]]*(iPhone 17 Pro) \(([A-F0-9-]+)\).*/\2\t\1/p' |
      tail -n 1
  })"
  if [[ -z "$record" ]]; then
    fail \
      'No available iPhone 17 Pro simulator was found.' \
      'Install the current iOS Simulator runtime in Xcode, or set SIMULATOR_UDID, then retry.'
  fi
  printf '%s\n' "$record"
}

if ! simulator_record="$(resolve_simulator)"; then
  printf '%s\n' "$simulator_record"
  exit 1
fi
IFS=$'\t' read -r simulator_udid simulator_name <<<"$simulator_record"

mkdir -p "$root/.devme"
if ! "$xcodebuild_bin" build \
  -quiet \
  -project "$root/apps/ios/Starter.xcodeproj" \
  -scheme Starter \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_udid" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$root/.devme/SourcePackages" \
  CODE_SIGNING_ALLOWED=NO \
  CONVEX_URL="http://127.0.0.1:$convex_port" >"$build_log" 2>&1; then
  tail -n 80 "$build_log" >&2
  fail \
    'Xcode could not build Starter for the selected simulator.' \
    'Inspect the build diagnostics above, fix Xcode or compilation, then retry.'
fi

readonly app="$derived_data/Build/Products/Debug-iphonesimulator/Starter.app"
if [[ ! -d "$app" ]]; then
  fail \
    'Xcode reported success without producing Starter.app.' \
    'Inspect the Xcode build output and the configured DerivedData path.'
fi

if ! "$xcrun_bin" simctl list devices booted | grep -Fq "$simulator_udid"; then
  "$xcrun_bin" simctl boot "$simulator_udid" >/dev/null
fi
"$xcrun_bin" simctl bootstatus "$simulator_udid" -b >/dev/null

readonly bundle_id="$("$plist_buddy_bin" -c 'Print :CFBundleIdentifier' "$app/Info.plist")"
if ! "$xcrun_bin" simctl install "$simulator_udid" "$app" >/dev/null; then
  fail \
    'Simulator could not install Starter.' \
    'Restart the selected simulator, then retry.'
fi
if ! "$xcrun_bin" simctl launch --terminate-running-process "$simulator_udid" "$bundle_id" >/dev/null; then
  fail \
    'Simulator installed Starter but could not launch it.' \
    'Open Simulator, inspect its state, then retry.'
fi
open -a Simulator >/dev/null 2>&1 || true

printf 'result:\n'
printf '  status: launched\n'
printf '  simulator: %s\n' "$(toon_quote "$simulator_name")"
printf '  bundle_id: %s\n' "$(toon_quote "$bundle_id")"
printf '  backend_url: %s\n' "$(toon_quote "http://127.0.0.1:$convex_port")"
