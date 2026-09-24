#!/usr/bin/env bash
# Rebuilds and starts the inactive Compose service, verifies it, then switches Nginx.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="${1:?Usage: deploy.sh VERSION [blue|green]}"
CURRENT="$(sed -n 's/.*server \(blue\|green\):8000;.*/\1/p' "$ROOT/deployment/nginx/active-upstream.conf")"
if [[ -n "${2:-}" ]]; then TARGET="$2"; elif [[ "$CURRENT" == blue ]]; then TARGET=green; else TARGET=blue; fi
case "$TARGET" in blue|green) ;; *) echo "Target must be blue or green" >&2; exit 2;; esac

cd "$ROOT"
docker compose build "$TARGET"
BLUE_VERSION="$VERSION" GREEN_VERSION="$VERSION" docker compose up -d --no-deps --force-recreate "$TARGET"
PORT="$(docker compose port "$TARGET" 8000 | awk -F: '{print $NF}')"
"$ROOT/deployment/blue-green/health-check.sh" "http://127.0.0.1:$PORT" "$VERSION"
"$ROOT/deployment/blue-green/switch.sh" "$TARGET"
echo "Deployment complete: $TARGET ($VERSION)"
