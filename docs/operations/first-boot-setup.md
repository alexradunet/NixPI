# First Boot Setup

> Validating a fresh NixPI host after a plain base install

## Audience

Operators bringing up a fresh NixPI headless VPS.

## Prerequisites

Before this checklist, you should already have:

1. a completed plain-base install such as `nixpi-deploy-ovh`
2. SSH or console access to the installed machine
3. the intended primary user, hostname, timezone, and keyboard values for bootstrap

## What First Boot Means Now

NixPI comes up as a shell-first host runtime with Zellij as the default interactive terminal UI.

A fresh system should provide:

- a plain base system that boots normally before NixPI is layered on
- a bootstrap path that writes narrow `/etc/nixos` helper files
- an installed `/etc/nixos` flake that remains authoritative for host convergence
- a rebuild path that stays anchored to `/etc/nixos#nixos`
- a Pi runtime that becomes available after bootstrap completes

## First-Boot Checklist

### 1. Bootstrap NixPI on the machine

The first post-install action is to run `nixpi-bootstrap-host` on the machine.

```bash
nix run github:alexradunet/nixpi#nixpi-bootstrap-host -- \
  --primary-user alex \
  --hostname bloom-eu-1 \
  --timezone Europe/Bucharest \
  --keyboard us
```

If `/etc/nixos/flake.nix` already exists, follow the printed manual integration guidance and rebuild the host explicitly:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos --impure
```

### 2. Verify the base services

```bash
systemctl status nixpi-app-setup.service
systemctl status sshd.service
systemctl status netbird-wt0.service
systemctl status nixpi-update.timer
```

Expected result: all four services are active or activatable.

### 3. Verify the runtime entry path

From SSH:

```bash
command -v pi
pi --help
ls -la ~/.pi
```

Expected result:

- the `pi` command is installed
- Pi is usable without any browser-only service layer
- user-home marker files are not the primary control plane for the host mode

After the first successful login, the default operator-facing interface is Zellij. The generated layout opens Pi and a shell tab. If you need a plain shell for recovery, use `NIXPI_NO_ZELLIJ=1` before starting the login shell.

### 4. Verify NetBird bootstrap before normal use

```bash
systemctl status netbird-wt0.service
netbird-wt0 status
```

Expected result:

- `netbird-wt0.service` is active
- the host has enrolled into the managed NetBird network
- `netbird-wt0 status` reports the local peer and connection state

### 5. Verify the rebuild path

Steady-state rebuilds should use the installed host flake:

```bash
sudo nixpi-rebuild
```

Manual recovery or existing-flake integration also rebuilds through the same host-owned root:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos --impure
```

Expected result:

- `sudo nixpi-rebuild` rebuilds from the installed host flake
- manual host rebuilds still target `/etc/nixos#nixos`
- the deployed system stays independent from any boot-time repo seeding

## Operator Orientation

After first boot, keep these boundaries in mind:

- the deployed NixOS config owns bootstrap and steady-state behavior
- the installed `/etc/nixos` flake remains authoritative for the running host
- NixPI is layered into the host through generated helper files, not by replacing the machine root
- user-home marker files are not the control path for transitioning host state
- SSH sessions are the operator control plane, with Zellij as the default interactive UI
- shell behavior should already match the deployed NixOS configuration
- system services remain inspectable with normal NixOS and systemd tooling

## Reference

### Relevant Services

| Service | Purpose |
|------|---------|
| `nixpi-app-setup.service` | Provides the Pi runtime entry path |
| `sshd.service` | Remote shell access |
| `netbird-wt0.service` | NetBird client for the private admin network |

### Current Behavior Target

- the machine boots to a normal headless multi-user target
- no desktop session is required to start operating NixPI
- the primary user workflow is Pi in the terminal, reached from SSH via Zellij by default
- updates run through native NixOS/systemd paths, and `sudo nixpi-rebuild` targets the installed host flake
