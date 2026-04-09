---
title: Install NixPI
description: Install NixPI onto a fresh OVH VPS by provisioning a plain base system first, then bootstrapping on-host.
---

# Install NixPI

## Supported target

- headless x86_64 VPS
- provider rescue-mode access
- SSH or console access to the installed machine
- outbound internet access during installation and bootstrap

## Canonical install path

NixPI supports one host-owned install story:

1. install a plain NixOS base for the machine
2. reconnect to the installed machine
3. run `nixpi-bootstrap-host` on the machine
4. rebuild only through `/etc/nixos#nixos`

Use the dedicated [OVH Rescue Deploy](./operations/ovh-rescue-deploy) runbook for the base install.

`nixos-anywhere` is used only for plain base-system provisioning. It does not install the final NixPI host directly.

Bootstrap writes narrow `/etc/nixos` helper files. On a classic `/etc/nixos` tree it can generate a minimal host flake automatically; on an existing flake host it prints the exact manual integration steps instead.

## Bootstrap NixPI on the machine

Run this on the installed host after the plain base system boots:

```bash
nix run github:alexradunet/nixpi#nixpi-bootstrap-host -- \
  --primary-user alex \
  --hostname bloom-eu-1 \
  --timezone Europe/Bucharest \
  --keyboard us
```

If `/etc/nixos/flake.nix` already exists, follow the printed instructions and rebuild manually:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos --impure
```

## After bootstrap

Validate the installed host:

```bash
systemctl status nixpi-app-setup.service
systemctl status sshd.service
systemctl status netbird-wt0.service
systemctl status nixpi-update.timer
netbird-wt0 status
```

Routine rebuilds should use the installed `/etc/nixos#nixos` host flake:

```bash
sudo nixpi-rebuild
```

The installed `/etc/nixos` flake remains the source of truth for the running host.

Rollback if needed:

```bash
sudo nixos-rebuild switch --rollback
```

## Next steps

- [Operations](./operations/)
- [OVH Rescue Deploy](./operations/ovh-rescue-deploy)
- [First Boot Setup](./operations/first-boot-setup)
- [Reference](./reference/)
