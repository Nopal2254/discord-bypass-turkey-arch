#!/bin/bash
# Refreshes the Discord /etc/hosts entries using DNS-over-HTTPS, bypassing
# Turk Telekom's DNS hijack (which returns a bogus sinkhole IP for these
# domains over plain DNS). Safe to re-run any time; only touches the
# marked block below.
set -euo pipefail

DOMAINS=(
  discord.com
  discord.gg
  discordapp.com
  gateway.discord.gg
  updates.discord.com
  cdn.discordapp.com
  media.discordapp.net
  discord.media
)

BEGIN_MARK="# >>> discord-bypass-turkey-arch (managed) >>>"
END_MARK="# <<< discord-bypass-turkey-arch (managed) <<<"

tmp=$(mktemp)
echo "$BEGIN_MARK" >> "$tmp"
for d in "${DOMAINS[@]}"; do
  ip=$(curl -sS --max-time 5 -H "accept: application/dns-json" \
    "https://cloudflare-dns.com/dns-query?name=$d&type=A" \
    | grep -oE '"data":"[0-9.]+"' | head -1 | grep -oE '[0-9.]+')
  if [ -z "$ip" ]; then
    echo "warning: could not resolve $d via DoH, skipping" >&2
    continue
  fi
  echo "$ip $d" >> "$tmp"
  echo "$d -> $ip"
done
echo "$END_MARK" >> "$tmp"

if [ "$EUID" -ne 0 ]; then
  echo "Run this with sudo to write /etc/hosts." >&2
  rm -f "$tmp"
  exit 1
fi

sed -i "/$BEGIN_MARK/,/$END_MARK/d" /etc/hosts
cat "$tmp" >> /etc/hosts
rm -f "$tmp"
echo "Updated /etc/hosts."
