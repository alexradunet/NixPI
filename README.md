# nazar

This repository is the operating manual and declarative VM fleet for the Hetzner Server Auction Proxmox host `nazar`. Keep the split clear: host/Proxmox material documents or installs things on `nazar`; VM state lives under the NixOS fleet in `flake.nix` and `nix/`.

## Current host identity

| Item | Value |
|---|---|
| Provider | Hetzner Server Auction / Robot |
| Proxmox hostname/node | `nazar` |
| Public IPv4 | `167.235.12.22` |
| Public IPv6 | `2a01:4f8:262:1b01::2/64` |
| Main NIC | `enp0s31f6` |
| OS | Debian 13 Trixie + Proxmox VE 9.1 |
| Nix tooling | Nix 2.34.7 multi-user install, for flake evaluation/builds only |
| Disk layout | 2x NVMe 512 GB, Linux software RAID1 |
| VM NAT bridge | `vmbr1`, `10.10.10.1/24` |
| Proxmox NetBird IP | `100.124.39.100` |
| Proxmox NetBird FQDN | `nazar.netbird.cloud` |

## Repository layout

```text
flake.nix                 # Nazar fleet orchestrator, deploy-rs apps, VM repo inputs
flake.lock                # locks nixpkgs, infra inputs, and VM repo inputs
nix/fleet/vms.nix         # central VM inventory: IDs, IPs, DNS, sizing, service contracts
/root/forgejo/           # VM 101 service repo: Forgejo NixOS module and runbook
nix/modules/common/       # reusable Nazar VM baseline modules
nix/modules/services/     # Nazar-owned infrastructure services, currently Forgejo
/root/minecraft/          # VM 110 service repo: PaperMC NixOS module and runbook
/root/ownloom/            # VM 120 service repo: OwnLoom packages/modules/runbooks
/root/ownloom-data/       # VM 121 service repo: DAV/Radicale module and runbook
proxmox/                  # files installed on the Proxmox host (nginx, zellij, notifications)
scripts/                  # host-side operational scripts
systemd/                  # host-side systemd units/timers
www/nazar-dashboard/      # host-served private dashboard
.pi/skills/               # project-local Pi recovery skill(s)
runbooks/                 # Nazar/fleet operational procedures and VM runbook stubs
security/                 # hardening state and roadmap
```

Source-of-truth rule: keep durable facts in `README.md`, `nix/fleet/vms.nix`, and focused runbooks. Do not keep stale command dumps, Pi session exports, build `result` symlinks, vendored upstream checkouts, or agent scratch notes in git.

## VM policy

Default VM rule: new VMs should run NixOS and be fully declarative. Guest OS, packages, services, users, firewall, SSH/NetBird integration, and backup hooks should live in version-controlled Nix configuration. Manual guest changes are not a valid long-term state.

VM 101 is the infrastructure Git/Forgejo VM; its service code/config now lives in `/root/forgejo`. Other VM-owned service code/config lives in sibling repositories: `/root/minecraft` for VM 110, `/root/ownloom` for VM 120, and `/root/ownloom-data` for VM 121. Nazar still owns the central fleet inventory, shared VM baseline, and infrastructure/networking boundary. Each NixOS VM gets declarative fleet context at `/etc/nazar/vm-context.md`, a generated self-rebuild flake at `/etc/nazar/self`, and helpers `nazar-vm-context`, `nazar-vm-switch`, and `nazar-deploy-request` so VM-local Pi agents can commit, push, and rebuild their own VM without broad fleet credentials.

Canonical operating model: VM-local Pi agents author/test/deploy VM-owned service changes; Nazar remains the infrastructure, networking, recovery, and fallback deploy authority. Proxmox VE on Debian remains the current host platform while a full NixOS + microVM clean reinstall is prepared deliberately. See `runbooks/CANONICAL_OPERATING_MODEL.md`, `runbooks/NIXOS_MICROVM_HOST_MIGRATION.md`, and `runbooks/NIXOS_MICROVM_CLEAN_REINSTALL.md`.

See `runbooks/NIXOS_DECLARATIVE_VM_POLICY.md`.

Fleet scaffolding lives in `flake.nix`, `nix/fleet/`, `nix/lib/`, and `nix/modules/common/`. VM 101/110/120/121 are declarative NixOS VMs built from their own flake repos and orchestrated here. See `runbooks/FORGEJO_GIT_VM.md`, `runbooks/MINECRAFT_PAPERMC_VM.md`, and `runbooks/NIXOS_FLEET_ARCHITECTURE.md`.

