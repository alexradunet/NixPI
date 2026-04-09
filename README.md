# NixPI

NixPI is a VPS-first, headless AI companion OS built on NixOS.

It combines:
- a plain OVH-compatible NixOS base system
- a host-owned `/etc/nixos` system root
- a shared `nixpi-bootstrap-host` integration path for already-installed NixOS systems
- a Zellij-first operator runtime for SSH and local tty sessions

By default, interactive operator sessions enter **Zellij** on both SSH and local tty logins. The default layout opens a Pi tab and a plain shell tab. For recovery or troubleshooting, skip auto-start with `NIXPI_NO_ZELLIJ=1` before starting a login shell.

## Quick start

Install a plain base system onto a fresh OVH VPS from rescue mode:

```bash
nix run .#nixpi-deploy-ovh -- \
  --target-host root@SERVER_IP \
  --disk /dev/sdX
```

After the machine boots, reconnect to the installed host and bootstrap NixPI on the machine:

```bash
nix run github:alexradunet/nixpi#nixpi-bootstrap-host -- \
  --primary-user alex \
  --hostname bloom-eu-1 \
  --timezone Europe/Bucharest \
  --keyboard us
```

Validate the running host:

```bash
systemctl status sshd.service
systemctl status netbird-wt0.service
systemctl status nixpi-app-setup.service
netbird-wt0 status
```

Steady-state host model:

- `/etc/nixos` is the running host's source of truth
- `sudo nixpi-rebuild` rebuilds the installed `/etc/nixos#nixos` host flake
- NixPI is layered onto the host-owned system configuration rather than replacing the machine root

Rollback if needed:

```bash
sudo nixos-rebuild switch --rollback
```

## Docs

- Documentation site: https://alexradunet.github.io/NixPI
- Install guide: https://alexradunet.github.io/NixPI/install
- Operations: https://alexradunet.github.io/NixPI/operations/
- Architecture: https://alexradunet.github.io/NixPI/architecture/
- Reference: https://alexradunet.github.io/NixPI/reference/
- Internal notes (non-public): `internal/`

Run docs locally:

```bash
npm run docs:dev
```
