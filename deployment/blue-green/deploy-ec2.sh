#!/usr/bin/env bash
# Run on EC2 after Docker login; Nginx is installed on the host.
set -euo pipefail
IMAGE="${1:?Usage: deploy-ec2.sh IMAGE EXPECTED_VERSION [blue|green]}"
VERSION="${2:?Usage: deploy-ec2.sh IMAGE EXPECTED_VERSION [blue|green]}"
CONF="${NGINX_UPSTREAM_CONF:-/etc/nginx/conf.d/active-upstream.conf}"
CURRENT="$(sed -n 's/.*127\.0\.0\.1:\([0-9]*\).*/\1/p' "$CONF" | head -1)"
if [[ -n "${3:-}" ]]; then TARGET="$3"; elif [[ "$CURRENT" == 8001 ]]; then TARGET=green; else TARGET=blue; fi
case "$TARGET" in blue) PORT=8001;; green) PORT=8002;; *) echo "Target must be blue or green" >&2; exit 2;; esac
NAME="blue-green-$TARGET"
if [[ "${PULL_IMAGE:-true}" == "true" ]]; then
  docker pull "$IMAGE"
fi
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --restart unless-stopped -p "127.0.0.1:$PORT:8000" -e "APP_VERSION=$VERSION" "$IMAGE"
"$(dirname "${BASH_SOURCE[0]}")/health-check.sh" "http://127.0.0.1:$PORT" "$VERSION"

TMP="$(mktemp)"
BACKUP="$(mktemp)"
cp "$CONF" "$BACKUP"
printf 'upstream active_app {\n    server 127.0.0.1:%s;\n}\n' "$PORT" > "$TMP"
sudo install -m 0644 "$TMP" "$CONF"
if ! sudo nginx -t || ! sudo nginx -s reload; then
  sudo install -m 0644 "$BACKUP" "$CONF"
  sudo nginx -t && sudo nginx -s reload || true
  rm -f "$TMP" "$BACKUP"
  echo "Nginx switch failed; previous config restored" >&2
  exit 1
fi
rm -f "$TMP" "$BACKUP"
echo "Deployment complete: $TARGET ($VERSION) on port $PORT"
