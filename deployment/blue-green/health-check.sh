#!/usr/bin/env bash
set -euo pipefail

URL="${1:?Usage: health-check.sh BASE_URL EXPECTED_VERSION}"
EXPECTED_VERSION="${2:?Usage: health-check.sh BASE_URL EXPECTED_VERSION}"

for attempt in $(seq 1 15); do
  health="$(curl --fail --silent --max-time 5 "${URL%/}/health" 2>/dev/null || true)"
  version="$(curl --fail --silent --max-time 5 "${URL%/}/version" 2>/dev/null || true)"
  if printf '%s' "$health" | grep -F '"status":"ok"' >/dev/null \
    && printf '%s' "$version" | grep -F "\"version\":\"$EXPECTED_VERSION\"" >/dev/null; then
    echo "Healthy: $URL serves $EXPECTED_VERSION"
    exit 0
  fi
  sleep 1
done
echo "Expected a healthy $EXPECTED_VERSION response from $URL; last health response: ${health:-<no response>}; last version response: ${version:-<no response>}" >&2
exit 1
