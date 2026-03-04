#!/usr/bin/env bash
set -euo pipefail

# Jubei-Samurai WireGuard server setup script
# Target: Debian/Ubuntu-like systems
#
# This script:
# - Installs WireGuard
# - Enables IP forwarding
# - Sets up basic NAT
# - Creates /etc/wireguard/wg0.conf from wg0.conf.template
#
# Run as root: sudo bash setup.sh

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WG_DIR="/etc/wireguard"
WG_IFACE="wg0"
WG_CONF="${WG_DIR}/${WG_IFACE}.conf"

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root, e.g.: sudo bash setup.sh"
  exit 1
fi

echo "=== Jubei-Samurai WireGuard server setup ==="

apt_update_if_needed() {
  if ! command -v wg >/dev/null 2>&1; then
    echo "[*] Updating apt package index..."
    apt-get update -y
  fi
}

install_wireguard() {
  if command -v wg >/dev/null 2>&1; then
    echo "[*] WireGuard already installed."
    return
  fi

  echo "[*] Installing WireGuard packages..."
  apt_update_if_needed
  apt-get install -y wireguard wireguard-tools
}

enable_ip_forwarding() {
  echo "[*] Enabling IPv4 forwarding..."
  sysctl -w net.ipv4.ip_forward=1 >/dev/null

  if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  fi
}

setup_nat() {
  # Use iptables for basic NAT. This assumes your external interface is the default route.
  # You may need to adjust EXT_IF for your setup (e.g. eth0, ens3, etc.).
  EXT_IF="${EXT_IF:-$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1); exit}')}"

  if [[ -z "${EXT_IF}" ]]; then
    echo "[!] Could not detect external interface automatically. Set EXT_IF and re-run."
    return
  fi

  echo "[*] Setting up basic NAT on ${EXT_IF}..."

  iptables -t nat -C POSTROUTING -o "${EXT_IF}" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o "${EXT_IF}" -j MASQUERADE

  iptables -C FORWARD -i "${WG_IFACE}" -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i "${WG_IFACE}" -j ACCEPT
  iptables -C FORWARD -o "${WG_IFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -o "${WG_IFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT

  # Note: For persistence across reboots, consider using iptables-persistent or nftables rules.
}

generate_keys() {
  echo "[*] Generating server keypair..."
  mkdir -p "${WG_DIR}"
  chmod 700 "${WG_DIR}"

  umask 077
  wg genkey | tee "${WG_DIR}/server-private.key" | wg pubkey > "${WG_DIR}/server-public.key"
}

create_config_from_template() {
  if [[ ! -f "${TEMPLATE_DIR}/wg0.conf.template" ]]; then
    echo "[!] Template ${TEMPLATE_DIR}/wg0.conf.template not found."
    exit 1
  fi

  echo "[*] Creating ${WG_CONF} from template..."

  read -rp "Enter VPN interface address (e.g. 10.8.0.1/24): " VPN_ADDR
  read -rp "Enter UDP listen port (e.g. 51820): " VPN_PORT

  SERVER_PRIVATE_KEY="$(cat "${WG_DIR}/server-private.key")"

  sed \
    -e "s|{{SERVER_PRIVATE_KEY}}|${SERVER_PRIVATE_KEY}|g" \
    -e "s|{{SERVER_ADDRESS}}|${VPN_ADDR}|g" \
    -e "s|{{SERVER_PORT}}|${VPN_PORT}|g" \
    "${TEMPLATE_DIR}/wg0.conf.template" > "${WG_CONF}"

  chmod 600 "${WG_CONF}"
}

install_wireguard
enable_ip_forwarding
setup_nat

if [[ ! -f "${WG_DIR}/server-private.key" || ! -f "${WG_DIR}/server-public.key" ]]; then
  generate_keys
else
  echo "[*] Existing server keys detected; reusing."
fi

if [[ -f "${WG_CONF}" ]]; then
  echo "[*] ${WG_CONF} already exists. Skipping creation."
else
  create_config_from_template
fi

echo "[*] Enabling and starting wg-quick@${WG_IFACE}..."
systemctl enable "wg-quick@${WG_IFACE}" >/dev/null 2>&1 || true
systemctl restart "wg-quick@${WG_IFACE}"

echo ""
echo "=== Jubei-Samurai setup complete ==="
echo "Server public key:"
cat "${WG_DIR}/server-public.key"
echo ""
echo "You can now:"
echo "  - Add [Peer] entries to ${WG_CONF} for each client."
echo "  - Use the generated server public key in your client configs."

