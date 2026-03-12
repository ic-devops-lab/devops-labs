#!/usr/bin/env bash
set -euo pipefail

: "${GITLAB_PRIVATE_URL:?Must set GITLAB_PRIVATE_URL}"
: "${GITLAB_RUNNER_REG_TOKEN:?Must set GITLAB_RUNNER_REG_TOKEN}"
: "${RUNNER_NAME:?Must set RUNNER_NAME}"
: "${RUNNER_TAGS:?Must set RUNNER_TAGS}"
: "${RUNNER_EXECUTOR:?Must set RUNNER_EXECUTOR}"

echo "[register] Registering runner against: ${GITLAB_PRIVATE_URL}"
echo "[register] Runner name: ${RUNNER_NAME}"
echo "[register] Runner tags: ${RUNNER_TAGS}"
echo "[register] Executor: ${RUNNER_EXECUTOR}"

gitlab-runner register \
  --non-interactive \
  --url "${GITLAB_PRIVATE_URL}" \
  --registration-token "${GITLAB_RUNNER_REG_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --tag-list "${RUNNER_TAGS}" \
  --executor "${RUNNER_EXECUTOR}" \
  --docker-image "alpine:3.20" \
  --locked="false" \
  --access-level="not_protected" \
  --run-untagged="false"

CONFIG_FILE="/etc/gitlab-runner/config.toml"

if [ -f "${CONFIG_FILE}" ]; then
  echo "[register] Setting clone_url to internal GitLab URL: ${GITLAB_PRIVATE_URL}"

  if grep -q '^[[:space:]]*clone_url[[:space:]]*=' "${CONFIG_FILE}"; then
    sed -i "s|^[[:space:]]*clone_url[[:space:]]*=.*|  clone_url = \\\"${GITLAB_PRIVATE_URL}\\\"|" "${CONFIG_FILE}"
  else
    sed -i "/^[[:space:]]*url[[:space:]]*=/a\\  clone_url = \\\"${GITLAB_PRIVATE_URL}\\\"" "${CONFIG_FILE}"
  fi
else
  echo "[register] ERROR: ${CONFIG_FILE} not found after registration."
  exit 1
fi

echo "[register] Restarting gitlab-runner..."
systemctl restart gitlab-runner

echo "[register] Registration complete."
echo "[register] Current runners:"
gitlab-runner list || true

echo "[register] Effective clone_url setting:"
grep -n 'clone_url' "${CONFIG_FILE}" || true
