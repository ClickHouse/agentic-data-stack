#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"

read_env_var() {
    local key="$1"
    grep -E "^${key}=" "$ENV_FILE" | head -n1 | cut -d= -f2-
}

compose() {
    (cd "$PROJECT_DIR" && docker compose "$@")
}

if ! command -v docker >/dev/null 2>&1 || ! compose version >/dev/null 2>&1; then
    echo "  ℹ Docker Compose is unavailable; settings will apply the next time the stack starts."
    exit 0
fi

librechat_container=$(compose ps --status running -q librechat 2>/dev/null || true)
if [ -z "$librechat_container" ]; then
    echo "  ℹ LibreChat is not running; settings will apply the next time the stack starts."
    exit 0
fi

desired_hash=$(compose config --hash librechat 2>/dev/null | awk '$1 == "librechat" { print $2 }')
running_hash=$(docker inspect "$librechat_container" --format '{{ index .Config.Labels "com.docker.compose.config-hash" }}' 2>/dev/null || true)

if [ -z "$desired_hash" ] || [ "$desired_hash" != "$running_hash" ]; then
    echo "  ↻ LibreChat is running with stale configuration; recreating it now..."
    compose up -d --force-recreate --no-deps --wait --wait-timeout 300 librechat
else
    echo "  ✓ Running LibreChat configuration is already current."
fi

for key in LANGFUSE_BASE_URL LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY; do
    expected=$(read_env_var "$key")
    actual=$(compose exec -T librechat printenv "$key" | tr -d '\r')
    if [ "$actual" != "$expected" ]; then
        echo "  ❌ Running LibreChat has an unexpected ${key}." >&2
        echo "     Re-run: docker compose up -d --force-recreate --no-deps librechat" >&2
        exit 1
    fi
done

echo "  ✓ Running LibreChat target verified: $(read_env_var LANGFUSE_BASE_URL)"
