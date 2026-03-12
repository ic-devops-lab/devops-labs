#!/usr/bin/env bash
set -euo pipefail

HELPER_SCRIPTS_DIR="/opt/provision/runner"

echo "[runner] Updating apt..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

echo "[runner] Installing prerequisites..."
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common jq

echo "[runner] Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
ARCH="$(dpkg --print-architecture)"
echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "[runner] Installing GitLab Runner..."
curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash
apt-get install -y gitlab-runner
systemctl enable --now gitlab-runner

echo "[runner] Adding gitlab-runner user to docker group..."
usermod -aG docker gitlab-runner || true

chmod +x "${HELPER_SCRIPTS_DIR}"/*.sh

if [ -f /etc/gitlab-runner/config.toml ] && grep -q '^[[:space:]]*token[[:space:]]*=' /etc/gitlab-runner/config.toml; then
  echo "[runner] Existing runner configuration detected. Skipping registration."
  exit 0
fi

if [ -n "${GITLAB_API_TOKEN:-}" ] && [ -n "${GITLAB_RUNNER_DESCRIPTION:-}" ] && [ -n "${GITLAB_PRIVATE_URL:-}" ]; then
  echo "[runner] Attempting stale offline runner cleanup..."
  GITLAB_PRIVATE_URL="${GITLAB_PRIVATE_URL}" \
  GITLAB_API_TOKEN="${GITLAB_API_TOKEN}" \
  GITLAB_RUNNER_DESCRIPTION="${GITLAB_RUNNER_DESCRIPTION}" \
  "${HELPER_SCRIPTS_DIR}"/cleanup-stale-runners.sh || true
else
  echo "[runner] Stale runner cleanup skipped."
fi

if [ -n "${GITLAB_RUNNER_REG_TOKEN:-}" ]; then
  echo "[runner] Registration token provided, registering runner..."
  GITLAB_PRIVATE_URL="${GITLAB_PRIVATE_URL:?Must set GITLAB_PRIVATE_URL}" \
  GITLAB_RUNNER_REG_TOKEN="${GITLAB_RUNNER_REG_TOKEN}" \
  RUNNER_NAME="${RUNNER_NAME:-102-instance-default-001}" \
  RUNNER_TAGS="${RUNNER_TAGS:-private,docker,default,vm102}" \
  RUNNER_EXECUTOR="${RUNNER_EXECUTOR:-docker}" \
  "${HELPER_SCRIPTS_DIR}"/register-runner.sh
else
  echo "[runner] No GITLAB_RUNNER_REG_TOKEN set; skipping registration."
  echo "[runner] To register later, export the required env vars and run:"
  echo "         sudo ${HELPER_SCRIPTS_DIR}/register-runner.sh"
fi

echo "[runner] Done."
