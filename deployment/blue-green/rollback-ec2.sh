#!/usr/bin/env bash
set -euo pipefail
CONF="${NGINX_UPSTREAM_CONF:-/etc/nginx/conf.d/active-upstream.conf}"
PORT="$(sed -n 's/.*127\.0\.0\.1:\([0-9]*\).*/\1/p' "$CONF" | head -1)"
case "$PORT" in 8001) PREVIOUS=8002;; 8002) PREVIOUS=8001;; *) echo "Cannot determine active port" >&2; exit 1;; esac
TARGET_URL="http://127.0.0.1:$PREVIOUS"
TARGET_VERSION="$(curl --fail --silent --show-error --max-time 5 "$TARGET_URL/version" | python3 -c 'import json, sys; print(json.load(sys.stdin)["version"])')"
bash "$(dirname "${BASH_SOURCE[0]}")/health-check.sh" "$TARGET_URL" "$TARGET_VERSION"

TMP="$(mktemp)"
BACKUP="$(mktemp)"
cp "$CONF" "$BACKUP"
printf 'upstream active_app {\n    server 127.0.0.1:%s;\n}\n' "$PREVIOUS" > "$TMP"
sudo install -m 0644 "$TMP" "$CONF"
if ! sudo nginx -t || ! sudo nginx -s reload; then
  sudo install -m 0644 "$BACKUP" "$CONF"
  sudo nginx -t && sudo nginx -s reload || true
  rm -f "$TMP" "$BACKUP"
  echo "Nginx rollback failed; previous config restored" >&2
  exit 1
fi
rm -f "$TMP" "$BACKUP"
echo "Traffic rolled back to $TARGET_VERSION on port $PREVIOUS"
