#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly sdk_root="$root/.devme/android-sdk"
readonly archive="$root/.devme/commandlinetools-mac-14742923_latest.zip"
readonly archive_url="https://dl.google.com/android/repository/commandlinetools-mac-14742923_latest.zip"
readonly archive_sha1="cc27cca4b84bfdbc7df17e3d0a01d0c640d8ee71"

mkdir -p "$root/.devme" "$sdk_root/cmdline-tools"

if [[ ! -x "$sdk_root/cmdline-tools/latest/bin/sdkmanager" ]]; then
  if [[ ! -f "$archive" ]]; then
    curl -fL "$archive_url" -o "$archive"
  fi

  actual_sha1="$(shasum -a 1 "$archive" | awk '{print $1}')"
  if [[ "$actual_sha1" != "$archive_sha1" ]]; then
    printf 'Android command-line tools checksum mismatch.\n' >&2
    exit 1
  fi

  rm -rf "$root/.devme/android-command-line-tools"
  mkdir -p "$root/.devme/android-command-line-tools"
  unzip -q "$archive" -d "$root/.devme/android-command-line-tools"
  rm -rf "$sdk_root/cmdline-tools/latest"
  mv "$root/.devme/android-command-line-tools/cmdline-tools" "$sdk_root/cmdline-tools/latest"
  rm -rf "$root/.devme/android-command-line-tools"
fi

export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"

set +o pipefail
yes | "$sdk_root/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null
set -o pipefail
"$sdk_root/cmdline-tools/latest/bin/sdkmanager" \
  "build-tools;36.0.0" \
  "platform-tools" \
  "platforms;android-37.0"
