#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
source "$root/tooling/android-emulator-lifecycle.sh"

cat >"$temp/adb" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
count="$(wc -l <"$FAKE_COUNT" | tr -d ' ')"
printf 'x\n' >>"$FAKE_COUNT"
if [[ "${ALWAYS_STUCK:-0}" == "1" ]]; then
  if [[ "$MODE" == "shutdown" ]]; then
    exit 0
  fi
  exit 1
fi
if [[ "$MODE" == "shutdown" ]]; then
  ((count == 0)) && exit 0
  exit 1
fi
((count == 0)) && exit 1
printf '1\n'
SH
chmod +x "$temp/adb"
export FAKE_COUNT="$temp/count"

: >"$FAKE_COUNT"
MODE=shutdown ANDROID_EMULATOR_SHUTDOWN_ATTEMPTS=2 ANDROID_EMULATOR_LIFECYCLE_DELAY_SECONDS=0   devme_wait_for_android_emulator_shutdown "$temp/adb" emulator-5554
[[ "$(wc -l <"$FAKE_COUNT" | tr -d ' ')" -eq 2 ]]

: >"$FAKE_COUNT"
MODE=boot ANDROID_EMULATOR_BOOT_ATTEMPTS=2 ANDROID_EMULATOR_LIFECYCLE_DELAY_SECONDS=0   devme_wait_for_android_emulator_boot "$temp/adb" emulator-5554
[[ "$(wc -l <"$FAKE_COUNT" | tr -d ' ')" -eq 2 ]]

: >"$FAKE_COUNT"
if MODE=shutdown   ALWAYS_STUCK=1   ANDROID_EMULATOR_SHUTDOWN_ATTEMPTS=2   ANDROID_EMULATOR_LIFECYCLE_DELAY_SECONDS=0   devme_wait_for_android_emulator_shutdown "$temp/adb" emulator-5554 2>/dev/null; then
  printf 'Expected bounded Android emulator shutdown to fail.\n' >&2
  exit 1
fi