## Private Git server

A private Forgejo Git server is running for the `nazar` infrastructure repo.

| Item | Value |
|---|---|
| Proxmox VM ID | `101` |
| Proxmox VM name | `git` |
| Guest OS | NixOS 26.05 pre-release from this flake |
| VM IP on NAT bridge | `10.10.10.21` |
| VM NetBird IP/FQDN | `100.124.135.247` / `git.netbird.cloud` |
| Web UI | `http://git.nazar.studio/` |
| Git SSH remote | `ssh://git@git.nazar.studio:10022/nazar/nazar.git` |
| Access model | NetBird-only |
| Backup job | `git-daily`, daily `03:20`, `keep-last=7` |

## Minecraft server

A PaperMC Minecraft VM is declared for the `mc.nazar.studio` server.

| Item | Value |
|---|---|
| Proxmox VM ID | `110` |
| Proxmox VM name | `minecraft` |
| Guest OS | NixOS 26.05 pre-release from this flake |
| VM IP on NAT bridge | `10.10.10.30` |
| Service DNS | `mc.nazar.studio` |
| Service ports | `80/tcp` for the landing page, `25565/tcp` for Minecraft, `24454/udp` for Simple Voice Chat |
| State path | `/var/lib/minecraft` |
| Access model | Public landing page plus Minecraft TCP/25565 and voice UDP/24454 forwarding enabled; admin access remains NetBird-private |
| Backup job | `minecraft-daily`, daily `03:40`, `keep-last=7` |

See `runbooks/MINECRAFT_PAPERMC_VM.md` before creating or exposing it.

## Current VM state

OwnLoom now has declarative internal-only NixOS VM profiles in this flake. VM 120 is intended for Pi agent + core OwnLoom extension support, the technical local wiki, the phase-1 private web UI, and a Zellij developer terminal. VM 121 is the personal DAV-backed data tier. No Gateway, public Web, Minecraft, NAT forwards, or public exposure is enabled for OwnLoom.

| Item | Value |
|---|---|
| Proxmox VM ID | `120` |
| Proxmox VM name | `ownloom` |
| Build output | `.#ownloom-qcow2` |
| VM IP on NAT bridge | `10.10.10.40` |
| Domain metadata | `ownloom.nazar.studio` |
| Resources | 5 vCPU, 32 GiB RAM, 200 GiB disk |
| NetBird | `ownloom.netbird.cloud` / `100.124.202.128` |
| Current status | running, imported from `.#ownloom-qcow2`, NetBird enrolled |
| Private web UI | `http://ownloom.nazar.studio/` (NetBird-only, no phase-1 app auth) |
| Developer terminal | `http://ownloom.nazar.studio/zellij/` (Zellij web as `alex`) |

| Item | Value |
|---|---|
| Proxmox VM ID | `121` |
| Proxmox VM name | `ownloom-data` |
| Build output | `.#ownloom-data-qcow2` |
| VM IP on NAT bridge | `10.10.10.41` |
| Domain metadata | `data.nazar.studio` |
| State paths | `/var/lib/radicale/collections`, `/var/lib/ownloom-data/webdav` |
| Access model | NetBird/private only; no public routes |
| NetBird | `ownloom-data.netbird.cloud` / `100.124.7.246` |
| Current status | running, imported from `.#ownloom-data-qcow2`, NetBird enrolled |

VM 122 (`ownloom-vault`, `10.10.10.42`) is reserved as a future concept only; Bitwarden/Vaultwarden is not enabled.

Legacy VM 100 / `10.10.10.20` was the paused installer shell. Do not destroy old VM 100 backups until the VM 120 replacement is validated and important backups are copied off-host.

## Access

Private dashboard and Proxmox UI over NetBird/private DNS:

```text
https://nazar.studio/          # private dashboard + service links
https://nazar.studio/zellij/   # Zellij web terminal, token required
https://pve.nazar.studio/      # Proxmox UI alias, self-signed cert for now
https://100.124.39.100:8006    # direct Proxmox fallback
```

See `runbooks/NAZAR_PRIVATE_DASHBOARD.md` for dashboard/Zellij operations.

Private OwnLoom over NetBird/private DNS:

```text
http://ownloom.nazar.studio/          # personal web app, personal wiki by default
http://ownloom.nazar.studio/zellij/   # developer terminal as alex for Pi coding-agent work
```

Private Git over NetBird/private DNS:

