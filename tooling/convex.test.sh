#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temporary_directory="$(mktemp -d)"
readonly docker_log="$temporary_directory/docker.log"
readonly fake_bin="$temporary_directory/bin"
mkdir -p "$fake_bin"

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

cat >"$fake_bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$DOCKER_LOG"
if [[ " $* " == *" up "* ]]; then
  trap 'exit 0' INT TERM
  while true; do sleep 1; done
fi
EOF
chmod +x "$fake_bin/docker"

DOCKER_LOG="$docker_log" \
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

kill -TERM "$service_pid"
set +e
wait "$service_pid"
service_status=$?
set -e
if [[ "$service_status" -ne 0 && "$service_status" -ne 143 ]]; then
  printf 'Convex service exited with unexpected status %s.\n' "$service_status" >&2
  exit 1
fi

grep -q 'compose.* down .*--remove-orphans .*--timeout 1' "$docker_log"
printf 'Convex service cleanup test passed.\n'
