---
name: first-boot
description: Guide the user through one-time Bloom system setup on a fresh install
---

# First-Boot Setup

Use this skill on the first session after a fresh Bloom OS install.

## Prerequisite Check

If `~/.bloom/.setup-complete` exists, setup is already complete. Skip unless user asks to re-run specific steps.

## Setup Style

- Be conversational (one step at a time)
- Let user skip/defer steps
- Prefer Bloom tools over long shell copy-paste blocks
- Clarify tool-vs-shell: `service_install`, `bloom_repo_configure`, etc. are Pi tools (not bash commands)
- On fresh Bloom OS, user `bloom` has passwordless `sudo` for bootstrap tasks.

## Setup Steps

### 1) Git Identity

Ask the user for their name and email, then set globally:

```bash
git config --global user.name "<name>"
git config --global user.email "<email>"
```

Suggest sensible defaults (e.g., hostname-based) but let the user choose.

### 2) NetBird Setup (mesh networking)

NetBird provides the mesh network that other services (dufs, VNC) are accessible through remotely. Set it up first.

- Install service package: `service_install(name="netbird", version="0.1.0")`
- Preflight: confirm user has entries in `/etc/subuid` and `/etc/subgid`
- Authenticate: `podman exec bloom-netbird netbird up`
- Validate: `service_test(name="netbird")`

### 3) dufs Setup (tool-first)

- Install service package: `service_install(name="dufs", version="0.1.0")`
- Validate service: `service_test(name="dufs")`
- Direct user to `http://localhost:5000`
- dufs serves `$HOME` over WebDAV (mapped in container as bind mount)

If Bloom runs inside a VM, `localhost` in the guest may not be reachable from the host machine.
Offer one of these access paths:

- QEMU host-forwarded port (recommended in dev): host `localhost:5000` → guest `5000`
- SSH tunnel: `ssh -L 5000:localhost:5000 -p 2222 bloom@localhost`
- Guest IP direct access on LAN if routing allows (`http://<guest-ip>:5000`)

### 4) Optional Service Packages (manifest-first)

Prefer declarative setup:

1. Declare desired services in manifest (`manifest_set_service`)
2. Apply desired state (`manifest_apply(install_missing=true)`)
3. Validate selected services (`service_test` / `systemd_control` / `container_logs`)

Suggested optional profiles:

- **sync-only**: dufs
- **communication**: whatsapp + lemonade
Example declaration flow:

1. `manifest_set_service(name="whatsapp", image="ghcr.io/pibloom/bloom-whatsapp:0.2.0", version="0.2.0", enabled=true)`
2. `manifest_set_service(name="lemonade", image="ghcr.io/lemonade-sdk/lemonade-server:latest", version="0.1.0", enabled=true)`
3. `manifest_apply(install_missing=true)`

Post-install guidance:

- WhatsApp pairing: `journalctl --user -u bloom-whatsapp -f` and scan QR

If tooling is unavailable, use the fallback manual `oras pull` flow from `skills/service-management/SKILL.md`.

### 5) Mark Setup Complete

```bash
touch ~/.bloom/.setup-complete
```

## Notes

- Revisit skipped steps on demand
- Confirm each critical step before moving on

## Developer Mode (optional, not part of first-boot)

For contributors who want to submit PRs back to the Bloom repo, install `gh` and configure the repo:

```bash
sudo dnf install gh
gh auth login
```

Then use `bloom_repo_configure` to set up fork-based PR flow:
1. `bloom_repo_configure(repo_url="https://github.com/{owner}/pi-bloom.git")`
2. `bloom_repo_status` (verify PR-ready state)
3. `bloom_repo_sync(branch="main")`