```text
http://git.nazar.studio/
ssh://git@git.nazar.studio:10022/nazar/nazar.git
```

Minecraft service DNS:

```text
http://mc.nazar.studio/         # public Minecraft landing page
mc.nazar.studio:25565          # public game traffic; administration remains private
```

Shell access from the local NixOS desktop:

```bash
netbird ssh alex@nazar              # daily host shell once NetBird SSH client trust is established
netbird ssh root@nazar              # key-only/root break-glass fallback
```

`alex` is also a Linux sudo admin on the Proxmox host. The host `alex` password is locked; shell access is key/NetBird-identity based and sudo is passwordless. Root on `nazar` keeps the password-manager-backed console/rescue break-glass path. The root password was rotated on 2026-05-11, saved in the password manager, and the temporary handoff file was shredded.

Zellij is available on `nazar`, and the private dashboard exposes Zellij web at `https://nazar.studio/zellij/` for browser access with a Zellij login token. SSH logins still stay in a plain shell by default; attach to the persistent workspace manually when needed:

```bash
zellij attach --create nazar
```

Inside `nazar`, use Fresh for repository navigation and the VM-name aliases for private NAT access. `alex` is the canonical NixOS VM admin user; VM passwords remain locked and SSH is key-only:

```bash
ide                 # Fresh terminal IDE in /root/nazar
ssh alex@git
ssh alex@minecraft
ssh alex@ownloom
ssh alex@ownloom-data
```

Root VM SSH remains available key-only for current compatibility and break-glass administration, but it is not the normal human login. Do not add a shared VM password. VMs may have unique root console/noVNC break-glass passwords via `/var/lib/nazar/secrets/root-password-hash`; SSH password login remains disabled and the plaintext passwords must live only in the external password manager, not git.

Break-glass/fallback paths:

```bash
ssh root@10.10.10.40  # raw ownloom NAT IP from Proxmox/private side, root break-glass
ssh root@10.10.10.41  # raw ownloom-data NAT IP from Proxmox/private side, root break-glass
ssh nazar-public      # expected to time out in normal boot; Rescue is break-glass
```

Direct NetBird/OpenSSH to VM FQDNs is not canonical and is not allowed by the normal NetBird policy set.

## Fleet orchestration

`nazar` is the Proxmox host and the NixOS fleet orchestrator. Day-2 production VM changes are deployed by `/root/nazar` on the Proxmox host, using `deploy-rs` over the private `vmbr1` NAT aliases as `alex` with sudo to the root system profile. VM-local Pi agents should commit/push VM repo changes first; direct VM-local `nixos-rebuild switch` is not the canonical production path. On VMs, `nazar-vm-context` shows the local repo and deploy handoff, and Pi loads the same policy from `/home/alex/.pi/agent/AGENTS.md`.

```bash
netbird ssh root@nazar
cd /root/nazar
nix flake check --no-build
nix run .#deploy-git           # canary one VM first
nix run .#deploy-minecraft
nix run .#deploy-ownloom
nix run .#deploy-ownloom-data
# only after canary validation and a maintenance-window decision:
NAZAR_DEPLOY_ALL_CONFIRM=yes nix run .#deploy-all
```

After each deploy, run the VM's service checks (`systemctl --failed`, qemu guest status where useful, and the service-specific checks in that VM's runbook). These commands do not create or destroy Proxmox VMs; they switch the NixOS system profile on existing guests. Proxmox lifecycle actions (`qm create`, `qm destroy`, disk resize/import, backup restore) remain separately gated by the runbooks.

Proxmox login:

```text
Daily target: alex@pve, Administrator on /, TOTP enabled
Break-glass: root@pam, Linux PAM, TOTP enabled
```

Do not migrate `alex@pve` to PAM just because the Linux `alex` user exists. The Linux `alex` password is intentionally locked for shell access; keep the Proxmox UI account in the `pve` realm unless a future tested migration creates `alex@pam` with its own password/TOTP/ACL plan.

Public direct access to `https://167.235.12.22:8006` and public SSH to `167.235.12.22:22` are intentionally blocked in normal boot.

## Public exposure rule

Default posture: services stay under the NetBird layer. Public Reverse Proxy services and public port-forwarding units remain disabled unless a service is intentionally being shared.

Before toggling any service public, harden that VM/service for public traffic: real auth, TLS/proxying, least-privilege ports, no admin/debug exposure, backups/restore tested, logging/alerting, and a clear rollback toggle. If we are not sharing it yet, leave it NetBird-private as-is.

