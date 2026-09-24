#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF="$ROOT/deployment/nginx/active-upstream.conf"
if grep -Fq 'server blue:8000;' "$CONF"; then
  CURRENT=blue
elif grep -Fq 'server green:8000;' "$CONF"; then
  CURRENT=green
else
  CURRENT=unknown
fi
case "$CURRENT" in blue) PREVIOUS=green;; green) PREVIOUS=blue;; *) echo "Cannot determine active color from Nginx config" >&2; exit 1;; esac
"$ROOT/deployment/blue-green/switch.sh" "$PREVIOUS"
