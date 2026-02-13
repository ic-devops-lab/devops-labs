#!/usr/bin/env bash
set -euo pipefail

# --- SSH restrictions: ONLY from VPN + Home IP ---
VPN_SUBNET="10.8.0.0/24"
HOME_IP="203.0.113.10/32"   # <-- change this

LOG="/var/log/firewalld-start.log"
exec >>"$LOG" 2>&1
echo "=== $(date -Is) Applying firewalld policy ==="

# Detect public interface (interface used for default route)
PUBLIC_IF="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}' || true)"
if [[ -z "${PUBLIC_IF}" ]]; then
  echo "[!] Could not auto-detect public interface. Set PUBLIC_IF manually in script."
  exit 1
fi
echo "[*] Public interface detected: ${PUBLIC_IF}"

# Ensure firewalld running
systemctl enable --now firewalld

# Use a clean, predictable zone as default
firewall-cmd --set-default-zone=public

# Bind the public interface to public zone (idempotent)
firewall-cmd --permanent --zone=public --add-interface="${PUBLIC_IF}" || true

# Tighten: no "trusted" shortcuts
# (public zone default target is usually DROP/REJECT depending on distro; we rely on explicit allows)

# Remove common services/ports that might exist by default/have been added previously (ignore errors)
for svc in cockpit dhcpv6-client samba nfs rpc-bind; do
  firewall-cmd --permanent --zone=public --remove-service="$svc" 2>/dev/null || true
done

# Remove previously-added ports we care about, then re-add (keeps policy stable)
for p in 22 80 443 3389; do
  firewall-cmd --permanent --zone=public --remove-port="${p}/tcp" 2>/dev/null || true
done
# ssh as service (more readable). uncomment to allow acces from anywhere
# firewall-cmd --permanent --zone=public --add-service=ssh
# http/https as services
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
# xRDP. uncomment to allow access from anywhere
# firewall-cmd --permanent --zone=public --add-port=3389/tcp
# OpenVPN
sudo firewall-cmd --permanent --zone=public --add-port=1194/udp

# Ensure SSH/RDP are not globally exposed. comment out when allowed
firewall-cmd --permanent --zone=public --remove-service=ssh 2>/dev/null || true
firewall-cmd --permanent --zone=public --remove-port=22/tcp 2>/dev/null || true
firewall-cmd --permanent --zone=public --remove-port=3389/tcp 2>/dev/null || true

# Remove old/duplicate rich rules if you re-run (best-effort cleanup)
firewall-cmd --permanent --zone=public --remove-rich-rule="rule family='ipv4' source address='${VPN_SUBNET}' service name='ssh' accept" 2>/dev/null || true
firewall-cmd --permanent --zone=public --remove-rich-rule="rule family='ipv4' source address='${HOME_IP}' service name='ssh' accept" 2>/dev/null || true
# firewall-cmd --permanent --zone=public --remove-rich-rule="rule family='ipv4' source address='${VPN_SUBNET}' service name='rdp' accept" 2>/dev/null || true
# firewall-cmd --permanent --zone=public --remove-rich-rule="rule family='ipv4' source address='${HOME_IP}' service name='rdp' accept" 2>/dev/null || true
firewall-cmd --permanent --zone=public --remove-rich-rule="rule family='ipv4' source address='${VPN_SUBNET}' port protocol='tcp' port='3389' accept" 2>/dev/null || true
firewall-cmd --permanent --zone=public --remove-rich-rule="rule family='ipv4' source address='${HOME_IP}' port protocol='tcp' port='3389' accept" 2>/dev/null || true

# Add allow rules for SSH/RDP
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='${VPN_SUBNET}' service name='ssh' accept"
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='${HOME_IP}' service name='ssh' accept"
# firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='${VPN_SUBNET}' service name='rdp' accept" 2>/dev/null || true
# firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='${HOME_IP}' service name='rdp' accept" 2>/dev/null || true
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='${VPN_SUBNET}' port protocol='tcp' port='3389' accept" 2>/dev/null || true
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='${HOME_IP}' port protocol='tcp' port='3389' accept" 2>/dev/null || true

# Safety net: explicitly reject common DB ports on both IPv4+IPv6
# (Even if Docker publishes them accidentally)
DB_PORTS=(5432 3306 6379 27017 9200 9300)
for port in "${DB_PORTS[@]}"; do
  firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='${port}' protocol='tcp' reject" || true
  firewall-cmd --permanent --add-rich-rule="rule family='ipv6' port port='${port}' protocol='tcp' reject" || true
done

# Reload to apply permanent config to runtime
firewall-cmd --reload

echo "[✓] Done. Current public zone:"
firewall-cmd --zone=public --list-all