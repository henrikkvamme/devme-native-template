#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"
source "$root/tooling/android-emulator-lifecycle.sh"
readonly sdk_root="${ANDROID_SDK_ROOT:-$root/.devme/android-sdk}"
readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="$(devme_convex_port "$slot")"
if declare -F devme_convex_site_port >/dev/null; then
  auth_site_port="$(devme_convex_site_port "$slot")"
else
  auth_site_port="$((convex_port + 1))"
fi
readonly auth_site_port
readonly emulator_port="$((5554 + slot * 2))"
readonly serial="emulator-$emulator_port"
readonly avd_name="starter-devme-$slot"
readonly image="system-images;android-37.0;google_apis_ps16k;arm64-v8a"
readonly adb="${ADB_BIN:-$sdk_root/platform-tools/adb}"
readonly emulator="${ANDROID_EMULATOR_BIN:-$sdk_root/emulator/emulator}"
readonly sdkmanager="${SDKMANAGER_BIN:-$sdk_root/cmdline-tools/latest/bin/sdkmanager}"
readonly avdmanager="${AVDMANAGER_BIN:-$sdk_root/cmdline-tools/latest/bin/avdmanager}"
readonly gradle="${GRADLE_BIN:-$root/apps/android/gradlew}"
readonly avd_home="${ANDROID_AVD_HOME:-$root/.devme/avd-$slot}"
readonly emulator_log="$root/.devme/android-emulator-$slot.log"
readonly launchctl_bin="${LAUNCHCTL_BIN:-launchctl}"
readonly platform="${DEVME_TEST_PLATFORM:-$(uname -s)}"
google_web_client_id="${GOOGLE_WEB_CLIENT_ID:-}"

export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"
export ANDROID_AVD_HOME="$avd_home"

if [[ -z "$google_web_client_id" && -f "$root/.env.auth.local" && -f "$root/tooling/auth-config.ts" ]]; then
  google_web_client_id="$(
    bun "$root/tooling/auth-config.ts" android-client-id --input "$root/.env.auth.local"
  )"
fi

if [[ ! -x "$emulator" || ! -d "$sdk_root/system-images/android-37.0/google_apis_ps16k/arm64-v8a" ]]; then
  "$sdkmanager" "emulator" "$image"
fi

mkdir -p "$avd_home" "$root/.devme"
if [[ ! -f "$avd_home/$avd_name.avd/config.ini" ]]; then
  printf 'no\n' | "$avdmanager" create avd \
    --name "$avd_name" \
    --package "$image" \
    --device pixel_9 \
    --force
fi

booted="$($adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
if [[ "$booted" != "1" ]] && ! "$adb" -s "$serial" get-state >/dev/null 2>&1; then
  if [[ "${DEVME_TEST_EMULATOR_FOREGROUND:-0}" == "1" ]]; then
    "$emulator" -avd "$avd_name" -port "$emulator_port" >"$emulator_log" 2>&1 &
  elif [[ "$platform" == "Darwin" ]]; then
    "$launchctl_bin" remove "devme.starter.android.$slot" >/dev/null 2>&1 || true
    "$launchctl_bin" submit \
      -l "devme.starter.android.$slot" \
      -o "$emulator_log" \
      -e "$emulator_log" \
      -- /usr/bin/env \
      ANDROID_HOME="$sdk_root" \
      ANDROID_SDK_ROOT="$sdk_root" \
      ANDROID_AVD_HOME="$avd_home" \
      HOME="$HOME" \
      "$emulator" -avd "$avd_name" -port "$emulator_port" -no-audio -no-boot-anim
    "$launchctl_bin" kickstart "gui/$(id -u)/devme.starter.android.$slot"
  else
    setsid "$emulator" -avd "$avd_name" -port "$emulator_port" \
      -no-audio -no-boot-anim >"$emulator_log" 2>&1 < /dev/null &
  fi

fi

if [[ "$booted" != "1" ]] && ! devme_wait_for_android_emulator_boot "$adb" "$serial"; then
  tail -n 100 "$emulator_log" >&2 || true
  exit 1
fi

gradle_arguments=(
  --project-dir "$root/apps/android"
  -PconvexUrl="http://10.0.2.2:$convex_port"
  -PauthSiteUrl="http://10.0.2.2:$auth_site_port"
)
if [[ -n "$google_web_client_id" ]]; then
  gradle_arguments+=("-PgoogleWebClientId=$google_web_client_id")
fi
"$gradle" "${gradle_arguments[@]}" assembleDebug

readonly apk="${ANDROID_APK_PATH:-$root/apps/android/app/build/outputs/apk/debug/app-debug.apk}"
"$adb" -s "$serial" install -r "$apk" >/dev/null
"$adb" -s "$serial" shell pm grant \
  dev.starter.app android.permission.ACCESS_LOCAL_NETWORK >/dev/null 2>&1 || true
"$adb" -s "$serial" shell am start -W -n dev.starter.app/.MainActivity >/dev/null

printf 'result:\n'
printf '  platform: "android"\n'
printf '  target: "%s"\n' "$serial"
printf '  backend_url: "http://10.0.2.2:%s"\n' "$convex_port"
printf '  auth_site_url: "http://10.0.2.2:%s"\n' "$auth_site_port"
printf '  log: "%s"\n' "$emulator_log"
