#!/usr/bin/env bash

devme_boot_ios_simulator() {
  local devme_xcrun_bin="$1"
  local devme_simulator_udid="$2"
  local attempts="${IOS_SIMULATOR_READY_ATTEMPTS:-120}"
  local delay="${IOS_SIMULATOR_READY_DELAY_SECONDS:-1}"
  local attempt

  "$devme_xcrun_bin" simctl boot "$devme_simulator_udid" >/dev/null 2>&1 || true
  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if "$devme_xcrun_bin" simctl spawn "$devme_simulator_udid" \
      launchctl print user/foreground/com.apple.SpringBoard >/dev/null 2>&1; then
      return 0
    fi
    sleep "$delay"
  done

  printf 'Simulator %s did not expose SpringBoard after %s readiness checks.\n' \
    "$devme_simulator_udid" \
    "$attempts" >&2
  return 1
}
