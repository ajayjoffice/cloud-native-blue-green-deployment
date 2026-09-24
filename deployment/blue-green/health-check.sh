#!/usr/bin/env bash
set -euo pipefail

URL="${1:?Usage: health-check.sh BASE_URL EXPECTED_VERSION}"
EXPECTED_VERSION="${2:?Usage: health-check.sh BASE_URL EXPECTED_VERSION}"

health="$(curl --fail --silent --show-error --max-time 5 "${URL%/}/health")"
version="$(curl --fail --silent --show-error --max-time 5 "${URL%/}/version")"
printf '%s' "$health" | grep -F '"status":"ok"' >/dev/null || {
  echo "Health endpoint did not report status=ok: $health" >&2; exit 1;
}
printf '%s' "$version" | grep -F "\"version\":\"$EXPECTED_VERSION\"" >/dev/null || {
  echo "Expected version $EXPECTED_VERSION, received: $version" >&2; exit 1;
}
echo "Healthy: $URL serves $EXPECTED_VERSION"
