# discord-bypass-turkey-arch

Get Discord working on Arch Linux (or any systemd + nftables distro) when your ISP blocks it — specifically written for **Türk Telekom**, but the same technique may work for other DPI-based ISP blocks.

Only Discord's own traffic is affected. Nothing else on your system is touched, slowed down, or routed anywhere different.

## The problem

Türk Telekom (and likely other Turkish ISPs) blocks Discord two ways at once:

1. **DNS hijacking** — plain DNS queries for `discord.com` and related domains return a bogus sinkhole IP instead of Discord's real servers.
2. **DPI-based TCP resets** — even if you connect directly to Discord's real IP, the moment your TLS `ClientHello` reveals `discord.com` in the SNI field, the connection gets reset. This DPI does full TCP stream reassembly, so simple packet-splitting tricks (the kind [zapret](https://github.com/bol-van/zapret) uses) mostly don't fool it — TTL tricks, packet reordering, and decoy packets were all found ineffective during testing on this specific block.

What *does* work: a small independent tool called [ByeDPI](https://github.com/hufrea/byedpi) (`ciadpi`), using a technique combo (`--tlsrec`, TLS record splitting) that this ISP's DPI apparently doesn't handle — discovered via [SplitWire-Turkey](https://github.com/cagritaskn/SplitWire-Turkey), a Windows-only tool built for this exact problem. This repo ports that same technique to a clean, Linux-native, systemd-based setup.

## How it works

```
Discord (launched under "discordnet" group)
        │
        ▼
nftables (redirects only discordnet-group HTTPS traffic)
        │
        ▼
ciadpi transparent proxy :1085  (applies TLS record splitting + auto-fallback)
        │
        ▼
Discord's real servers (via /etc/hosts fix, bypassing the DNS hijack)
```

- A dedicated `discordnet` Linux group scopes the whole thing — only processes running under it get redirected.
- `ciadpi` runs as a systemd service in transparent-proxy mode, so no app-level proxy configuration is needed.
- Discord's `.desktop` launcher is overridden to run it via `newgrp discordnet` (not `sudo -g`, which would strip your GPU/audio group access and break video/voice).

## Requirements

- Arch Linux (or similar) with `systemd` and `nftables` as the active firewall backend
- Discord installed via the official Arch package (`/usr/bin/discord`)
- `curl`

## Install

```bash
git clone https://github.com/<your-username>/discord-bypass-turkey-arch.git
cd discord-bypass-turkey-arch
chmod +x install.sh scripts/*.sh scripts/discord-launcher
./install.sh
```

Then **log out and back in once** (group membership only takes effect in a fresh login session), and launch Discord normally from your app menu.

## If it stops working

Discord's DNS entries are pinned to specific Cloudflare IPs looked up at install time. If Discord's infrastructure changes IPs, refresh them:

```bash
sudo ./scripts/update-hosts.sh
```

If the DPI technique itself stops working (ISPs do update their blocking over time), check `ciadpi`'s options at [hufrea/byedpi](https://github.com/hufrea/byedpi) and edit the `ExecStart` line in `/etc/systemd/system/ciadpi.service`, then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ciadpi
```

## Uninstall

```bash
./uninstall.sh
```

## Credits

- [hufrea/byedpi](https://github.com/hufrea/byedpi) — the actual DPI-bypass engine this relies on
- [cagritaskn/SplitWire-Turkey](https://github.com/cagritaskn/SplitWire-Turkey) — where the working parameter combo for Türk Telekom was found (Windows-only tool; this repo is a Linux-native port of just its ByeDPI method)

## Disclaimer

This is a personal-use tool for accessing a legal service (Discord) that's being blocked/throttled by an ISP. It doesn't do anything to Discord's servers or anyone else's traffic — it only changes how your own machine reaches them.
