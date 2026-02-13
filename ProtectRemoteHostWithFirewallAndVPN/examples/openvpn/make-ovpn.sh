#!/usr/bin/env bash
set -euo pipefail

CLIENT="${1:-}"
if [[ -z "$CLIENT" ]]; then
  echo "Usage: $0 <client_name>" >&2
  exit 1
fi

# Where your Easy-RSA CA lives (non-root user home)
CA_DIR="${CA_DIR:-$HOME/openvpn-ca}"
PKI_DIR="$CA_DIR/pki"

# Canonical server-side copies used by the running OpenVPN instance
OVPN_DIR="/etc/openvpn/server"
SERVER_CONF="$OVPN_DIR/server.conf"
CA_CRT="$OVPN_DIR/ca.crt"

# Client cert/key (created under your non-root Easy-RSA workspace)
CLIENT_CRT="$PKI_DIR/issued/${CLIENT}.crt"
CLIENT_KEY="$PKI_DIR/private/${CLIENT}.key"

OUT_DIR="$HOME/client-configs"
OUT_FILE="$OUT_DIR/${CLIENT}.ovpn"

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

# Sanity checks
[[ -s "$CLIENT_CRT" ]] || { echo "Missing/empty client cert: $CLIENT_CRT" >&2; exit 1; }
[[ -s "$CLIENT_KEY" ]] || { echo "Missing/empty client key:  $CLIENT_KEY" >&2; exit 1; }
sudo test -s "$CA_CRT" || { echo "Missing/empty CA cert:     $CA_CRT" >&2; exit 1; }
sudo test -s "$SERVER_CONF" || { echo "Missing server conf:       $SERVER_CONF" >&2; exit 1; }

# Detect public IP for convenience (best-effort)
PUBIP="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' || true)"
: "${PUBIP:=YOUR_SERVER_IP}"

# Detect whether server uses tls-crypt or tls-auth and which key file
TLS_MODE=""     # "crypt" or "auth"
TLS_KEY_PATH="" # full path

# Parse only non-comment lines
if sudo grep -Eq '^[[:space:]]*tls-crypt[[:space:]]+' "$SERVER_CONF"; then
  TLS_MODE="crypt"
  keyfile="$(sudo awk '($1=="tls-crypt"){print $2; exit}' "$SERVER_CONF")"
elif sudo grep -Eq '^[[:space:]]*tls-auth[[:space:]]+' "$SERVER_CONF"; then
  TLS_MODE="auth"
  keyfile="$(sudo awk '($1=="tls-auth"){print $2; exit}' "$SERVER_CONF")"
fi

if [[ -n "${TLS_MODE}" ]]; then
  # If keyfile is relative, it’s relative to /etc/openvpn/server in your layout
  if [[ "$keyfile" = /* ]]; then
    TLS_KEY_PATH="$keyfile"
  else
    TLS_KEY_PATH="$OVPN_DIR/$keyfile"
  fi
  sudo test -s "$TLS_KEY_PATH" || { echo "Missing/empty TLS key: $TLS_KEY_PATH" >&2; exit 1; }
fi

# Write the profile
cat > "$OUT_FILE" <<CONFIG
client
dev tun
proto udp
remote ${PUBIP} 1194
resolv-retry infinite
nobind

persist-key
persist-tun

remote-cert-tls server
cipher AES-256-GCM
auth SHA256
auth-nocache
verb 3

<ca>
$(sudo cat "$CA_CRT")
</ca>

<cert>
$(awk 'BEGIN{p=0} /BEGIN CERTIFICATE/{p=1} p{print} /END CERTIFICATE/{p=0}' "$CLIENT_CRT")
</cert>

<key>
$(cat "$CLIENT_KEY")
</key>
CONFIG

# Append tls-crypt or tls-auth section if server uses it
if [[ "$TLS_MODE" == "crypt" ]]; then
  {
    echo ""
    echo "<tls-crypt>"
    sudo cat "$TLS_KEY_PATH"
    echo "</tls-crypt>"
  } >> "$OUT_FILE"
elif [[ "$TLS_MODE" == "auth" ]]; then
  {
    echo ""
    echo "key-direction 1"
    echo "<tls-auth>"
    sudo cat "$TLS_KEY_PATH"
    echo "</tls-auth>"
  } >> "$OUT_FILE"
fi

chmod 600 "$OUT_FILE"

echo "Wrote: $OUT_FILE"
if [[ -n "$TLS_MODE" ]]; then
  echo "TLS mode: tls-$TLS_MODE"
  echo "TLS key:  $TLS_KEY_PATH"
  echo "TLS hash: $(sudo sha256sum "$TLS_KEY_PATH" | awk '{print $1}')"
  echo "TLS bytes: $(sudo stat -c '%s' "$TLS_KEY_PATH")"
else
  echo "TLS mode: (none detected in $SERVER_CONF)"
fi
