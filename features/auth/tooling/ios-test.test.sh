#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT

cat >"$temp/xcrun" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_LOG"
case "$*" in
  "simctl list devicetypes -j")
    printf '%s\n' '{"devicetypes":[{"name":"iPhone 17 Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"}]}'
    ;;
  "simctl list runtimes available -j")
    printf '%s\n' '{"runtimes":[{"isAvailable":true,"name":"iOS 26.5","version":"26.5","identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-5"}]}'
    ;;
  "simctl list devices -j")
    printf '%s\n' '{"devices":{}}'
    ;;
  simctl\ create*)
    printf '%s\n' 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'
    ;;
esac
SH

cat >"$temp/xcodebuild" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_LOG"
[[ " $* " == *" -destination platform=iOS Simulator,id=AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE "* ]]
SH

chmod +x "$temp/xcrun" "$temp/xcodebuild"
export FAKE_LOG="$temp/commands.log"

DEVME_SLOT=3 \
  XCRUN_BIN="$temp/xcrun" \
  XCODEBUILD_BIN="$temp/xcodebuild" \
  "$root/tooling/ios-test.sh"

grep -Fq 'simctl create Starter Unit 3' "$FAKE_LOG"
grep -Fq 'simctl boot AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE' "$FAKE_LOG"
grep -Fq 'simctl spawn AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE launchctl print user/foreground/com.apple.SpringBoard' "$FAKE_LOG"
grep -Fq 'simctl shutdown AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE' "$FAKE_LOG"
grep -Fq 'simctl delete AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE' "$FAKE_LOG"
