#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/firewalld-init.log"
exec >>"$LOG" 2>&1
echo "=== $(date -Is) Applying firewalld policy ==="

# Detect public interface (interface used for default route)
PUBLIC_IF="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}' || true)"
if [[ -z "${PUBLIC_IF}" ]]; then
  echo "[!] Could not auto-detect public interface. Set PUBLIC_IF manually in script."
  exit 1
fi
echo "[*] Public interface detected: ${PUBLIC_IF}"

systemctl enable --now firewalld

# Deterministic baseline
firewall-cmd --set-default-zone=public
firewall-cmd --permanent --zone=public --add-interface="${PUBLIC_IF}" || true

# Explicit deny-by-default stance
firewall-cmd --permanent --zone=public --set-target=DROP

# Remove common services that may exist by default
for svc in cockpit dhcpv6-client samba nfs rpc-bind; do
  firewall-cmd --permanent --zone=public --remove-service="$svc" 2>/dev/null || true
done

# Remove managed ports first (idempotency)
for p in 22 80 443 3389; do
  firewall-cmd --permanent --zone=public --remove-port="${p}/tcp" 2>/dev/null || true
done

# Phase 1: SSH remains publicly accessible
firewall-cmd --permanent --zone=public --add-service=ssh

# Reverse-proxy entry points
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https

# Optional: xRDP
firewall-cmd --permanent --zone=public --add-port=3389/tcp

# Safety net: explicitly reject common database ports
DB_PORTS=(5432 3306 6379 27017 9200 9300)
for port in "${DB_PORTS[@]}"; do
  firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='${port}' protocol='tcp' reject" || true
  firewall-cmd --permanent --add-rich-rule="rule family='ipv6' port port='${port}' protocol='tcp' reject" || true
done

firewall-cmd --reload

echo "[✓] Done. Current public zone:"
firewall-cmd --zone=public --list-all