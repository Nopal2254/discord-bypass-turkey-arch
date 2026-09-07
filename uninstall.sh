#!/bin/bash
# Reverts everything install.sh set up.
set -euo pipefail

echo "==> Stopping and disabling services..."
sudo systemctl disable --now discordredirect-nft 2>/dev/null || true
sudo systemctl disable --now ciadpi 2>/dev/null || true
sudo rm -f /etc/systemd/system/discordredirect-nft.service
sudo rm -f /etc/systemd/system/ciadpi.service
sudo rm -f /etc/discordredirect.nft
sudo systemctl daemon-reload

echo "==> Removing DNS hosts entries..."
sudo sed -i "/# >>> discord-bypass-turkey-arch (managed) >>>/,/# <<< discord-bypass-turkey-arch (managed) <<</d" /etc/hosts

echo "==> Removing ciadpi binary..."
sudo rm -rf /opt/discord-bypass

echo "==> Restoring default Discord launcher..."
rm -f "$HOME/.local/share/applications/discord.desktop"
rm -f "$HOME/.local/bin/discord-launcher"

echo ""
echo "Note: the 'discordnet' group was left in place (in case you're still"
echo "using it for something else). To remove it too:"
echo "  sudo gpasswd -d \$USER discordnet"
echo "  sudo groupdel discordnet"
