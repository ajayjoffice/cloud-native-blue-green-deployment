#!/usr/bin/env bash
set -euo pipefail

COLOR="${1:?Usage: switch.sh blue|green}"
case "$COLOR" in blue) TARGET=blue;; green) TARGET=green;; *) echo "Color must be blue or green" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF="$ROOT/deployment/nginx/active-upstream.conf"
printf 'upstream active_app {\n    server %s:8000;\n}\n' "$TARGET" > "$CONF"
docker compose -f "$ROOT/docker-compose.yml" exec -T nginx nginx -t
docker compose -f "$ROOT/docker-compose.yml" exec -T nginx nginx -s reload
echo "Nginx now routes traffic to $TARGET"
