#!/usr/bin/env bash
set -euo pipefail

# ====== EDIT THIS ======
GITLAB_FQDN="${GITLAB_FQDN:-gitlab.yourdomain.com}"
GITLAB_PRIVATE_IP="${GITLAB_PRIVATE_IP:-192.168.56.10}"

# Private listener for runner traffic.
# This is the internal GitLab entrypoint used by the runner for:
# - registration
# - API calls
# - Git over HTTP checkout
GITLAB_INTERNAL_NGINX_PORT="8081"

# Keep Workhorse exposed for the existing reverse-proxy / tunnel topology.
GITLAB_WORKHORSE_PORT="8181"

# Optional: keep Puma reachable for troubleshooting only.
GITLAB_PUMA_PORT="8080"
# =======================

export DEBIAN_FRONTEND=noninteractive

echo "[*] Updating packages..."
apt-get update -y
apt-get install -y curl ca-certificates tzdata openssh-server perl gpg lsb-release ruby jq

echo "[*] Creating backups directory..."
mkdir -p /srv/gitlab-backups
chmod 700 /srv/gitlab-backups

echo "[*] Installing postfix (local only)..."
apt-get install -y postfix || true

if ! command -v gitlab-ctl >/dev/null 2>&1; then
  echo "[*] Adding GitLab package repository..."
  curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
fi

if ! dpkg -s gitlab-ce >/dev/null 2>&1; then
  echo "[*] Installing gitlab-ce..."
  apt-get install -y gitlab-ce
else
  echo "[*] gitlab-ce already installed, skipping package install."
fi

echo "[*] Configuring /etc/gitlab/gitlab.rb ..."
GITLAB_RB="/etc/gitlab/gitlab.rb"
test -f "$GITLAB_RB"

if grep -q "^external_url" "$GITLAB_RB"; then
  sed -i "s|^external_url .*|external_url \"https://${GITLAB_FQDN}\"|g" "$GITLAB_RB"
else
  echo "external_url \"https://${GITLAB_FQDN}\"" >> "$GITLAB_RB"
fi

echo "[*] Applying gitlab.rb settings..."

cat >/tmp/gitlab_rb_patch.rb <<'RUBY'
f, private_ip, nginx_port, workhorse_port, puma_port = ARGV
txt = File.read(f)

def set_kv(txt, key, value)
  re = /^#{Regexp.escape(key)}\s*=.*$/
  if txt.match?(re)
    txt.gsub(re, "#{key} = #{value}")
  else
    txt + "\n#{key} = #{value}\n"
  end
end

txt = set_kv(txt, "nginx['enable']", "true")
txt = set_kv(txt, "nginx['listen_addresses']", "['#{private_ip}']")
txt = set_kv(txt, "nginx['listen_port']", nginx_port)
txt = set_kv(txt, "nginx['listen_https']", "false")

txt = set_kv(txt, "puma['listen']", "'0.0.0.0'")
txt = set_kv(txt, "puma['port']", puma_port)

txt = set_kv(txt, "gitlab_workhorse['listen_network']", "\"tcp\"")
txt = set_kv(txt, "gitlab_workhorse['listen_addr']", "\"0.0.0.0:#{workhorse_port}\"")

txt = set_kv(txt, "gitlab_rails['backup_path']", "\"/srv/gitlab-backups\"")

File.write(f, txt)
RUBY

ruby /tmp/gitlab_rb_patch.rb "$GITLAB_RB" "$GITLAB_PRIVATE_IP" "$GITLAB_INTERNAL_NGINX_PORT" "$GITLAB_WORKHORSE_PORT" "$GITLAB_PUMA_PORT"
rm -f /tmp/gitlab_rb_patch.rb

echo "[*] Running gitlab-ctl reconfigure..."
gitlab-ctl reconfigure

echo "[*] Restarting GitLab services..."
gitlab-ctl restart

echo "[*] Validating listeners..."
ss -tulpn | grep -E ":${GITLAB_INTERNAL_NGINX_PORT}|:${GITLAB_WORKHORSE_PORT}|:${GITLAB_PUMA_PORT}" || true

echo "[*] Done."
echo "    External URL: https://${GITLAB_FQDN}"
echo "    Private runner URL: http://${GITLAB_PRIVATE_IP}:${GITLAB_INTERNAL_NGINX_PORT}"
echo "    Existing reverse-proxy / tunnel upstream can stay on: http://${GITLAB_PRIVATE_IP}:${GITLAB_WORKHORSE_PORT}"
echo "    Puma remains reachable on: http://${GITLAB_PRIVATE_IP}:${GITLAB_PUMA_PORT} (not for runner checkout)"

systemctl status --no-pager gitlab-runsvdir || true
