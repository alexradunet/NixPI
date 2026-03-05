# Bloom Service Packages

Bloom services are modular capabilities packaged as OCI artifacts and deployed via Podman Quadlet.

## Package Format

Each service package is a directory containing:

```
services/{name}/
├── quadlet/
│   ├── bloom-{name}.container    # Podman Quadlet container unit
│   └── bloom-{name}-*.volume     # Optional volume definitions
└── SKILL.md                      # Pi skill file (frontmatter + docs)
```

## OCI Artifact Distribution

Service packages are pushed to GHCR as OCI artifacts using `oras`:

```
ghcr.io/alexradunet/bloom-svc-{name}:latest
```

### Pushing

```bash
just svc-push {name}
```

### Pulling & Installing

```bash
just svc-install {name}
```

Or manually:
```bash
mkdir -p /tmp/bloom-svc
oras pull ghcr.io/alexradunet/bloom-svc-{name}:latest -o /tmp/bloom-svc/
cp /tmp/bloom-svc/quadlet/* ~/.config/containers/systemd/
mkdir -p ~/Garden/Bloom/Skills/{name}
cp /tmp/bloom-svc/SKILL.md ~/Garden/Bloom/Skills/{name}/SKILL.md
systemctl --user daemon-reload
systemctl --user start bloom-{name}
rm -rf /tmp/bloom-svc
```

## OCI Annotations

Each artifact carries standard annotations:

| Annotation | Description |
|------------|-------------|
| `org.opencontainers.image.title` | `bloom-{name}` |
| `org.opencontainers.image.description` | Human-readable description |
| `org.opencontainers.image.source` | `https://github.com/alexradunet/bloom` |
| `org.opencontainers.image.version` | Semver version |
| `dev.bloom.service.category` | `media`, `communication`, `networking`, `sync`, or `utility` |
| `dev.bloom.service.port` | Exposed port (if any) |

## Quadlet Conventions

- Container name: `bloom-{name}`
- Network: `host` (services communicate via localhost)
- Health checks: required (`HealthCmd`, `HealthInterval`, `HealthRetries`)
- Logging: `LogDriver=journald`
- Security: `NoNewPrivileges=true` minimum
- Restart: `on-failure` with `RestartSec=10`

## Available Services

| Service | Category | Port | Description |
|---------|----------|------|-------------|
| `whisper` | media | 9000 | Speech-to-text transcription via faster-whisper |
| `whatsapp` | communication | — | WhatsApp messaging bridge via Baileys |
| `tailscale` | networking | — | Secure mesh VPN via Tailscale |
