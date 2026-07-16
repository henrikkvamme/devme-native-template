#!/usr/bin/env bash

set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temporary_directory="$(mktemp -d)"
readonly fake_bin="$temporary_directory/bin"
readonly command_log="$temporary_directory/commands.log"
readonly real_bun="$(command -v bun)"

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

mkdir -p "$fake_bin"
: >"$command_log"
cat >"$temporary_directory/auth.env" <<'EOF'
GOOGLE_WEB_CLIENT_ID=123-web.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=123-ios.apps.googleusercontent.com
EOF
export AUTH_CONFIG_FILE="$temporary_directory/auth.env"
export IOS_AUTH_XCCONFIG="$temporary_directory/Auth.local.xcconfig"

cat >"$fake_bin/tailscale" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "status" && "${2:-}" == "--json" ]]; then
  online="${TAILSCALE_PEER_ONLINE:-true}"
  self_online="${TAILSCALE_SELF_ONLINE:-true}"
  printf '{"BackendState":"Running","Self":{"DNSName":"macbook.example.ts.net.","Online":%s},"Peer":{"phone":{"DNSName":"iphone.example.ts.net.","OS":"iOS","Online":%s}}}\n' "$self_online" "$online"
  exit 0
fi

if [[ "${1:-}" == "serve" && "${2:-}" == "status" && "${3:-}" == "--json" ]]; then
  state="${SERVE_STATE:-/nonexistent}"
  first=true
  printf '{"TCP":{'
  for port in 8443 8444; do
    if [[ -f "$state-$port" ]]; then
      [[ "$first" == true ]] || printf ','
      printf '"%s":{"HTTPS":true}' "$port"
      first=false
    fi
  done
  printf '},"Web":{'
  first=true
  for port in 8443 8444; do
    if [[ -f "$state-$port" ]]; then
      [[ "$first" == true ]] || printf ','
      target="$(cat "$state-$port")"
      printf '"macbook.example.ts.net:%s":{"Handlers":{"/":{"Proxy":"%s"}}}' "$port" "$target"
      first=false
    fi
  done
  printf '}}\n'
  exit 0
fi

if [[ "${1:-}" == "serve" && "$*" == *'--bg'* ]]; then
  for argument in "$@"; do
    if [[ "$argument" == --https=* ]]; then port="${argument#--https=}"; fi
  done
  printf '%s\n' "${*: -1}" >"$SERVE_STATE-$port"
fi

if [[ "${1:-}" == "serve" && "${*: -1}" == "off" ]]; then
  for argument in "$@"; do
    if [[ "$argument" == --https=* ]]; then port="${argument#--https=}"; fi
  done
  if [[ ! -f "$SERVE_STATE-$port" ]]; then
    printf 'handler does not exist\n' >&2
    exit 1
  fi
  rm -f "$SERVE_STATE-$port"
fi

printf 'tailscale %s\n' "$*" >>"$COMMAND_LOG"
SCRIPT

cat >"$fake_bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >>"$COMMAND_LOG"
if [[ "${CURL_MODE:-success}" == "fail" ]]; then
  exit 7
fi
printf 'unknown'
SCRIPT

cat >"$fake_bin/convex-helper" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'convex-helper %s\n' "$*" >>"$COMMAND_LOG"
SCRIPT

cat >"$fake_bin/bun" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-e" ]]; then
  exec "$REAL_BUN" "$@"
fi

if [[ "$*" == *'backend/test/latest-event.ts'* ]]; then
  if [[ ! -f "$EVENT_STATE" ]]; then
    touch "$EVENT_STATE"
    printf 'old-event\ttest\n'
  else
    printf 'new-event\tios\n'
  fi
  exit 0
fi

exec "$REAL_BUN" "$@"
SCRIPT

cat >"$fake_bin/defaults" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'ABCDE12345\n'
SCRIPT

cat >"$fake_bin/PlistBuddy" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'dev.starter.app\n'
SCRIPT

cat >"$fake_bin/xcodebuild" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'xcodebuild %s\n' "$*" >>"$COMMAND_LOG"

