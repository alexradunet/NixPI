---
name: bridge-management
description: Install, configure, and manage messaging bridges that connect Bloom to external platforms
---

# Bridge Management Skill

Use this skill when the user wants to set up, configure, or troubleshoot messaging bridges (e.g. WhatsApp).

## Bridge Architecture

Bridges are OCI service packages deployed as Podman Quadlet containers. Each bridge:
- Runs as a systemd-managed container
- Connects to Pi via localhost TCP (bloom-channels on port 18800)
- Has its own auth state and configuration
- Is installed via `oras pull` from GHCR

## WhatsApp Bridge (Baileys)

The WhatsApp bridge uses Baileys (lightweight, no browser needed):
- Container: `bloom-whatsapp`
- Auth: QR code pairing on first run
- Connection: TCP to bloom-channels extension
- Resource usage: ~50MB RAM (vs 500MB+ with Puppeteer-based alternatives)

## Installation

Install via the service package:

```bash
mkdir -p /tmp/bloom-svc
oras pull ghcr.io/alexradunet/bloom-svc-whatsapp:latest -o /tmp/bloom-svc/
cp /tmp/bloom-svc/quadlet/* ~/.config/containers/systemd/
mkdir -p ~/Garden/Bloom/Skills/whatsapp
cp /tmp/bloom-svc/SKILL.md ~/Garden/Bloom/Skills/whatsapp/SKILL.md
systemctl --user daemon-reload
systemctl --user start bloom-whatsapp
rm -rf /tmp/bloom-svc
```

Then check logs for the QR code:
```bash
journalctl --user -u bloom-whatsapp -f
```

Scan the QR code with WhatsApp mobile, then verify:
```bash
systemctl --user status bloom-whatsapp
```

## Media Message Handling

The WhatsApp bridge downloads incoming media (audio, image, video, documents) to `/var/lib/bloom/media/`. Media metadata is forwarded to Pi via the channel protocol with the file path, MIME type, size, and duration.

Pi can then use installed services to process media — for example, using the Whisper service to transcribe audio messages.

## Troubleshooting

- Bridge won't start: `journalctl --user -u bloom-whatsapp -n 100`
- Connection lost: `systemctl --user restart bloom-whatsapp`
- Auth expired: Remove auth volume, restart, re-scan QR code:
  ```bash
  systemctl --user stop bloom-whatsapp
  podman volume rm bloom-whatsapp-auth
  systemctl --user start bloom-whatsapp
  ```
