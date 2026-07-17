#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temporary_directory="$(mktemp -d)"
readonly docker_log="$temporary_directory/docker.log"
readonly docker_pid_file="$temporary_directory/docker.pid"
readonly fake_bin="$temporary_directory/bin"
mkdir -p "$fake_bin"

grep -Fq \
  'stop = "DEVME_SLOT={slot} CONVEX_PORT={port} ../tooling/convex.sh down"' \
  "$root/backend/devme.toml"

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

cat >"$fake_bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$COMPOSE_PROJECT_NAME" "$*" >>"$DOCKER_LOG"
if [[ " $* " == *" up "* ]]; then
  if [[ "${FAKE_DOCKER_UP_MODE:-wait}" == "fail" ]]; then
    exit 42
  fi
  printf '%s\n' "$$" >"$DOCKER_PID_FILE"
  trap 'exit 0' INT TERM
  while true; do sleep 1; done
fi
EOF
chmod +x "$fake_bin/docker"

DOCKER_LOG="$docker_log" \
DOCKER_PID_FILE="$docker_pid_file" \
PATH="$fake_bin:$PATH" \
DEVME_SLOT=99 \
CONVEX_INSTANCE_SECRET="$(printf 'a%.0s' {1..64})" \
  "$root/tooling/convex.sh" up &
service_pid=$!

for _ in {1..50}; do
  if grep -q 'compose.* up .*--remove-orphans' "$docker_log" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
grep -q 'compose.* up .*--remove-orphans' "$docker_log"
grep -Eq '^starter-[[:xdigit:]]{8}-99 compose.* up .*--remove-orphans' "$docker_log"

kill -TERM "$service_pid"
kill -TERM "$(cat "$docker_pid_file")"
set +e
wait "$service_pid"
service_status=$?
set -e
if [[ "$service_status" -ne 0 && "$service_status" -ne 143 ]]; then
  printf 'Convex service exited with unexpected status %s.\n' "$service_status" >&2
  exit 1
fi

if grep -q 'compose.* down' "$docker_log"; then
  printf 'Convex service performed teardown outside Devme stop handling.\n' >&2
  exit 1
fi

DOCKER_LOG="$docker_log" \
DOCKER_PID_FILE="$docker_pid_file" \
PATH="$fake_bin:$PATH" \
DEVME_SLOT=99 \
CONVEX_INSTANCE_SECRET="$(printf 'a%.0s' {1..64})" \
  "$root/tooling/convex.sh" down
grep -q 'compose.* down .*--remove-orphans' "$docker_log"

immediate_exit_log="$temporary_directory/immediate-exit.log"
set +e
DOCKER_LOG="$docker_log" \
DOCKER_PID_FILE="$docker_pid_file" \
FAKE_DOCKER_UP_MODE=fail \
PATH="$fake_bin:$PATH" \
DEVME_SLOT=99 \
CONVEX_INSTANCE_SECRET="$(printf 'a%.0s' {1..64})" \
  "$root/tooling/convex.sh" up >"$immediate_exit_log" 2>&1
immediate_exit_status=$?
set -e
if [[ "$immediate_exit_status" -ne 42 ]]; then
  cat "$immediate_exit_log" >&2
  printf 'Convex service did not preserve the immediate Compose exit status: %s.\n' \
    "$immediate_exit_status" >&2
  exit 1
fi
printf 'Convex service lifecycle test passed.\n'
