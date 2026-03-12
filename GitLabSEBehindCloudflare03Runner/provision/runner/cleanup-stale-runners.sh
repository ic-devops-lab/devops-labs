#!/usr/bin/env bash
set -euo pipefail

: "${GITLAB_PRIVATE_URL:?Must set GITLAB_PRIVATE_URL}"
: "${GITLAB_API_TOKEN:?Must set GITLAB_API_TOKEN}"
: "${GITLAB_RUNNER_DESCRIPTION:?Must set GITLAB_RUNNER_DESCRIPTION}"

API_BASE="${GITLAB_PRIVATE_URL%/}/api/v4"
AUTH_HEADER="PRIVATE-TOKEN: ${GITLAB_API_TOKEN}"

echo "[cleanup] Looking for offline runners with description: ${GITLAB_RUNNER_DESCRIPTION}"

runner_ids="$(
  curl -fsS --header "${AUTH_HEADER}" "${API_BASE}/runners/all?per_page=100" |
    jq -r --arg desc "${GITLAB_RUNNER_DESCRIPTION}" '.[] | select(.description == $desc and .status == "offline") | .id'
)"

if [ -z "${runner_ids}" ]; then
  echo "[cleanup] No offline runners found for cleanup."
  exit 0
fi

while IFS= read -r runner_id; do
  [ -n "${runner_id}" ] || continue
  echo "[cleanup] Deleting offline runner id=${runner_id}"
  curl -fsS -X DELETE --header "${AUTH_HEADER}" "${API_BASE}/runners/${runner_id}" >/dev/null
done <<< "${runner_ids}"

echo "[cleanup] Cleanup complete."
