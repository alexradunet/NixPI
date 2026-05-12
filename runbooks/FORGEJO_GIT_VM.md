# Forgejo Git VM Runbook

This runbook documents the replacement of the legacy Debian/Docker Gogs VM with a fresh declarative NixOS Forgejo VM.

## Current state

```text
VMID: 101
Proxmox name: git
Guest OS: NixOS 26.05 pre-release
Service: Forgejo 15.0.1 LTS
NAT IP: 10.10.10.21
NetBird IP: 100.124.135.247
NetBird FQDN: git.netbird.cloud
State path: /var/lib/forgejo
Web: http://git.nazar.studio/
Git SSH: ssh://git@git.nazar.studio:10022/nazar/nazar.git
Backup job: git-daily, daily 03:20, keep-last=7
```

## Migration decisions

Approved direction:

```text
Target app: Forgejo
Target OS: NixOS
Preserve from old Gogs: only Git repository content that exists locally and is pushed after rebuild
Do not preserve: old Gogs users, SSH keys, issues, settings, database, container state
Fresh pre-rebuild backup of old VM: intentionally skipped by user decision
Fleet direction: this repo becomes the Proxmox/NixOS VM fleet root
```

This means destroying the old VM is expected to lose all old Forge/Gogs application state. Older same-host backup archives may exist from previous work, but this migration does not create or rely on a fresh pre-rebuild backup.

## Current external contract to preserve

```text
VMID: 101
Proxmox name after rebuild: git
NAT IP: 10.10.10.21
Web: http://git.nazar.studio/
Git SSH: ssh://git@git.nazar.studio:10022/nazar/nazar.git
Host routing: 100.124.39.100:80 -> 10.10.10.21:3000
Host routing: 100.124.39.100:10022 -> 10.10.10.21:10022 via git-ssh-proxy.service
```

If the rebuilt VM keeps the same IP and ports, the existing NetBird-only nginx and socat host routing should not need to change.

## Declarative source

The canonical VM 101 service profile now lives in the Forgejo repo:

```text
/root/forgejo
/root/forgejo/nix/hosts/forgejo/default.nix
/root/forgejo/nix/modules/forgejo*.nix
/root/forgejo/runbooks/FORGEJO_GIT_VM.md
```

Nazar remains responsible for the central fleet inventory, shared VM baseline modules, deploy-rs apps, and host-side `git-ssh-proxy.service`.

Evaluate from the Proxmox host, where Nix is installed as tooling only:

```bash
. /etc/profile.d/nix.sh
nix flake metadata
nix flake check
nix build .#nixosConfigurations.git.config.system.build.toplevel
nix build .#git-qcow2
```

`result/nixos-git.qcow2` is the generated importable Proxmox disk image. Update the lock file intentionally when needed:

```bash
nix flake lock
```

## STOP before destructive operations

Do not run the commands below until the user gives final confirmation in the live session.

Destructive commands include:

```bash
qm stop 101
qm destroy 101 --purge
```

## Recreate VM 101

After final confirmation only:

```bash
qm stop 101 || true
qm destroy 101 --purge

qm create 101 \
  --name git \
  --memory 2048 \
  --balloon 512 \
  --cores 2 \
  --cpu host \
  --numa 1 \
  --machine q35 \
  --bios seabios \
  --ostype l26 \
  --scsihw virtio-scsi-single \
  --agent enabled=1 \
  --serial0 socket \
  --vga std \
  --tablet 1 \
  --net0 virtio=BC:24:11:0A:4B:0E,bridge=vmbr1

qm importdisk 101 result/nixos-git.qcow2 local --format qcow2
qm set 101 --virtio0 local:101/vm-101-disk-0.qcow2,discard=on
qm set 101 --boot 'order=virtio0'
qm resize 101 virtio0 32G
qm set 101 --onboot 1
qm set 101 --startup order=20
qm start 101
```

