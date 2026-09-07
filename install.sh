#!/bin/bash
# discord-bypass-turkey-arch installer
#
# Sets up a DPI-bypass path for Discord on Arch Linux (or any systemd +
# nftables distro), scoped ONLY to Discord's traffic via a dedicated Linux
# group - nothing else on the system is touched or slowed down.
#
# What this does:
#   1. Fixes Discord's domains in /etc/hosts (Turk Telekom DNS-hijacks them
#      to a sinkhole IP over plain DNS; this resolves them via DoH instead).
#   2. Installs ciadpi (ByeDPI) as a systemd service acting as a transparent
#      DPI-evasion proxy, using a technique set validated against Turk
#      Telekom's DPI (TLS record splitting, TCP disorder, auto-fallback).
#   3. Creates a "discordnet" Linux group and an nftables rule that silently
#      redirects ONLY that group's HTTPS traffic into the proxy above.
#   4. Overrides Discord's .desktop launcher to run it under that group via
#      newgrp (not sudo -g, which would strip GPU/audio group access).
#
# Requires: systemd, nftables, an Arch-style Discord install at /usr/bin/discord.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR=/opt/discord-bypass
CIADPI_VERSION="0.17.3"
CIADPI_URL="https://github.com/hufrea/byedpi/releases/download/v${CIADPI_VERSION}/byedpi-${CIADPI_VERSION#0.}-x86_64.tar.gz"

if [ "$EUID" -eq 0 ]; then
  echo "Run this as your normal user (it will ask for sudo when needed), not as root." >&2
  exit 1
fi

command -v nft >/dev/null || { echo "nftables not found. Install it first."; exit 1; }
command -v systemctl >/dev/null || { echo "systemd not found."; exit 1; }
[ -x /usr/bin/discord ] || echo "Warning: /usr/bin/discord not found - the launcher override will still be installed, but check the path is correct for your system."

echo "==> Downloading ciadpi (ByeDPI) ${CIADPI_VERSION}..."
tmp=$(mktemp -d)
curl -sSL -o "$tmp/ciadpi.tar.gz" "$CIADPI_URL"
tar xzf "$tmp/ciadpi.tar.gz" -C "$tmp"
sudo mkdir -p "$INSTALL_DIR"
sudo install -m 0755 "$tmp/ciadpi-x86_64" "$INSTALL_DIR/ciadpi-x86_64"
rm -rf "$tmp"

echo "==> Creating discordnet group..."
sudo groupadd -f discordnet
sudo usermod -aG discordnet "$USER"

echo "==> Fixing Discord's DNS entries (bypassing ISP DNS hijack)..."
sudo bash "$SCRIPT_DIR/scripts/update-hosts.sh"

echo "==> Installing ciadpi systemd service..."
sudo install -m 0644 "$SCRIPT_DIR/systemd/ciadpi.service" /etc/systemd/system/ciadpi.service

echo "==> Installing nftables redirect for the discordnet group..."
sudo install -m 0644 "$SCRIPT_DIR/systemd/discordredirect.nft" /etc/discordredirect.nft
sudo install -m 0644 "$SCRIPT_DIR/systemd/discordredirect-nft.service" /etc/systemd/system/discordredirect-nft.service

sudo systemctl daemon-reload
sudo systemctl enable --now ciadpi
sudo systemctl enable --now discordredirect-nft

echo "==> Installing Discord launcher wrapper..."
mkdir -p "$HOME/.local/bin"
install -m 0755 "$SCRIPT_DIR/scripts/discord-launcher" "$HOME/.local/bin/discord-launcher"

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/discord.desktop" << EOF
[Desktop Entry]
Name=Discord
StartupWMClass=discord
Comment=All-in-one voice and text chat for gamers that's free, secure, and works on both your desktop and phone.
GenericName=Internet Messenger
Exec=$HOME/.local/bin/discord-launcher %u
Icon=discord
Type=Application
Categories=Network;InstantMessaging;
MimeType=x-scheme-handler/discord;
Path=/usr/bin
EOF

echo ""
echo "==================================================================="
echo " Done. IMPORTANT: log out and back in once (group membership for"
echo " 'discordnet' only takes effect in a fresh login session), then"
echo " launch Discord normally from your app menu."
echo ""
echo " If Discord's DNS entries ever go stale, re-run:"
echo "   sudo scripts/update-hosts.sh"
echo "==================================================================="
