# OwnLoom Data VM Runbook

VM 121 (`ownloom-data`) is the approved private personal/user-data VM for OwnLoom.

## Target

```text
Hostname / Proxmox name: ownloom-data
VMID: 121
NAT IP: 10.10.10.41/24 via vmbr1
Gateway: 10.10.10.1
Domain metadata: data.nazar.studio
NetBird name: ownloom-data.netbird.cloud
NetBird private DNS: data.nazar.studio
CPU: 2 vCPU
RAM: 4096 MiB, balloon 1024 MiB
Disk: 100 GiB after Proxmox resize
Firmware for imported image: SeaBIOS
Autostart: off initially
Public exposure: none
NetBird: ownloom-data.netbird.cloud / 100.124.7.246
Deployment status: running, imported from qcow2, NetBird enrolled
```

NetBird/private access is canonical. Do not add public DNS routes, public port
forwards, or Proxmox host forwarding for this VM without a new explicit decision.
Minecraft remains the only documented opt-in public-service exception.

Direct DAV service access is allowed only by NetBird policy:

```text
admins-to-ownloom-data-dav: admins -> ownloom-data TCP/80
ownloom-to-ownloom-data-dav: ownloom -> ownloom-data TCP/80
```

VM SSH administration remains through `netbird ssh root@nazar`, then `ssh alex@ownloom-data` over the private NAT bridge alias. Root VM SSH remains key-only for break-glass and current compatibility.

## Enabled services

- Radicale CalDAV/CardDAV service, suitable for calendar/contact/journal DAV data.
- nginx WebDAV for personal wiki/files/journal Markdown under `/files/`.
- Radicale and WebDAV are reachable through the NetBird interface only; the NAT bridge is not opened for DAV HTTP.

Auth is enabled without committing plaintext credentials or password hashes.
nginx protects both `/files/` and `/radicale/` with Basic Auth from:

```text
/var/lib/ownloom-data/secrets/ownloom-data-htpasswd
```

The file is provisioned outside git and should be `root:nginx` / `0640`.
Radicale is bound to loopback and trusts nginx's `X-Remote-User` header via
`auth.type = http_x_remote_user`, with `owner_only` rights. VM 120 uses the
same `alex` WebDAV user for the ultra-simple initial setup and reads its password from:

```text
/var/lib/ownloom/secrets/alex-webdav-password
```

Current plaintext recovery copy on `nazar`, if still present after provisioning:

```text
/root/ownloom-data-credentials.txt
```

Store those credentials in the password manager and then remove the recovery
copy if desired. Move these runtime secrets to encrypted sops-managed material
and complete backup/restore validation before migrating real personal data.

## State paths

```text
/var/lib/radicale/collections        Radicale collections
/var/lib/ownloom-data/webdav         WebDAV personal files/wiki/journal data
/var/lib/ownloom-data/webdav/wiki    default personal wiki collection
/var/lib/ownloom-data/wiki-git-backup periodic git snapshot worktree for the wiki
```

## Personal wiki git snapshots

The personal wiki remains WebDAV-primary at:

```text
/var/lib/ownloom-data/webdav/wiki
```

A declarative systemd timer snapshots that directory to the private Forgejo repo:

```text
ssh://git@10.10.10.21:10022/nazar/personal-wiki-backup.git
```

Timer/unit:

```text
ownloom-wiki-git-backup.timer    # hourly, persistent
ownloom-wiki-git-backup.service
```

Runtime deploy key, provisioned outside git:

```text
/var/lib/ownloom-data/secrets/wiki-backup-ed25519
```

The public half is installed as a write deploy key on the private Forgejo repo. The one-time Forgejo bootstrap token used to create the repo/key was deleted after use.

## Build and validate

```bash
nix flake check --no-build
nix build .#nixosConfigurations.ownloom-data.config.system.build.toplevel
nix build .#ownloom-data-qcow2
```

The image output is `result/nixos-ownloom-data.qcow2`.

## STOP before destructive operations

Do not run destructive Proxmox commands until the user gives explicit live
confirmation. Destructive commands include `qm stop`, `qm destroy`, disk
replacement, and any operation that overwrites an existing VM.

## Create VM 121 from qcow2

Current status: VM 121 has already been created and started. Keep these commands as the recreate procedure. After final confirmation only:

```bash
qm create 121 \
  --name ownloom-data \
  --memory 4096 \
  --balloon 1024 \
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
  --net0 virtio=BC:24:11:0A:4B:21,bridge=vmbr1

qm importdisk 121 result/nixos-ownloom-data.qcow2 local --format qcow2
qm set 121 --virtio0 local:121/vm-121-disk-0.qcow2,discard=on
qm set 121 --boot 'order=virtio0'
qm resize 121 virtio0 100G
qm set 121 --onboot 0
qm set 121 --startup order=41
qm start 121
```

No public port-forward validation should exist for this VM because it is internal-only.

## Guest validation

```bash
qm status 121
qm agent 121 ping
ping -c3 10.10.10.41
# From nazar after `netbird ssh root@nazar`:
ssh alex@ownloom-data 'hostname; whoami; systemctl is-active radicale nginx'
ssh alex@ownloom-data 'netbird status'
ssh alex@ownloom-data 'sudo systemctl --failed'
ssh alex@ownloom-data 'systemctl status radicale nginx --no-pager'
ssh alex@ownloom-data 'curl -fsS http://127.0.0.1:5232/.web/ >/dev/null || true'
ssh alex@ownloom-data 'curl -fsS http://127.0.0.1/ | head'
ssh alex@ownloom-data 'curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1/files/'
ssh alex@ownloom-data 'systemctl status ownloom-wiki-git-backup.timer --no-pager'
ssh alex@ownloom-data 'sudo systemctl start ownloom-wiki-git-backup.service'
ssh alex@ownloom-data 'sudo env GIT_SSH_COMMAND="ssh -i /var/lib/ownloom-data/secrets/wiki-backup-ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=/var/lib/ownloom-data/secrets/wiki-backup-known_hosts" git ls-remote ssh://git@10.10.10.21:10022/nazar/personal-wiki-backup.git refs/heads/main'

# From ownloom or an admin peer in the NetBird admins group:
getent hosts data.nazar.studio
curl -fsS http://data.nazar.studio/ | head
curl -sS -o /dev/null -w '%{http_code}\n' http://data.nazar.studio/files/  # expected: 401 without credentials
# Avoid echoing the password or putting it in process arguments.
NETRC=$(mktemp)
trap 'rm -f "$NETRC"' EXIT
chmod 600 "$NETRC"
{
  printf 'machine data.nazar.studio login alex password '
  sed -n '1p' /var/lib/ownloom/secrets/alex-webdav-password
} > "$NETRC"
curl --netrc-file "$NETRC" \
  -fsS -X OPTIONS -i http://data.nazar.studio/files/ | head
rm -f "$NETRC"
trap - EXIT

# NAT fallback from Proxmox/private side using key-only root break-glass:
ssh root@10.10.10.41 hostname
```

## VM 122 reservation

`ownloom-vault` is reserved as a future concept at VMID 122 / `10.10.10.42`.
No Bitwarden/Vaultwarden service is enabled in this repository.
