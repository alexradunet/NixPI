---
name: service-management
description: Install, manage, and discover OCI-packaged service containers
---

# Service Management

Bloom services are modular capabilities packaged as OCI artifacts. Each package contains Quadlet container units and a SKILL.md file.

## Registry

Service packages are hosted at:
```
ghcr.io/alexradunet/bloom-svc-{name}:latest
```

## Install a Service

```bash
mkdir -p /tmp/bloom-svc
oras pull ghcr.io/alexradunet/bloom-svc-{name}:latest -o /tmp/bloom-svc/
cp /tmp/bloom-svc/quadlet/*.container ~/.config/containers/systemd/
cp /tmp/bloom-svc/quadlet/*.volume ~/.config/containers/systemd/ 2>/dev/null
mkdir -p ~/Garden/Bloom/Skills/{name}
cp /tmp/bloom-svc/SKILL.md ~/Garden/Bloom/Skills/{name}/SKILL.md
systemctl --user daemon-reload
systemctl --user start bloom-{name}
rm -rf /tmp/bloom-svc
```

## Remove a Service

```bash
systemctl --user stop bloom-{name}
rm ~/.config/containers/systemd/bloom-{name}.*
rm -rf ~/Garden/Bloom/Skills/{name}
systemctl --user daemon-reload
```

## List Installed Services

```bash
ls ~/.config/containers/systemd/bloom-*.container
```

## Check Service Health

```bash
systemctl --user status bloom-{name}
```

## View Service Logs

```bash
journalctl --user -u bloom-{name} -n 50
```

## Browse Available Versions

```bash
oras repo tags ghcr.io/alexradunet/bloom-svc-{name}
```

## Known Services

| Name | Category | Description |
|------|----------|-------------|
| `whisper` | media | Speech-to-text transcription (faster-whisper, port 9000) |
| `whatsapp` | communication | WhatsApp messaging bridge via Baileys |
| `tailscale` | networking | Secure mesh VPN via Tailscale |