`data.nazar.studio` now has nginx Basic Auth for `/files/` and `/radicale/`. The initial ultra-simple setup uses one `alex` DAV/Radicale account for both human clients and VM 120's wiki backend. The committed config references runtime secret files only; no plaintext DAV/Radicale credentials or password hashes belong in git.

The personal wiki is WebDAV-primary on `data.nazar.studio` and is snapshotted hourly to the private Forgejo repo `nazar/personal-wiki-backup` by `ownloom-wiki-git-backup.timer` on VM 121.

## Important docs

- `runbooks/CANONICAL_OPERATING_MODEL.md` — source-of-truth operating model: Proxmox host, Nazar deploy authority, VM-local Pi workflow, and platform non-goals.
- `runbooks/NAZAR_PROXMOX_BASELINE.md` — current Proxmox host baseline, access model, and hardening tasks.
- `runbooks/NIXOS_FLEET_ARCHITECTURE.md` — VM fleet layout, deploy-rs flow, VMID/IP conventions.
- `runbooks/NIXOS_DECLARATIVE_VM_POLICY.md` — default declarative policy for all VMs.
- `runbooks/FORGEJO_GIT_VM.md` — Nazar-owned Forgejo deploy/recovery stub; canonical VM runbook lives in `/root/forgejo/runbooks/FORGEJO_GIT_VM.md`.
- `runbooks/MINECRAFT_PAPERMC_VM.md` — Nazar-owned Minecraft host-forwarding/deploy stub; canonical VM runbook lives in `/root/minecraft/runbooks/MINECRAFT_PAPERMC_VM.md`.
- `runbooks/OWNLOOM_VM_RECREATE.md` — Nazar-owned OwnLoom deploy/private-access stub; canonical VM runbook lives in `/root/ownloom/runbooks/OWNLOOM_VM_RECREATE.md`.
- `runbooks/OWNLOOM_DATA_VM.md` — Nazar-owned OwnLoom Data deploy/private-access stub; canonical VM runbook lives in `/root/ownloom-data/runbooks/OWNLOOM_DATA_VM.md`.
- `runbooks/BACKUPS.md` — VM backup/restore notes and backup job inventory.
- `runbooks/ALERTS.md` — Proxmox alert target plus RAID/SMART/ACME/disk/boot bridges.
- `runbooks/PROXMOX_FIREWALL.md` — native Proxmox firewall policy and rollback notes.
- `runbooks/NETBIRD_ACCESS.md` — NetBird access and private DNS runbook.
- `runbooks/DOMAIN_AND_TLS_SETUP.md` — private domain + TLS setup summary.
- `runbooks/NAZAR_PRIVATE_DASHBOARD.md` — private dashboard and Zellij web terminal.
- `runbooks/PI_ON_NAZAR.md` — Pi coding-agent installation and usage on `nazar`.
- `runbooks/FRESH_IDE_ON_NAZAR.md` — Fresh terminal IDE setup on `nazar`.
- `runbooks/RECOVERY_RUNBOOK.md` and `runbooks/RESCUE_DRILL.md` — Hetzner Rescue recovery.
- `security/HARDENING_APPLIED.md` and `security/HARDENING_ROADMAP.md` — hardening state and roadmap.
- `CHANGELOG.md` — chronological installation/hardening log.
- Historical-only runbooks: `runbooks/GOGS_PRIVATE_GIT.md`, `runbooks/NIXOS_UNSTABLE_VM.md`, `runbooks/PROXMOX_ACME_CERTIFICATE.md`.

## NetBird names

NetBird dashboard labels/FQDNs and private domain records are now aligned:

```text
nazar.netbird.cloud              -> 100.124.39.100
git.netbird.cloud                -> 100.124.135.247
ownloom.netbird.cloud            -> 100.124.202.128
ownloom-data.netbird.cloud       -> 100.124.7.246

nazar.studio NetBird custom zone:
  nazar.studio                   -> 100.124.39.100
  pve.nazar.studio               -> 100.124.39.100
  git.nazar.studio               -> 100.124.39.100
  ownloom.nazar.studio           -> 100.124.202.128
  data.nazar.studio              -> 100.124.7.246
  mc.nazar.studio                -> 100.124.39.100

Public `*.nazar.studio` exposure is controlled service-by-service. Default is private/NetBird-only; public reverse-proxy or forwarding must be explicitly enabled per service.
```

## Warning about secrets

This folder should not contain private keys, passwords, Proxmox private cert keys, setup keys, or WireGuard/NetBird secrets.
