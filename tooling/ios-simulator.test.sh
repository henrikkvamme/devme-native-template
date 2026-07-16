#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT

cat >"$temp/auth.env" <<'EOF'
GOOGLE_WEB_CLIENT_ID=123-web.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=123-ios.apps.googleusercontent.com
EOF
export AUTH_CONFIG_FILE="$temp/auth.env"
export IOS_AUTH_XCCONFIG="$temp/Auth.local.xcconfig"

cat >"$temp/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_LOG"
if [[ "$*" == "simctl list devices available" ]]; then
  if [[ "${SIMULATOR_LIST_EMPTY:-0}" != "1" ]]; then
    printf '    iPhone 17 Pro (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)\n'
  fi
elif [[ "$*" == "simctl list devices booted" ]]; then
  exit 0
fi
EOF

cat >"$temp/xcodebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
derived_data=""
while (($#)); do
  if [[ "$1" == "-derivedDataPath" ]]; then
    derived_data="$2"
    shift 2
  else
    shift
  fi
done
mkdir -p "$derived_data/Build/Products/Debug-iphonesimulator/Starter.app"
: >"$derived_data/Build/Products/Debug-iphonesimulator/Starter.app/Info.plist"
EOF

cat >"$temp/plistbuddy" <<'EOF'
#!/usr/bin/env bash
printf 'dev.starter.app\n'
EOF

chmod +x "$temp/xcrun" "$temp/xcodebuild" "$temp/plistbuddy"

export FAKE_LOG="$temp/commands.log"
output="$({
  DEVME_SLOT=0 \
    XCRUN_BIN="$temp/xcrun" \
    XCODEBUILD_BIN="$temp/xcodebuild" \
    PLIST_BUDDY_BIN="$temp/plistbuddy" \
    "$root/tooling/ios-simulator.sh"
})"

[[ "$output" == *'status: launched'* ]]
[[ "$output" == *'simulator_udid: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"'* ]]
[[ "$output" == *'bundle_id: "dev.starter.app"'* ]]
grep -Fq 'simctl install AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE' "$FAKE_LOG"
grep -Fq 'simctl launch --terminate-running-process AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE dev.starter.app' "$FAKE_LOG"

if SIMULATOR_LIST_EMPTY=1 \
  XCRUN_BIN="$temp/xcrun" \
  XCODEBUILD_BIN="$temp/xcodebuild" \
  PLIST_BUDDY_BIN="$temp/plistbuddy" \
  "$root/tooling/ios-simulator.sh" >"$temp/error.out"; then
  printf 'Expected missing simulator discovery to fail.\n' >&2
  exit 1
fi
grep -Fq 'error: "No available iPhone 17 Pro simulator was found."' "$temp/error.out"
