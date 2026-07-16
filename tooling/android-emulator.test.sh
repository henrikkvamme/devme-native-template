#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/starter-android-emulator.XXXXXX")"
readonly sdk="$temporary_directory/sdk"
readonly commands="$temporary_directory/commands"

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

mkdir -p \
  "$sdk/platform-tools" \
  "$sdk/emulator" \
  "$sdk/system-images/android-37.0/google_apis_ps16k/arm64-v8a" \
  "$temporary_directory/avd/starter-devme-0.avd"
touch "$temporary_directory/avd/starter-devme-0.avd/config.ini" "$temporary_directory/app.apk"

cat >"$sdk/platform-tools/adb" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'adb %s\n' "$*" >>"$COMMAND_LOG"
if [[ " $* " == *" shell getprop sys.boot_completed "* ]]; then
  printf '1\n'
fi
SH

cat >"$sdk/emulator/emulator" <<'SH'
#!/usr/bin/env bash
printf 'emulator %s\n' "$*" >>"$COMMAND_LOG"
SH

cat >"$temporary_directory/gradle" <<'SH'
#!/usr/bin/env bash
printf 'gradle %s\n' "$*" >>"$COMMAND_LOG"
SH

chmod +x "$sdk/platform-tools/adb" "$sdk/emulator/emulator" "$temporary_directory/gradle"

output="$({
  COMMAND_LOG="$commands" \
  ANDROID_SDK_ROOT="$sdk" \
  ANDROID_AVD_HOME="$temporary_directory/avd" \
  ADB_BIN="$sdk/platform-tools/adb" \
  ANDROID_EMULATOR_BIN="$sdk/emulator/emulator" \
  GRADLE_BIN="$temporary_directory/gradle" \
  ANDROID_APK_PATH="$temporary_directory/app.apk" \
  DEVME_TEST_EMULATOR_FOREGROUND=1 \
    "$root/tooling/android-emulator.sh"
})"

grep -q 'gradle .*assembleDebug' "$commands"
grep -q 'adb -s emulator-5554 install -r' "$commands"
grep -q 'shell am start -W -n dev.starter.app/.MainActivity' "$commands"
grep -q 'target: "emulator-5554"' <<<"$output"
grep -q 'backend_url: "http://10.0.2.2:3210"' <<<"$output"
