#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"
readonly sdk_root="${ANDROID_SDK_ROOT:-$root/.devme/android-sdk}"
readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="$(devme_convex_port "$slot")"
readonly emulator_port="$((5554 + slot * 2))"
readonly serial="emulator-$emulator_port"
readonly avd_name="sambu-devme-$slot"
readonly image="system-images;android-37.0;google_apis_ps16k;arm64-v8a"
readonly adb="$sdk_root/platform-tools/adb"
readonly emulator="$sdk_root/emulator/emulator"
readonly avd_home="$root/.devme/avd-$slot"
readonly emulator_log="$root/.devme/android-emulator-$slot.log"
readonly screenshot="$root/.devme/android-home-$slot.png"

export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"
export ANDROID_AVD_HOME="$avd_home"

if [[ ! -x "$emulator" || ! -d "$sdk_root/system-images/android-37.0/google_apis_ps16k/arm64-v8a" ]]; then
  "$sdk_root/cmdline-tools/latest/bin/sdkmanager" "emulator" "$image"
fi

mkdir -p "$avd_home"
if [[ ! -f "$avd_home/$avd_name.avd/config.ini" ]]; then
  printf 'no\n' | "$sdk_root/cmdline-tools/latest/bin/avdmanager" create avd \
    --name "$avd_name" \
    --package "$image" \
    --device pixel_9 \
    --force
fi

cleanup() {
  "$adb" -s "$serial" emu kill >/dev/null 2>&1 || true
  if [[ -n "${emulator_pid:-}" ]]; then
    wait "$emulator_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

"$adb" -s "$serial" emu kill >/dev/null 2>&1 || true
"$emulator" \
  -avd "$avd_name" \
  -port "$emulator_port" \
  -no-audio \
  -no-boot-anim \
  -no-snapshot \
  -no-window \
  -wipe-data \
  >"$emulator_log" 2>&1 &
emulator_pid=$!

deadline=$((SECONDS + 300))
until [[ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
  if ((SECONDS >= deadline)); then
    tail -n 100 "$emulator_log" >&2
    printf 'Android emulator did not finish booting.\n' >&2
    exit 1
  fi
  sleep 2
done

"$root/apps/android/gradlew" \
  --project-dir "$root/apps/android" \
  -PconvexUrl="http://10.0.2.2:$convex_port" \
  assembleDebug

readonly apk="$root/apps/android/app/build/outputs/apk/debug/app-debug.apk"
"$adb" -s "$serial" install -r "$apk" >/dev/null
"$adb" -s "$serial" shell pm grant \
  dev.sambu.app android.permission.ACCESS_LOCAL_NETWORK
"$adb" -s "$serial" shell am start -W \
  -n dev.sambu.app/.MainActivity >/dev/null

deadline=$((SECONDS + 60))
while true; do
  "$adb" -s "$serial" shell uiautomator dump /sdcard/sambu-window.xml >/dev/null
  ui="$("$adb" -s "$serial" shell cat /sdcard/sambu-window.xml)"
  if [[ "$ui" == *"Connected to Convex"* && "$ui" == *"Send native ping"* ]]; then
    break
  fi
  if ((SECONDS >= deadline)); then
    printf '%s\n' "$ui" >&2
    "$adb" -s "$serial" logcat -d -t 200 >&2
    printf 'Android UI did not render the deployed Convex event.\n' >&2
    exit 1
  fi
  sleep 2
done

IFS=$'\t' read -r before_id _ < <(
  CONVEX_URL="http://127.0.0.1:$convex_port" \
    bun "$root/backend/test/latest-event.ts"
)

button_bounds="$(
  printf '%s\n' "$ui" |
    sed -n 's/.*text="Send native ping"[^>]*bounds="\([^"]*\)".*/\1/p'
)"
if [[ ! "$button_bounds" =~ ^\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]$ ]]; then
  printf 'Could not locate the native ping button in the Android UI.\n' >&2
  exit 1
fi

tap_x="$((BASH_REMATCH[1] + (BASH_REMATCH[3] - BASH_REMATCH[1]) / 2))"
tap_y="$((BASH_REMATCH[2] + (BASH_REMATCH[4] - BASH_REMATCH[2]) / 2))"
"$adb" -s "$serial" shell input tap "$tap_x" "$tap_y"

deadline=$((SECONDS + 60))
while true; do
  IFS=$'\t' read -r latest_id latest_client < <(
    CONVEX_URL="http://127.0.0.1:$convex_port" \
      bun "$root/backend/test/latest-event.ts"
  )
  "$adb" -s "$serial" shell uiautomator dump /sdcard/sambu-window.xml >/dev/null
  ui="$("$adb" -s "$serial" shell cat /sdcard/sambu-window.xml)"
  if [[ "$latest_id" != "$before_id" && "$latest_client" == "android" && "$ui" == *'text="Android"'* ]]; then
    break
  fi
  if ((SECONDS >= deadline)); then
    printf '%s\n' "$ui" >&2
    "$adb" -s "$serial" logcat -d -t 200 >&2
    printf 'Android native mutation did not reach Convex and render reactively.\n' >&2
    exit 1
  fi
  sleep 2
done

sleep 1
"$adb" -s "$serial" exec-out screencap -p >"$screenshot"
printf 'Android UI verified on %s. Screenshot: %s\n' "$serial" "$screenshot"
