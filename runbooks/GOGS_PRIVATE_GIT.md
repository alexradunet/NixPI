# Historical Gogs Private Git Server

This runbook documents the retired Debian/Docker Gogs Git server that previously hosted the `nazar` infrastructure repository.

Current Git service: VM 101 has been rebuilt as a declarative NixOS Forgejo VM. See `runbooks/FORGEJO_GIT_VM.md`.

## Retired state

```text
Service: Gogs
Purpose: private minimal Git server for nazar/infra repositories
Access model: NetBird-only
VM ID: 101
VM name: gogs
Guest OS: Debian 13 cloud image
Guest NAT IP: 10.10.10.21
Gogs image: gogs/gogs:next-0.14.2
Storage path in VM: /srv/gogs
Database: SQLite
Admin user: nazar
Admin email: admin@nazar.studio
Credentials file on Proxmox host: /root/gogs-admin-credentials.txt
```

Do not copy credentials into this repository.

## Policy status

VM 101 used to run Debian 13 with a Docker-managed Gogs service. That legacy VM was intentionally destroyed and replaced by NixOS + Forgejo.

See `runbooks/NIXOS_DECLARATIVE_VM_POLICY.md`.

## URLs

```text
Web UI:   http://git.nazar.studio/
Git SSH:  ssh://git@git.nazar.studio:10022/nazar/nazar.git
Repo:     nazar/nazar
Canonical infra remote: yes, for now
```

DNS:

```text
git.nazar.studio A 100.124.39.100
```

The DNS record points to the Proxmox host's NetBird overlay IP, not to the public Hetzner IP. The service is reachable only from NetBird-connected devices with matching ACLs.

## Traffic flow

```text
NetBird client
  -> git.nazar.studio / 100.124.39.100
  -> Proxmox host nazar
  -> nginx/socat bound to 100.124.39.100 only
  -> Gogs VM 101 at 10.10.10.21
```

Ports:

```text
100.124.39.100:80     -> nginx virtual host git.nazar.studio -> 10.10.10.21:3000
100.124.39.100:10022  -> socat -> 10.10.10.21:10022 -> Gogs builtin SSH on container port 2222
```

No Gogs ports are intentionally exposed on the public Hetzner interface.

## VM configuration

Important Proxmox config:

```text
VMID: 101
name: gogs
onboot: 1
startup: order=20
memory: 2048 MB
balloon: 512 MB
cores: 2
boot: scsi0
scsi0: local:101/vm-101-disk-1.qcow2, size=32G
net0: virtio=BC:24:11:0A:4B:0E, bridge=vmbr1
QEMU guest agent: enabled
```

DHCP reservation on the host:

```text
BC:24:11:0A:4B:0E -> 10.10.10.21 -> gogs
```

The reservation is in:

```text
/etc/systemd/system/ownloom-vm-dhcp.service
```

## Gogs container service

Inside VM 101:

```text
systemd unit: /etc/systemd/system/gogs-docker.service
volume: /srv/gogs:/data
container: gogs
image: gogs/gogs:next-0.14.2
published ports in VM:
  3000 -> Gogs HTTP
  10022 -> Gogs SSH, forwarded to container 2222
```

Useful checks from Proxmox:

```bash
qm status 101
qm agent 101 ping
curl --noproxy '*' -I http://10.10.10.21:3000/
qm guest exec 101 -- bash -lc 'systemctl status gogs-docker --no-pager -l'
qm guest exec 101 -- bash -lc 'docker ps --no-trunc'
```

Gogs config path inside VM:

```text
/srv/gogs/gogs/conf/app.ini
```

Important settings:

```ini
BRAND_NAME = Nazar Git
RUN_MODE = prod

[server]
EXTERNAL_URL = http://git.nazar.studio/
DOMAIN = git.nazar.studio
HTTP_PORT = 3000
START_SSH_SERVER = true
SSH_LISTEN_PORT = 2222
SSH_PORT = 10022

[database]
TYPE = sqlite3
PATH = /data/gogs/data/gogs.db

[auth]
REQUIRE_SIGNIN_VIEW = true
DISABLE_REGISTRATION = true

[repository]
ROOT = /data/git/gogs-repositories
FORCE_PRIVATE = true
DEFAULT_BRANCH = main
```

## Repository bootstrap

The local `/root/nazar` repository has remote `nazar`:

```bash
git remote -v
# nazar ssh://git@git.nazar.studio:10022/nazar/nazar.git
```

Initial committed `main` history was pushed to Gogs:

```text
91fd333 main -> nazar/main
```

Local uncommitted work may still exist. Check before assuming Gogs has every local file:

```bash
git status --short --branch
```

## SSH keys

Gogs SSH host key fingerprint observed from clients:

```text
SHA256:JZiccfi5TsvntUgfX8wM+305cjoJXpiF5F9p5b2bw8w
```

Current known user/deploy keys added:

```text
nazar host push key: /root/.ssh/gogs-nazar-push on Proxmox host
alex@yoga: user SSH key added to Gogs account nazar
```

Add more user keys through:

```text
http://git.nazar.studio/ -> User Settings -> SSH Keys
```

Test from a NetBird-connected client:

```bash
git ls-remote ssh://git@git.nazar.studio:10022/nazar/nazar.git
```

Expected output includes:

```text
91fd333... HEAD
91fd333... refs/heads/main
```

## Backups

A Proxmox backup job is configured:

```text
Job ID: gogs-daily
VM ID: 101
Schedule: daily at 03:20
Mode: snapshot
Compression: zstd
Storage: local
Retention: keep-last=7
Notes template: {{guestname}} private git server
Notification mode: notification-system
```

An initial manual backup was also completed successfully:

```text
/var/lib/vz/dump/vzdump-qemu-101-2026_05_10-18_38_46.vma.zst
Result: OK
Archive size: ~683 MiB
```

Local-only backups protect against VM mistakes, but not against total host loss. For now, manually download important Gogs backup archives from `/var/lib/vz/dump/` to the desktop PC after important changes. Automated encrypted backups or an external Git mirror can be reconsidered later if needed.

## Operations

Restart Gogs container service:

```bash
qm guest exec 101 -- bash -lc 'systemctl restart gogs-docker.service'
```

View Gogs logs:

```bash
qm guest exec 101 -- bash -lc 'docker logs --tail=200 gogs'
```

Run a Gogs backup inside the container if needed:

```bash
qm guest exec 101 -- bash -lc "docker exec gogs sh -lc 'cd /app/gogs && ./gogs backup --config /data/gogs/conf/app.ini'"
```

Note: Proxmox VM-level backups are the primary configured backup mechanism right now.

## Security notes

- Registration is disabled.
- Sign-in is required to view content.
- New repositories are forced private.
- Gogs web is currently plain HTTP over NetBird; this is acceptable for private overlay use but can later be upgraded to HTTPS with DNS-01.
- This legacy Debian/Docker Gogs VM was retired; VM 101 is now the declarative NixOS Forgejo VM documented in `runbooks/FORGEJO_GIT_VM.md`.
- Admin credentials are root-only on the Proxmox host at `/root/gogs-admin-credentials.txt`.
- API bootstrap tokens used during setup were deleted after use.
