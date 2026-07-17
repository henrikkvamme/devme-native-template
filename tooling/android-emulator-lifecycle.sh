#!/usr/bin/env bash

devme_wait_for_android_emulator_shutdown() {
  local adb_bin="$1"
  local device_serial="$2"
  local attempts="${ANDROID_EMULATOR_SHUTDOWN_ATTEMPTS:-60}"
  local delay="${ANDROID_EMULATOR_LIFECYCLE_DELAY_SECONDS:-1}"

  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    if ! "$adb_bin" -s "$device_serial" get-state >/dev/null 2>&1; then
      return 0
    fi
    sleep "$delay"
  done

  printf 'Android emulator %s did not shut down after %s checks.\n' "$device_serial" "$attempts" >&2
  return 1
}

devme_wait_for_android_emulator_boot() {
  local adb_bin="$1"
  local device_serial="$2"
  local attempts="${ANDROID_EMULATOR_BOOT_ATTEMPTS:-150}"
  local delay="${ANDROID_EMULATOR_LIFECYCLE_DELAY_SECONDS:-2}"

  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    if [[ "$("$adb_bin" -s "$device_serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
      return 0
    fi
    sleep "$delay"
  done

  printf 'Android emulator %s did not finish booting after %s checks.\n' "$device_serial" "$attempts" >&2
  return 1
}
