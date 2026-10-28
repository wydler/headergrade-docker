#!/usr/bin/env sh
set -eu

IMAGE="${1:-headergrade-docker:test}"
NAME="headergrade-smoke-$$"
TMP_DIR="$(mktemp -d)"
HOST_PORT=""

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP_DIR/data"
# The official node image's unprivileged user is UID/GID 1000.
if [ "$(id -u)" -eq 0 ]; then
  chown 1000:1000 "$TMP_DIR/data"
elif command -v sudo >/dev/null 2>&1 && sudo -n chown 1000:1000 "$TMP_DIR/data"; then
  :
else
  echo "ERROR: cannot set test data directory ownership to UID/GID 1000." >&2
  echo "Run the smoke test with permission to chown the temporary data directory." >&2
  exit 1
fi

docker run -d \
  --name "$NAME" \
  --read-only \
  --tmpfs /tmp:size=16m,noexec,nosuid,nodev \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  --pids-limit 128 \
  -p 127.0.0.1::3000 \
  -v "$TMP_DIR/data:/app/data" \
  "$IMAGE" >/dev/null

HOST_PORT="$(docker port "$NAME" 3000/tcp | sed 's/.*://')"
if [ -z "$HOST_PORT" ]; then
  echo "ERROR: Docker did not publish a host port." >&2
  exit 1
fi

i=0
until [ "$i" -ge 30 ]; do
  status="$(docker inspect --format '{{.State.Health.Status}}' "$NAME" 2>/dev/null || true)"
  if [ "$status" = "healthy" ]; then
    break
  fi
  i=$((i + 1))
  sleep 2
done

if [ "${status:-}" != "healthy" ]; then
  docker logs "$NAME" >&2 || true
  echo "ERROR: container did not become healthy (status: ${status:-unknown})." >&2
  exit 1
fi

uid="$(docker exec "$NAME" id -u)"
if [ "$uid" = "0" ]; then
  echo "ERROR: application is running as root." >&2
  exit 1
fi

response="$(curl --fail --silent --show-error "http://127.0.0.1:${HOST_PORT}/api/stats")"
printf '%s' "$response" | grep -q . || {
  echo "ERROR: /api/stats returned an empty response." >&2
  exit 1
}

echo "PASS: container is healthy, non-root, and /api/stats responds."