The MAC is intentionally preserved so the existing DHCP reservation still maps VMID 101 to `10.10.10.21`. The NixOS config uses a static IP too. The first boot should grow the root partition to the resized 32 GiB disk.

## Bootstrap Forgejo

Forgejo itself is declarative. Runtime application state still has to be initialized.

Optional admin bootstrap path:

```text
/run/secrets/forgejo-admin-password
```

If that file exists, `forgejo-bootstrap.service` tries to create admin user `nazar` with email `admin@nazar.studio`. If it does not exist, the unit skips cleanly.

After boot:

```bash
systemctl status forgejo --no-pager
systemctl status forgejo-bootstrap --no-pager
ss -ltnp | grep -E ':3000|:10022'
curl --noproxy '*' -I http://10.10.10.21:3000/
```

Create repository `nazar/nazar` in Forgejo, then push this repo. Only refs present in the local checkout will be preserved; old remote-only Gogs refs are intentionally discarded by this migration.

```bash
cd /root/nazar
git status --short --branch
git remote -v
# If needed:
git remote set-url nazar ssh://git@git.nazar.studio:10022/nazar/nazar.git

git push -u nazar main
git push nazar --tags
```

## Validate private access

From Proxmox:

```bash
qm status 101
qm agent 101 ping
curl --noproxy '*' -I http://10.10.10.21:3000/
curl --noproxy '*' -I -H 'Host: git.nazar.studio' http://100.124.39.100/
```

From a NetBird admin client:

```bash
curl --connect-timeout 5 http://git.nazar.studio/
git ls-remote ssh://git@git.nazar.studio:10022/nazar/nazar.git
```

The SSH host fingerprint will change from the old Gogs server. Clients may need to remove the old known-host entry for `[git.nazar.studio]:10022`.

## NetBird enrollment

`services.netbird.enable = true` is declared in the common VM modules. VM 101 is enrolled as `git.netbird.cloud` with NetBird IP `100.124.135.247`.

If a setup key was pasted into chat or logs during enrollment, revoke/rotate it in the NetBird dashboard.

## Backup after rebuild

The fresh old-VM backup was intentionally skipped. `qm destroy 101 --purge` removed the old `gogs-daily` backup job with the VM config. A new `git-daily` VM 101 backup job is configured for the rebuilt Forgejo VM.

## Rollback limitation

With no fresh pre-rebuild backup, rollback means recreating a new Git VM and pushing this repository again. Old Gogs application metadata will not be recoverable from this migration path.

## Creating VM service repositories

Nazar now consumes VM-owned service repositories for Minecraft, OwnLoom, and OwnLoom Data. Create these Forgejo repositories as private, empty repositories under the existing `nazar` namespace before pushing split histories:

```text
nazar/minecraft
nazar/ownloom
nazar/ownloom-data
```

Creation checklist:

1. Use the Forgejo UI or a short-lived API token.
2. Keep the repository private.
3. Use default branch `main`.
4. Do not initialize with README, license, or gitignore; the first push comes from the prepared local repositories.
5. Validate with `git ls-remote ssh://git@git.nazar.studio:10022/nazar/<repo>.git` before switching Nazar flake inputs from local `path:` URLs to `git+ssh:` URLs.

Do not create bare repositories directly under `/var/lib/forgejo/repositories`; that bypasses Forgejo database state, permissions, hooks, and UI metadata.


### Recovery note for split VM repos

The Nazar flake now locks `minecraft`, `ownloom`, and `ownloom-data` as Forgejo SSH inputs. For VM 101 disaster recovery, keep local clones, off-host mirrors, or git bundles for all five repositories (`nazar` plus `forgejo`, `minecraft`, `ownloom`, and `ownloom-data`). If Forgejo is unavailable during recovery, build with local overrides such as:

```bash
nix build .#git-qcow2   --override-input minecraft path:/root/minecraft   --override-input ownloom path:/root/ownloom   --override-input ownloom-data path:/root/ownloom-data
```