derived_data=''
while (($#)); do
  if [[ "$1" == "-derivedDataPath" ]]; then
    derived_data="$2"
    break
  fi
  shift
done

mkdir -p "$derived_data/Build/Products/Debug-iphoneos/Starter.app"
SCRIPT

cat >"$fake_bin/xcrun" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "devicectl" && "${2:-}" == "list" && "${3:-}" == "devices" ]]; then
  output=''
  while (($#)); do
    if [[ "$1" == "--json-output" ]]; then
      output="$2"
      break
    fi
    shift
  done
  if [[ "${XCDEVICE_MODE:-one}" == "multiple" ]]; then
    printf '%s\n' '{"result":{"devices":[{"identifier":"CORE-1","deviceProperties":{"name":"First iPhone"},"hardwareProperties":{"reality":"physical","platform":"iOS","udid":"PHONE-1"}},{"identifier":"CORE-2","deviceProperties":{"name":"Second iPhone"},"hardwareProperties":{"reality":"physical","platform":"iOS","udid":"PHONE-2"}}]}}' >"$output"
  else
    printf '%s\n' '{"result":{"devices":[{"identifier":"CORE-1","deviceProperties":{"name":"Developer iPhone"},"hardwareProperties":{"reality":"physical","platform":"iOS","udid":"PHONE-1"}}]}}' >"$output"
  fi
  exit 0
fi

if [[ "$*" == *'device process launch'* && "${DEVICE_LAUNCH_MODE:-success}" == "locked" ]]; then
  printf 'FBSOpenApplicationErrorDomain error 7: reason: Locked\n' >&2
  exit 1
fi

printf 'xcrun %s\n' "$*" >>"$COMMAND_LOG"
SCRIPT

chmod +x "$fake_bin"/*
export REAL_BUN="$real_bun"
export EVENT_STATE="$temporary_directory/event-state"

assert_contains() {
  local path="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$path"; then
    printf 'expected %s to contain: %s\n' "$path" "$expected" >&2
    sed -n '1,200p' "$path" >&2
    exit 1
  fi
}

device_url="$({
PATH="$fake_bin:$PATH" \
    COMMAND_LOG="$command_log" \
    DEVME_SLOT=2 \
    "$root/tooling/tailscale-convex.sh" url
})"

if [[ "$device_url" != "https://macbook.example.ts.net:8483" ]]; then
  printf 'unexpected device URL: %s\n' "$device_url" >&2
  exit 1
fi

  PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  CONVEX_HELPER_BIN="$fake_bin/convex-helper" \
  SERVE_STATE="$temporary_directory/serve-state" \
  "$root/tooling/tailscale-convex.sh" ensure >/dev/null
PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  CONVEX_HELPER_BIN="$fake_bin/convex-helper" \
  SERVE_STATE="$temporary_directory/serve-state" \
  "$root/tooling/tailscale-convex.sh" stop >/dev/null
PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  CONVEX_HELPER_BIN="$fake_bin/convex-helper" \
  SERVE_STATE="$temporary_directory/serve-state" \
  "$root/tooling/tailscale-convex.sh" stop >"$temporary_directory/already-stopped.out"
assert_contains "$temporary_directory/already-stopped.out" 'status: already-stopped'
assert_contains "$command_log" 'tailscale serve --yes --bg --https=8443 http://127.0.0.1:3210'
assert_contains "$command_log" 'tailscale serve --yes --bg --https=8444 http://127.0.0.1:3211'
assert_contains "$command_log" 'convex-helper auth-host https://macbook.example.ts.net:8444'

printf 'http://127.0.0.1:9999\n' >"$temporary_directory/serve-state-8443"
mismatch_output="$temporary_directory/mismatch.out"
if PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  CONVEX_HELPER_BIN="$fake_bin/convex-helper" \
  SERVE_STATE="$temporary_directory/serve-state" \
  "$root/tooling/tailscale-convex.sh" stop >"$mismatch_output"; then
  printf 'mismatched Tailscale target stop unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$mismatch_output" 'owned by another target'

url_failure_output="$temporary_directory/url-failure.out"
if PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  TAILSCALE_SELF_ONLINE=false \
  "$root/tooling/tailscale-convex.sh" url >"$url_failure_output"; then
  printf 'offline Mac URL lookup unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$url_failure_output" 'Tailscale did not report an online MagicDNS name'
if grep -Fq 'https://error:' "$url_failure_output"; then
  printf 'offline Mac error was embedded into a URL\n' >&2
  exit 1
fi

health_failure_output="$temporary_directory/health-failure.out"
rm -f "$temporary_directory/serve-state-8443" "$temporary_directory/serve-state-8444"
if PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  SERVE_STATE="$temporary_directory/serve-state" \
  CURL_MODE=fail \
  TAILSCALE_HEALTH_TIMEOUT_SECONDS=0 \
  "$root/tooling/tailscale-convex.sh" ensure >"$health_failure_output" 2>/dev/null; then
  printf 'unhealthy Tailscale endpoint unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$health_failure_output" 'did not become healthy'

offline_output="$temporary_directory/offline.out"
if PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  TAILSCALE_PEER_ONLINE=false \
  "$root/tooling/tailscale-convex.sh" require-ios-peer >"$offline_output"; then
  printf 'offline iOS peer check unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$offline_output" 'Open Tailscale on the iPhone'

PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  PLIST_BUDDY_BIN="$fake_bin/PlistBuddy" \
  DEVME_SLOT=2 \
  "$root/tooling/ios-device.sh" launch >"$temporary_directory/launch.out"

assert_contains "$command_log" 'CONVEX_URL=https://macbook.example.ts.net:8483'
assert_contains "$command_log" 'AUTH_SITE_URL=https://macbook.example.ts.net:8484'
assert_contains "$command_log" 'DEVELOPMENT_TEAM=ABCDE12345'
assert_contains "$command_log" 'platform=iOS,id=PHONE-1'
assert_contains "$command_log" 'device install app --device PHONE-1'
assert_contains "$command_log" 'device process launch --device PHONE-1 --terminate-existing dev.starter.app'
assert_contains "$temporary_directory/launch.out" 'status: launched'

: >"$command_log"
PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  PLIST_BUDDY_BIN="$fake_bin/PlistBuddy" \
  XCDEVICE_MODE=multiple \
  IOS_DEVICE_UDID=PHONE-2 \
  IOS_DEVELOPMENT_TEAM=TEAM-OVERRIDE \
  "$root/tooling/ios-device.sh" launch >/dev/null
assert_contains "$command_log" 'platform=iOS,id=PHONE-2'
assert_contains "$command_log" 'DEVELOPMENT_TEAM=TEAM-OVERRIDE'

rm -f "$EVENT_STATE"
PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  PLIST_BUDDY_BIN="$fake_bin/PlistBuddy" \
  "$root/tooling/ios-device.sh" e2e >"$temporary_directory/e2e.out" 2>/dev/null
assert_contains "$temporary_directory/e2e.out" 'status: passed'
assert_contains "$command_log" 'xcodebuild test'
assert_contains "$command_log" 'xcresulttool export attachments'

locked_output="$temporary_directory/locked.out"
if PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  PLIST_BUDDY_BIN="$fake_bin/PlistBuddy" \
  DEVICE_LAUNCH_MODE=locked \
  "$root/tooling/ios-device.sh" launch >"$locked_output" 2>/dev/null; then
  printf 'locked physical device launch unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$locked_output" 'Unlock the iPhone'

multiple_output="$temporary_directory/multiple.out"
if PATH="$fake_bin:$PATH" \
  COMMAND_LOG="$command_log" \
  PLIST_BUDDY_BIN="$fake_bin/PlistBuddy" \
  XCDEVICE_MODE=multiple \
  "$root/tooling/ios-device.sh" launch >"$multiple_output"; then
  printf 'ambiguous physical-device selection unexpectedly passed\n' >&2
  exit 1
fi
assert_contains "$multiple_output" 'IOS_DEVICE_UDID'
