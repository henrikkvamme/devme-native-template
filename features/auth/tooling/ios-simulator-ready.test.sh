#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
source "$root/tooling/ios-simulator-ready.sh"

cat >"$temp/xcrun" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_LOG"
if [[ "$*" == simctl\ spawn* ]]; then
  count="$(wc -l <"$FAKE_COUNT" | tr -d ' ')"
  printf 'x\n' >>"$FAKE_COUNT"
  if [[ "${ALWAYS_FAIL:-0}" == "1" || "$count" -eq 0 ]]; then
    exit 1
  fi
fi
SH
chmod +x "$temp/xcrun"
export FAKE_LOG="$temp/commands.log"
export FAKE_COUNT="$temp/count"
: >"$FAKE_COUNT"

IOS_SIMULATOR_READY_ATTEMPTS=2 \
IOS_SIMULATOR_READY_DELAY_SECONDS=0 \
  devme_boot_ios_simulator "$temp/xcrun" AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE

grep -Fq 'simctl boot AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE' "$FAKE_LOG"
[[ "$(grep -c 'launchctl print user/foreground/com.apple.SpringBoard' "$FAKE_LOG")" -eq 2 ]]

if ALWAYS_FAIL=1 \
  IOS_SIMULATOR_READY_ATTEMPTS=2 \
  IOS_SIMULATOR_READY_DELAY_SECONDS=0 \
  devme_boot_ios_simulator "$temp/xcrun" FFFFFFFF-BBBB-CCCC-DDDD-EEEEEEEEEEEE 2>/dev/null; then
  printf 'Expected bounded simulator readiness to fail.\n' >&2
  exit 1
fi
