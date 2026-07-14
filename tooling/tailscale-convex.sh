#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"

readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="$(devme_convex_port "$slot")"
readonly site_port="$(devme_convex_site_port "$slot")"
readonly https_port="$(devme_tailscale_https_port "$slot")"
readonly site_https_port="$(devme_tailscale_auth_https_port "$slot")"
readonly tailscale_bin="${TAILSCALE_BIN:-tailscale}"
readonly curl_bin="${CURL_BIN:-curl}"
readonly bun_bin="${BUN_BIN:-bun}"
stop_endpoint_status='already-stopped'

fail() {
  local message="$1"
  local help="$2"
  printf 'error: "%s"\n' "$message"
  printf 'help[1]: "%s"\n' "$help"
  exit 1
}

tailscale_status() {
  "$tailscale_bin" status --json 2>/dev/null ||
    fail \
      'Tailscale is not connected on this Mac.' \
      'Open Tailscale on the Mac, connect it, then retry the Devme task.'
}

tailscale_dns_name() {
  tailscale_status | "$bun_bin" -e '
    const status = await Bun.stdin.json();
    const name = status.Self?.DNSName?.replace(/\.$/, "");
    if (!status.Self?.Online || !name) process.exit(1);
    console.log(name);
  ' || fail \
    'Tailscale did not report an online MagicDNS name for this Mac.' \
    'Reconnect Tailscale on the Mac, then retry the Devme task.'
}

device_url() {
  local port="$1"
  local dns_name
  if ! dns_name="$(tailscale_dns_name)"; then
    printf '%s\n' "$dns_name"
    return 1
  fi
  printf 'https://%s:%s\n' "$dns_name" "$port"
}

require_ios_peer() {
  if ! tailscale_status | "$bun_bin" -e '
    const status = await Bun.stdin.json();
    const peers = Object.values(status.Peer ?? {});
    if (!peers.some((peer) => peer.OS === "iOS" && peer.Online)) process.exit(1);
  '; then
    fail \
      'No online iOS device was found in this tailnet.' \
      'Open Tailscale on the iPhone, connect it to the same tailnet, then retry.'
  fi
}

serve_state() {
  local port="$1"
  local status
  if ! status="$("$tailscale_bin" serve status --json 2>/dev/null)"; then
    fail \
      'Tailscale Serve configuration could not be inspected.' \
      'Reconnect Tailscale on the Mac, then retry the Devme task.'
  fi
  printf '%s\n' "$status" | HTTPS_PORT="$port" "$bun_bin" -e '
    const status = await Bun.stdin.json();
    const port = process.env.HTTPS_PORT;
    const configured = status.TCP?.[port]?.HTTPS === true;
    const web = Object.entries(status.Web ?? {})
      .find(([authority]) => authority.endsWith(`:${port}`))?.[1];
    const target = web?.Handlers?.["/"]?.Proxy ?? "";
    console.log(`${configured}\t${target}`);
  '
}

wait_until_healthy() {
  local url="$1"
  local path="$2"
  local timeout="${TAILSCALE_HEALTH_TIMEOUT_SECONDS:-60}"
  local deadline="$((SECONDS + timeout))"

  while ! "$curl_bin" \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "$url$path" >/dev/null 2>&1; do
    if ((SECONDS >= deadline)); then
      fail \
        "The tailnet endpoint at $url$path did not become healthy." \
        'Inspect Tailscale Serve and Convex health, then retry device-backend.'
    fi
    sleep 2
  done
}

ensure_endpoint() {
  local port="$1"
  local target="$2"
  local health_path="$3"
  local state configured existing_target serve_output url

  state="$(serve_state "$port")"
  IFS=$'\t' read -r configured existing_target <<<"$state"
  if [[ "$configured" == 'true' && "$existing_target" != "$target" ]]; then
    fail \
      "Tailscale HTTPS port $port is owned by another target: ${existing_target:-unknown}." \
      'Choose a free Devme slot or remove the conflicting Tailscale Serve handler, then retry.'
  fi
  if ! serve_output="$("$tailscale_bin" serve --yes --bg --https="$port" "$target" 2>&1)"; then
    printf '%s\n' "$serve_output" >&2
    fail \
      "Tailscale Serve could not configure HTTPS port $port." \
      'Inspect the diagnostics above, reconnect Tailscale, then retry device-backend.'
  fi
  url="$(device_url "$port")"
  wait_until_healthy "$url" "$health_path"
}

stop_endpoint() {
  local port="$1"
  local target="$2"
  local state configured existing_target stop_output

  state="$(serve_state "$port")"
  IFS=$'\t' read -r configured existing_target <<<"$state"
  if [[ "$configured" == 'true' && "$existing_target" != "$target" ]]; then
    fail \
      "Tailscale HTTPS port $port is owned by another target: ${existing_target:-unknown}." \
      'Do not remove it from this worktree; select the worktree that owns the handler.'
  fi
  if [[ "$configured" == 'true' ]]; then
    if ! stop_output="$("$tailscale_bin" serve --yes --https="$port" off 2>&1)"; then
      printf '%s\n' "$stop_output" >&2
      fail \
        "Tailscale Serve could not remove HTTPS port $port." \
        'Reconnect Tailscale on the Mac, then retry device-backend-stop.'
    fi
    stop_endpoint_status='stopped'
  else
    stop_endpoint_status='already-stopped'
  fi
}

case "${1:-}" in
  ensure)
    ensure_endpoint "$https_port" "http://127.0.0.1:$convex_port" /version
    ensure_endpoint "$site_https_port" "http://127.0.0.1:$site_port" /api/auth/get-session
    printf 'result:\n'
    printf '  status: ready\n'
    printf '  backend_url: "%s"\n' "$(device_url "$https_port")"
    printf '  auth_site_url: "%s"\n' "$(device_url "$site_https_port")"
    printf '  visibility: tailnet-only\n'
    ;;
  health)
    wait_until_healthy "$(device_url "$https_port")" /version
    wait_until_healthy "$(device_url "$site_https_port")" /api/auth/get-session
    ;;
  require-ios-peer)
    require_ios_peer
    ;;
  stop)
    stop_endpoint "$https_port" "http://127.0.0.1:$convex_port"
    api_status="$stop_endpoint_status"
    stop_endpoint "$site_https_port" "http://127.0.0.1:$site_port"
    site_status="$stop_endpoint_status"
    status='already-stopped'
    if [[ "$api_status" == 'stopped' || "$site_status" == 'stopped' ]]; then
      status='stopped'
    fi
    printf 'result:\n'
    printf '  status: %s\n' "$status"
    printf '  https_ports: [%s, %s]\n' "$https_port" "$site_https_port"
    ;;
  url)
    device_url "$https_port"
    ;;
  site-url)
    device_url "$site_https_port"
    ;;
  *)
    printf 'error: "Expected one of: ensure, health, require-ios-peer, stop, url, site-url."\n'
    printf 'help[1]: "Run this helper through a Devme task instead of invoking it directly."\n'
    exit 2
    ;;
esac
