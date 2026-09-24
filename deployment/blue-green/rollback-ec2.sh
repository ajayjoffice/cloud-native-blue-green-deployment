#!/usr/bin/env bash
set -euo pipefail
CONF="${NGINX_UPSTREAM_CONF:-/etc/nginx/conf.d/active-upstream.conf}"
PORT="$(sed -n 's/.*127\.0\.0\.1:\([0-9]*\).*/\1/p' "$CONF" | head -1)"
case "$PORT" in 8001) PREVIOUS=8002;; 8002) PREVIOUS=8001;; *) echo "Cannot determine active port" >&2; exit 1;; esac
TMP="$(mktemp)"
printf 'upstream active_app {\n    server 127.0.0.1:%s;\n}\n' "$PREVIOUS" > "$TMP"
sudo install -m 0644 "$TMP" "$CONF"
rm -f "$TMP"
sudo nginx -t && sudo nginx -s reload
echo "Traffic rolled back to port $PREVIOUS"
