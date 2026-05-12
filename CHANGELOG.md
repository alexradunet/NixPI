# Changelog

## 2026-05-12 — Nazar VM Pi/fleet context

- Added a shared Nazar VM context baseline that installs `/etc/nazar/vm-context.{md,json}`, `nazar-vm-context`, and `nazar-deploy-request` on fleet VMs.
- Added a global Pi `AGENTS.md` on VMs so VM-local agents know they can edit/test/commit/push the VM-owned repo, while production deploys remain a `/root/nazar` responsibility.
- Added Node/npm to the Nazar VM Pi baseline so project-local Pi package installs do not require an ad-hoc user profile install.

## 2026-05-12 — Remove Minecraft RCON

- Removed Minecraft RCON from VM 110, removed the NetBird TCP/25575 host forward, and deleted the private NetBird RCON policy because remote console access is not currently needed.

## 2026-05-12 — OwnLoom direct NetBird access

- Added the `admins-to-ownloom-web` NetBird policy, allowing admin peers to reach VM 120 OwnLoom directly on TCP/80 at `http://ownloom.nazar.studio/` and `/zellij/` without SSH tunneling.
- Added `scripts/netbird/ensure-ownloom-direct.py` to repair/ensure the OwnLoom NetBird policy and private DNS record using a root-only NetBird token file at `/root/.nazar-secrets/netbird-api-token`.

## 2026-05-12 — Forgejo VM repository and VM Pi baseline

- Split VM 101 Forgejo/Git service code into `/root/forgejo` and private Forgejo repo `nazar/forgejo`.
- Updated Nazar to consume `forgejo` as a flake input while preserving `.#git-qcow2` and `.#deploy-git`.
- Added a Nazar VM Pi baseline module for VM-owned repo worktrees on Git, Minecraft, and OwnLoom Data; OwnLoom keeps its richer OwnLoom-specific Pi module.
- Documented recovery `--override-input` fallbacks so Forgejo recovery can use local VM repo clones if VM 101 is unavailable.

## 2026-05-12 — VM service repositories split out

- Split VM-owned service code/config into sibling repositories: `/root/minecraft`, `/root/ownloom`, and `/root/ownloom-data`.
- Kept `nazar` as the central fleet inventory and deploy-rs orchestrator, with compatibility outputs such as `.#minecraft-qcow2`, `.#ownloom-qcow2`, `.#ownloom-data-qcow2`, and `.#deploy-*`.
- Replaced root VM runbooks with Nazar-owned stubs; canonical service runbooks now live in the VM repositories.
- Preserved host-side Proxmox assets, NetBird/private DNS policy, public Minecraft forwarding toggles, and runtime secrets policy in `nazar`.

## 2026-05-11 — OwnLoom phase-1 web app scaffold

- Added the phase-1 OwnLoom web app contract and scaffold for a NetBird-private VM 120 web interface based on `@earendil-works/pi-web-ui`, mini-lit, and Tailwind.
- Added planned API boundaries for personal wiki status/search/daily/ingest/session-capture/lint and technical-domain evolution requests.
- Added declarative VM 120 service wiring for nginx, `ownloom-web`, and a separate Zellij web terminal as `alex` under `/zellij/`.

## 2026-05-11 — Minecraft voice chat public-port audit

- Confirmed from the upstream Simple Voice Chat docs that voice traffic uses a separate UDP port, `24454` by default, configured in `plugins/voicechat/voicechat-server.properties`.
- Added explicit Proxmox host firewall allows on `enp0s31f6` for public `25565/tcp` and Simple Voice Chat `24454/udp`, then restarted `minecraft-netbird-forward.service` and `minecraft-public-forward.service` to restore NAT/forward rules after the firewall reload.
- Verified the Minecraft VM is listening on UDP `24454`, the plugin config has `port=24454`, and the official `svc ping` tool gets an application-level response from `10.10.10.30:24454`.
- After updating the Hetzner Robot input rule, external UDP probes to `mc.nazar.studio:24454` increment Nazar's public DNAT/FORWARD counters, confirming provider-side UDP `24454` traffic now reaches the host and forwards to VM 110. Public Minecraft TCP still works for `mc.nazar.studio:25565`.

## 2026-05-11 — Public Minecraft forwarding enabled

- Enabled `minecraft-public-forward.service` on `nazar`, forwarding public TCP/25565 and UDP/24454 from `enp0s31f6` to VM 110 (`10.10.10.30`).
- Verified `167.235.12.22:25565` reports online publicly as Paper `26.1.2` with MOTD `Nazar Minecraft`.
- `mc.nazar.studio` still resolves through the public wildcard to `eu1.netbird.services`; add an explicit public `A` record for `mc.nazar.studio -> 167.235.12.22` before using the hostname outside NetBird.

## 2026-05-11 — Minecraft Timberella plugin

- Added Timberella `1.2.0` as a declarative PaperMC plugin for VM 110 (`minecraft`), pinned to its Hangar CDN jar and Nix SHA-256 hash.

## 2026-05-11 — Personal wiki git snapshots

- Created private Forgejo repo `nazar/personal-wiki-backup` for periodic snapshots of the WebDAV-primary personal wiki.
- Added a dedicated deploy key from VM 121 (`ownloom-data`) to that repo; the private key is a runtime secret outside git.
- Added declarative `ownloom-wiki-git-backup.service` and hourly persistent timer on VM 121.
- The service mirrors `/var/lib/ownloom-data/webdav/wiki` into `/var/lib/ownloom-data/wiki-git-backup`, commits changes, and pushes over the private NAT bridge to `ssh://git@10.10.10.21:10022/nazar/personal-wiki-backup.git`.
- Verified the first snapshot commit reached `refs/heads/main`; the one-time Forgejo bootstrap token was deleted after repo/key creation.

## 2026-05-11 — OwnLoom Data DAV/Radicale auth

- Enabled nginx Basic Auth for `data.nazar.studio` `/files/` and `/radicale/` using a runtime htpasswd file outside git.
- Switched Radicale from unauthenticated bootstrap mode to `http_x_remote_user` behind nginx with `owner_only` rights.
- Provisioned runtime credentials on VM 121 and the OwnLoom WebDAV password file on VM 120; no plaintext credentials or password hashes were committed.
- Simplified to a single `alex` DAV/Radicale account for both human clients and VM 120's wiki backend.
- Verified unauthenticated NetBird-private requests to `/files/` and `/radicale/` return `401`, and authenticated `alex` WebDAV access returns `200`.

## 2026-05-11 — Nazar private DNS and public toggle model

- Created NetBird Custom Zone `nazar.studio` with private records: `nazar.studio`, `pve.nazar.studio`, `git.nazar.studio`, `ownloom.nazar.studio`, `data.nazar.studio`, and `mc.nazar.studio`.
- Disabled the old NetBird Custom Zone `nb.ownloom.com`; records are preserved but no longer distributed.
- Validated `data.nazar.studio` DAV access from the `ownloom` VM over NetBird.
- Added NetBird-private Minecraft forwarding on `wt0` for TCP/25565 and UDP/24454, and disabled the public Minecraft forwarding unit by default.
- Added NetBird policies for admin access to private Minecraft TCP/25565 and voice UDP/24454 through `nazar`.
- Configured `nazar.studio` and `pve.nazar.studio` on the NetBird-only nginx Proxmox vhost, with a refreshed self-signed certificate covering both names.
- Verified Gandi wildcard `*.nazar.studio -> eu1.netbird.services.` and NetBird Reverse Proxy custom domain validation for `nazar.studio`.
- Created disabled NetBird Reverse Proxy services as public toggles for `pve.nazar.studio`, `git.nazar.studio`, `ownloom.nazar.studio`, and `data.nazar.studio`.
- Updated fleet metadata to use `mc.nazar.studio`, `ownloom.nazar.studio`, and `data.nazar.studio`; public exposure remains opt-in per service.
- Documented the public exposure rule: keep services NetBird-private by default; before enabling a public Reverse Proxy service or public forward, the target VM/service must be explicitly hardened for public traffic.
- Deployed the updated NixOS configurations to VM 110 (`minecraft`), VM 120 (`ownloom`), and VM 121 (`ownloom-data`).
- Fixed VM 120/121 installed-host profiles to match the deployed legacy-BIOS qcow2 layout so remote `nixos-rebuild switch` is reproducible.
- Verified public DNS now resolves `*.nazar.studio` through `eu1.netbird.services` on Cloudflare, Google, and Quad9.
- Revoked the exposed NetBird API token after completing the configuration changes.

## 2026-05-11 — Zellij no longer auto-starts on nazar shell login

- Removed the root `.bashrc` auto-attach hook so `netbird ssh root@nazar` opens a plain shell by default.
- Kept Zellij installed for manual use with `zellij attach --create nazar`.
- Updated current access docs to describe Zellij as optional/manual.

## 2026-05-10 — NixOS fleet and Forgejo Git VM rebuild

- Installed Nix 2.34.7 multi-user on the Debian/Proxmox host for flake evaluation/build tooling only.
- Added the initial NixOS VM fleet flake under `flake.nix` and `nix/`.
- Added common NixOS modules for Proxmox guests, networking, SSH/firewall defaults, NetBird, sops-nix scaffolding, and Forgejo.
- Rebuilt VM 101 from legacy Debian/Docker Gogs to NixOS + Forgejo using the generated `.#git-qcow2` image.
- Preserved the external Git contract: `http://git.nazar.studio/` and `ssh://git@git.nazar.studio:10022/nazar/nazar.git`.
- Created fresh Forgejo admin/repo state and pushed this repository to the new Forgejo remote.
- Replaced the host SSH proxy unit with `git-ssh-proxy.service`.
- Created Proxmox backup job `git-daily` for VM 101, daily 03:20, zstd, keep-last=7.
- Completed a manual post-rebuild VM 101 backup: `/var/lib/vz/dump/vzdump-qemu-101-2026_05_10-21_33_33.vma.zst`.
- Enrolled the Git VM into NetBird as `git.netbird.cloud` / `100.124.135.247`.
- Added VM 110 (`minecraft`) to the same NixOS fleet flake as a declarative PaperMC server for `mc.balaur.org`, including checked-in Proxmox public-forward service scaffolding and runbook.
- Created and started VM 110, enabled `minecraft-public-forward.service` for public TCP/25565 forwarding to `10.10.10.30`, and created Proxmox backup job `minecraft-daily`, daily 03:40, zstd, keep-last=7.
- Upgraded VM 110 declaratively to PaperMC `26.1.2-62` with OpenJDK 25 after PaperMC's latest stable release required Java 25+, and verified `mc.balaur.org` reports online publicly.
- Added declarative PaperMC plugins for VM 110: SimpleVoiceChat, ToolStats, squaremap, AxGraves, and SimpleTPA; extended public forwarding for Simple Voice Chat UDP `24454`.
- Made `Cicorrel` the declarative Minecraft operator/admin for VM 110 with permission level 4.
- Removed AxGraves from VM 110 and declared `keepInventory = true` so players keep items on death.
- Declared Minecraft world seed `298649991203052898` for VM 110; this applies to newly generated worlds.
- Backed up and reset VM 110's generated world so seed `298649991203052898` is active; backup stored at `/var/backups/minecraft/world-reset-20260510T213558Z.tar.zst`.
- Rotated the Forgejo admin password after the initial password was exposed in chat; the new password is stored only in `/root/forgejo-admin-credentials.txt`.

## 2026-05-09 — Initial Proxmox installation

- Installed Debian 13 Trixie via Hetzner Robot Rescue `installimage`.
- Configured 2x NVMe disks as Linux software RAID1:
  - `/dev/md0` swap
  - `/dev/md1` `/boot`
  - `/dev/md2` `/`
- Added Proxmox VE 9 no-subscription repository.
- Installed Proxmox kernel `7.0.2-2-pve`.
- Installed Proxmox VE packages.
- Confirmed host boots into Proxmox kernel.
- Fixed BIOS GRUB installation by installing `grub-pc` and installing GRUB to both NVMe disks:

```bash
grub-install /dev/nvme0n1
grub-install /dev/nvme1n1
update-grub
```

- Removed Debian kernels and `os-prober` after Proxmox kernel was confirmed working.
- Configured Proxmox local storage at `/var/lib/vz`.
- Configured private NAT bridge `vmbr1`:

```text
vmbr1 = 10.10.10.1/24
VM subnet = 10.10.10.0/24
```

- Enabled IPv4/IPv6 forwarding.
- Added NAT masquerade rule for VM outbound internet.
- Disabled Proxmox enterprise APT repo and kept free no-subscription repo enabled.

## 2026-05-09 — SSH key handoff

- Created local SSH key:

```text
~/.ssh/ownloom-proxmox-root
```

- Added its public key to Proxmox root authorized keys.
- Confirmed SSH login works using the new key.
- Removed temporary setup SSH key `pi-temp-proxmox-setup` from the server.
- Deleted the local temporary setup key from `/tmp`.

## 2026-05-09 — NetBird preparation

- Enabled NetBird on local NixOS via `/etc/nixos/configuration.nix`:

```nix
services.netbird = {
  enable = true;
  ui.enable = true;
};
```

- Applied NixOS config with `nixos-rebuild switch`.
- Confirmed local NetBird is connected:

```text
Local NetBird IP: 100.124.32.110/16
Local NetBird FQDN: nixos-32-110.netbird.cloud
```

- Installed NetBird package on Proxmox host from the official NetBird Debian APT repository.
- Joined Proxmox host to NetBird using a temporary setup-key file.
- Confirmed Proxmox NetBird status:

```text
FQDN: ownloom-proxmox.netbird.cloud
NetBird IP: 100.124.39.100/16
Status: Connected
```

- Confirmed Proxmox UI works over NetBird:

```text
https://100.124.39.100:8006
```

- Confirmed SSH over NetBird works:

```bash
ssh ownloom-proxmox-nb
```

## 2026-05-09 — Hardening applied

- User confirmed Proxmox UI works over NetBird and enabled 2FA.
- Disabled SSH password login with `/etc/ssh/sshd_config.d/99-ownloom-hardening.conf`.
- Kept SSH key login enabled for:

```bash
ssh ownloom-proxmox-root
ssh ownloom-proxmox-nb
```

- Added host-side public interface lock-down for admin ports on `enp0s31f6`:

```text
TCP 8006
TCP 3128
TCP 3389
TCP 5900-5999
```

- Public Proxmox UI is now blocked.
- Proxmox UI over NetBird still works:

```text
https://100.124.39.100:8006
```

- Confirmed password SSH is rejected.

## 2026-05-10 — NixOS unstable VM prepared

- Fixed Hetzner Robot stateless firewall egress by adding incoming return rules for ephemeral ports.
- Confirmed host outbound internet works:

```text
HTTPS: OK
NixOS ISO URL: OK
apt update: OK
```

- Installed `dnsmasq-base` and created DHCP service for `vmbr1`:

```text
ownloom-vm-dhcp.service
DHCP range: 10.10.10.100-10.10.10.199
```

- Downloaded NixOS unstable minimal ISO:

```text
/var/lib/vz/template/iso/nixos-unstable-minimal-x86_64-linux.iso
SHA256: 45d793314903d9aab7b7659319ead334213fb506138970f7a52c70dc18c338f0
```

- Created VM:

```text
VM ID: 100
Name: nixos-unstable-01
CPU: 4 vCPU, host CPU
RAM: 16 GiB
Disk: 100 GiB
Network: vmbr1
DHCP reservation: 10.10.10.20
```

- Started VM into NixOS minimal installer ISO.
- Installed NixOS to the VM disk with UEFI/systemd-boot.
- Changed VM resources to 6 vCPU, 16 GiB RAM, 100 GiB disk.
- Detached ISO and set boot order to disk.
- Confirmed SSH works:

```bash
ssh ownloom-nixos-01
```

- Confirmed QEMU guest agent works:

```bash
qm agent 100 ping
```

- NetBird is installed in the VM and joined to the tailnet.
- Confirmed direct NetBird SSH works:

```bash
ssh ownloom-nixos-01
```

- VM NetBird identity:

```text
FQDN: nixos-unstable-01.netbird.cloud
NetBird IP: 100.124.2.197/16
```

## 2026-05-10 — Naming cleanup

- Renamed Proxmox host/node from `ownloom-vps` to `proxmox-hetzner`.
- Moved VM config from old Proxmox node path to:

```text
/etc/pve/nodes/proxmox-hetzner/qemu-server/100.conf
```

- Regenerated Proxmox node certificates.
- Renamed VM 100 from `nixos-unstable-01` to `ownloom` in Proxmox.
- Renamed NixOS guest hostname to `ownloom`.
- Renamed NixOS flake output to:

```text
nixosConfigurations.ownloom
```

- Updated local SSH aliases:

```bash
ssh proxmox-hetzner
ssh proxmox-hetzner-public
ssh ownloom
ssh ownloom-nat
```

- Renamed local documentation folder from `ownloom-vps/` to `proxmox-hetzner/`.

Note: NetBird dashboard/FQDN labels may still show original peer registration names until manually renamed in the NetBird dashboard.

## 2026-05-10 — NetBird dashboard names aligned

NetBird peer labels/FQDNs now match the intended names:

```text
proxmox-hetzner.netbird.cloud -> 100.124.39.100
ownloom.netbird.cloud         -> 100.124.2.197
evo-x1.netbird.cloud          -> 100.124.32.110
```

Verified local DNS resolution for the Proxmox and VM FQDNs.

## 2026-05-10 — NetBird setup keys revoked

User confirmed the temporary NetBird setup keys used for provisioning were revoked/deleted in the NetBird dashboard.

## 2026-05-10 — Private domain records attached

Added and verified Hetzner DNS A records for NetBird/private access:

```text
pve.ownloom.com -> 100.124.39.100
vm.ownloom.com  -> 100.124.2.197
```

Verified via local resolver, Cloudflare `1.1.1.1`, and Google `8.8.8.8`.
Also verified:

```text
https://pve.ownloom.com:8006 -> HTTP 200 over NetBird
ssh root@vm.ownloom.com      -> ownloom VM over NetBird
```

## 2026-05-10 — Certificate status checked

Verified `https://pve.ownloom.com:8006` connects over NetBird, but normal TLS verification still fails because Proxmox is serving its self-signed node certificate.

Current certificate status:

```text
Subject/CN: proxmox-hetzner
Issuer: Proxmox Virtual Environment internal CA
SANs: localhost, public IPv6, proxmox-hetzner
Missing SAN: pve.ownloom.com
```

Next certificate step remains: configure Proxmox ACME DNS-01 for `pve.ownloom.com`.

## 2026-05-10 — Proxmox ACME DNS plugin configured

Created/verified ACME setup progress for trusted Proxmox UI certificate:

```text
ACME account: default
DNS plugin: hetznercloud-ownloom
DNS API: hetznercloud
Validation delay: 120 seconds
Target certificate domain: pve.ownloom.com
```

The Hetzner Console API token is stored in Proxmox plugin configuration and is intentionally not documented here.

Current state after this step:

```text
ACME account/plugin: configured
Proxmox certificate: still self-signed
Next action: add ACME domain pve.ownloom.com and order certificate
```

## 2026-05-10 — Proxmox Let's Encrypt certificate installed

Ordered and installed Proxmox ACME certificate for:

```text
pve.ownloom.com
```

Verified from a NetBird-connected client:

```text
https://pve.ownloom.com:8006 -> HTTP 200
TLS verification: OK
Subject/CN: pve.ownloom.com
Issuer: Let's Encrypt R13
SAN: pve.ownloom.com
Valid until: 2026-08-08
```

Proxmox shows the custom web UI certificate as:

```text
pveproxy-ssl.pem
```

## 2026-05-10 — Domain and TLS runbook consolidated

Created consolidated documentation for the private domain and trusted TLS setup:

```text
runbooks/DOMAIN_AND_TLS_SETUP.md
```

This explains:

- A records for `pve.ownloom.com` and `vm.ownloom.com`;
- NetBird overlay IP usage;
- why DNS-01 ACME was used;
- Hetzner Console API token purpose;
- Proxmox ACME account/plugin/domain configuration;
- Let's Encrypt certificate result;
- renewal and verification notes.

## 2026-05-10 — Baseline local VM backup created

Created a one-time local snapshot backup of VM 100 (`ownloom`) after domain/TLS setup.

```text
Mode: snapshot
Compression: zstd
Storage: local
Result: OK
Backup archive: /var/lib/vz/dump/vzdump-qemu-100-2026_05_10-13_29_41.vma.zst
Size: ~849 MiB
```

Documented in:

```text
runbooks/BACKUPS.md
```

## 2026-05-10 — Scheduled local VM backup configured

Configured a Proxmox scheduled backup job for VM 100 (`ownloom`):

```text
Job ID: ownloom-daily-local
Schedule: daily at 02:30
Mode: snapshot
Compression: zstd
Storage: local
Retention: keep-last=3
Scheduler: pvescheduler active/enabled
```

This is a local safety-net backup only. Off-host backups are still required for disaster recovery.

## 2026-05-10 — Proxmox host renamed to nazar

Renamed Proxmox host/node:

```text
proxmox-hetzner -> nazar
```

Actions performed:

- Cleanly shut down VM 100 (`ownloom`).
- Updated `/etc/hostname`, `/etc/hosts`, mailname/Postfix hostname references.
- Rebooted the Proxmox host.
- Moved VM config to:

```text
/etc/pve/nodes/nazar/qemu-server/100.conf
```

- Removed stale old Proxmox node directory.
- Regenerated Proxmox node certificates with `pvecm updatecerts --force`.
- Preserved the Let's Encrypt Proxmox UI certificate for `pve.ownloom.com`.
- Reconnected NetBird with hostname `nazar`.
- Restarted VM 100.
- Renamed local documentation folder:

```text
proxmox-hetzner/ -> nazar/
```

- Added immediate local SSH aliases in `~/.ssh/config`:

```text
nazar
nazar-public
```

Compatibility aliases are still present:

```text
proxmox-hetzner
proxmox-hetzner-public
```

Verified:

```text
Host/node: nazar
NetBird FQDN: nazar.netbird.cloud
NetBird IP: 100.124.39.100
Proxmox UI: https://pve.ownloom.com:8006 -> HTTP 200, trusted TLS
VM 100: ownloom running
QEMU guest agent: OK
Scheduled backup job: ownloom-daily-local still configured
Public Proxmox UI: blocked
```

## 2026-05-10 — NetBird ACLs configured

Configured initial least-privilege NetBird access policies:

```text
admins-to-proxmox
  Source: admins
  Destination: proxmox-hosts
  Protocol: TCP
  Ports: 22, 8006

admins-to-vms
  Source: admins
  Destination: vms
  Protocol: TCP
  Ports: 22
```

Expected group membership:

```text
admins: EVO-X1, future admin laptop/phone
proxmox-hosts: nazar
vms: ownloom
```

Verified from `EVO-X1`:

```text
ssh nazar -> OK
https://pve.ownloom.com:8006 -> HTTP 200
ssh ownloom -> OK
```

## 2026-05-10 — Notifications deferred

Reviewed notification/email state:

```text
Proxmox default notifications: mail-to-root
Postfix: local-only
SMART alerts: root
mdadm RAID alerts: root
```

Decision: defer outbound SMTP/notification setup until a dedicated alert sender account/provider is chosen. Personal email may be used as recipient, but a dedicated sender account is preferred.

## 2026-05-10 — Pi installed on nazar

Installed Pi coding agent on the Proxmox host `nazar`.

```text
Node.js: v20.19.2
npm: 9.2.0
Pi: 0.73.1
Pi path: /usr/local/bin/pi
Install method: npm global package
```

No provider login/API key was configured during installation.

Usage:

```bash
ssh nazar
pi
```

Documented in:

```text
runbooks/PI_ON_NAZAR.md
```

## 2026-05-10 — Future hardening roadmap added

Added a forward-looking hardening and standardization roadmap:

```text
security/HARDENING_ROADMAP.md
```

The roadmap covers:

- off-host encrypted backups and restore tests;
- monitoring/alerting;
- named admin users and SSH access model;
- GitHub private repo/deploy key strategy;
- NetBird posture and default policy cleanup;
- Proxmox firewall standardization;
- patch cadence and vulnerability management;
- audit/logging evidence;
- secrets management;
- reusable NixOS VM templates;
- recovery exercises.

## 2026-05-10 — Hetzner Rescue drill completed

Completed the first break-glass Hetzner Rescue drill for `nazar`.

Verified:

- Rescue SSH login worked.
- RAID arrays `/dev/md0`, `/dev/md1`, and `/dev/md2` assembled and showed `[UU]`.
- Installed system mounted with `/dev/md2` on `/mnt` and `/dev/md1` on `/mnt/boot`.
- Chroot worked.
- Important recovery finding: `/etc/pve` is not plain disk files in Rescue/chroot; start Proxmox cluster filesystem in local mode with:

```bash
hostname nazar
chroot /mnt /bin/bash
pmxcfs -l
```

After `pmxcfs -l`, verified access to:

```text
/etc/pve/firewall/cluster.fw
/etc/pve/local/host.fw
/etc/pve/priv/authorized_keys
```

Also verified that `/root/.ssh/authorized_keys` points to `/etc/pve/priv/authorized_keys` on Proxmox.

A temporary rescue SSH key was added and removed during the drill. Normal boot validation succeeded: NetBird reconnected, Proxmox UI returned HTTP 200 over `pve.ownloom.com`, RAID remained healthy, and Proxmox firewall was enabled/running.

Documented in:

```text
runbooks/RESCUE_DRILL.md
runbooks/RECOVERY_RUNBOOK.md
.pi/skills/nazar-rescue/SKILL.md
```

## 2026-05-10 — Public SSH disabled after Rescue drill

After the successful Rescue drill, removed the public NIC SSH allow rule from `/etc/pve/local/host.fw`.

Removed:

```text
IN SSH(ACCEPT) -i enp0s31f6
```

Kept:

```text
IN ACCEPT -i enp0s31f6 -p udp -dport 51820
IN SSH(ACCEPT) -i wt0
IN ACCEPT -i wt0 -p tcp -dport 8006
IN ACCEPT -i wt0 -p tcp -dport 3128
IN ACCEPT -i wt0 -p tcp -dport 53
IN ACCEPT -i wt0 -p udp -dport 53
IN ACCEPT -i vmbr1 -p udp -dport 67
```

Backup before changing firewall:

```text
/etc/pve/local/host.fw.pre-remove-public-ssh-20260510T135534Z
```

Validation:

```text
Public SSH simulation -> ACTION: DROP
ssh nazar-public -> expected timeout
NetBird/Proxmox UI -> HTTP 200
```

Current intended access model:

```text
Primary shell:    netbird ssh root@nazar
Proxmox UI:       https://pve.ownloom.com:8006
Break-glass:      Hetzner Rescue
Public SSH:       disabled
```

## 2026-05-10 — NetBird SSH enabled for nazar

Enabled NetBird SSH server for the Proxmox host `nazar`.

Local NetBird client state on `nazar`:

```text
NetBird daemon: 0.70.5
SSH Server: Enabled
ServerSSHAllowed: true
EnableSSHRoot: true
EnableSSHSFTP: false
EnableSSHLocalPortForwarding: false
EnableSSHRemotePortForwarding: false
```

Primary shell command:

```bash
netbird ssh root@nazar
```

Notes:

- NetBird SSH is distinct from regular OpenSSH.
- It uses NetBird/OIDC identity and policy mapping.
- Do not enter a root password into unexpected prompts.
- If plain `ssh nazar` behaves differently, prefer `netbird ssh root@nazar` unless intentionally restoring traditional OpenSSH-over-NetBird behavior.

## 2026-05-10 — ownloom restored from local backup during verification

During verification after the Rescue/NetBird SSH work, VM 100 config/disk was found missing from Proxmox (`qm list` empty and `/etc/pve/nodes/nazar/qemu-server/100.conf` absent). Restored VM 100 from the pre-rescue local backup:

```bash
qmrestore /var/lib/vz/dump/vzdump-qemu-100-2026_05_10-15_25_50.vma.zst 100 --storage local
qm set 100 --onboot 1
qm start 100
```

Validation after restore:

```text
VM 100: running
Name: ownloom
onboot: 1
QEMU guest agent: OK
NAT IPv4: 10.10.10.20/24
```

This proved same-host local VM restore works, but off-host backup and alternate-ID restore testing remain required.

## 2026-05-10 — Fresh OwnLoom VM shell created

Researched NixOS-on-Proxmox installation approaches. Best-practice direction:

- use a VM rather than LXC for OwnLoom isolation;
- use q35/OVMF, VirtIO disk/network, host CPU type, and QEMU guest agent;
- use a Proxmox-specific NixOS host profile rather than installing the existing `ownloom-vps` profile unchanged;
- keep OwnLoom private/loopback-first until a public exposure plan is chosen.

Verified current NixOS ISO is the latest unstable/26.05 pre-release available from the channel:

```text
nixos-minimal-26.05pre992384.549bd84d6279-x86_64-linux.iso
sha256: 45d793314903d9aab7b7659319ead334213fb506138970f7a52c70dc18c338f0
```

Took a final local backup of the previous VM 100:

```text
/var/lib/vz/dump/vzdump-qemu-100-2026_05_10-16_48_25.vma.zst
```

Then destroyed and recreated VM 100 as a fresh NixOS installer VM:

```text
VMID: 100
Name: ownloom
CPU: 5 vCPU, host CPU type
RAM: 32 GiB
Disk: 200 GiB qcow2
Firmware: OVMF/UEFI, q35
Network: virtio on vmbr1
MAC: BC:24:11:5D:1F:17
NAT IP: 10.10.10.20 via existing DHCP reservation
Boot: NixOS minimal ISO first, disk second
Autostart: disabled until installed and validated
```

Validation:

```text
VM status: running
DHCP: 10.10.10.20 assigned
Ping 10.10.10.20: OK
SSH port on installer: open, but no key/password installed yet
```

Next step: use Proxmox noVNC console to add an SSH key to the NixOS installer environment, then install NixOS and deploy a Proxmox-specific OwnLoom host profile.

## 2026-05-10 — OwnLoom paused; Proxmox layer focus

Paused OwnLoom application installation to focus on hardening the Nazar Proxmox layer.

Stopped the fresh NixOS installer VM 100 and kept autostart disabled:

```text
VMID: 100
Name: ownloom
Status: stopped
Autostart: disabled
Resources: 5 vCPU, 32 GiB RAM, 200 GiB disk
```

Created Proxmox local admin user:

```text
alex@pve
Role: Administrator on /
```

Password and TOTP enrollment are still interactive/manual next steps.

Checked Proxmox layer health:

```text
apt list --upgradable: none
pve-firewall: enabled/running
public SSH simulation: ACTION: DROP
netbird: connected
systemctl --failed: none
```

Removed stale `pi-temp-proxmox-setup` public key from `/etc/pve/priv/authorized_keys`; backup was saved as `/etc/pve/priv/authorized_keys.pre-remove-stale-pi-temp-<timestamp>`.

Added baseline runbook:

```text
runbooks/NAZAR_PROXMOX_BASELINE.md
```

## 2026-05-10 — Proxmox UI admin accounts verified

Confirmed both Proxmox UI accounts work with 2FA:

```text
alex@pve  — daily Proxmox admin, Administrator on /, TOTP enabled
root@pam  — break-glass Linux PAM admin, TOTP enabled
```

Daily use should prefer `alex@pve`; keep `root@pam` as break-glass only. Store both passwords and TOTP recovery material in the password manager.

## 2026-05-10 — Proxmox SMTP alerts configured

Configured Proxmox notification delivery through Brevo SMTP for Nazar alerts.

```text
Target: nazar-alerts
Type: SMTP
Server: smtp-relay.brevo.com
Port: 587
Mode: STARTTLS
From: alerts@nazar.help
Recipient: eucico@proton.me
Matcher: nazar-alerts-all -> nazar-alerts
Default mail-to-root matcher: disabled
```

Also set `root@pam` and `alex@pve` email metadata to the recipient address.

Test notification was sent with:

```bash
pvesh create /cluster/notifications/targets/nazar-alerts/test
```

SMTP key was entered interactively and is not documented in this repository.

## 2026-05-10 — Proxmox SMTP alert delivery confirmed

Confirmed the Proxmox SMTP test notification sent through `nazar-alerts` arrived at the Proton recipient inbox.

Documentation updated with alert status and validation commands:

```text
runbooks/ALERTS.md
runbooks/NAZAR_PROXMOX_BASELINE.md
security/HARDENING_ROADMAP.md
TODO.md
```

Remaining alert work: verify or integrate mdadm RAID and smartd SMART alerts, which currently still target local `root` mail paths.

## 2026-05-10 — RAID and SMART alerts routed through Proxmox SMTP

Extended Nazar alerting beyond Proxmox tasks/backups.

Added host alert bridge:

```text
/etc/pve/notification-templates/default/nazar-alert-*.hbs
/usr/local/sbin/nazar-proxmox-notify
/usr/local/sbin/nazar-mdadm-alert
/usr/local/sbin/nazar-smartd-alert
```

Updated RAID monitoring:

```text
/etc/mdadm/mdadm.conf
  #MAILADDR root
  PROGRAM /usr/local/sbin/nazar-mdadm-alert
```

Updated SMART monitoring:

```text
/etc/smartd.conf
  DEVICESCAN -d removable -n standby -m <nomailer> -M exec /usr/local/sbin/nazar-smartd-alert
```

Restarted and verified services:

```text
mdmonitor.service       active/running
smartmontools.service   active/running
systemctl --failed      0 failed units
```

Safe test invocations succeeded:

```bash
mdadm --monitor --oneshot --test --program /usr/local/sbin/nazar-mdadm-alert /dev/md2
smartd -q onecheck -n -c <temp config with -M test>
```

Both tests reported delivery through Proxmox target `nazar-alerts`; recipient inbox confirmation should be checked.

## 2026-05-10 — ACME, disk usage, and boot alerts added

Added remaining local alert checks through the existing `nazar-alerts` Proxmox SMTP path.

New scripts:

```text
/usr/local/sbin/nazar-acme-cert-check
/usr/local/sbin/nazar-disk-usage-check
/usr/local/sbin/nazar-boot-alert
```

New systemd units:

```text
nazar-acme-cert-check.timer    daily certificate-expiry check
nazar-disk-usage-check.timer   hourly disk-usage check
nazar-boot-alert.service       boot/reboot notice
```

Default thresholds:

```text
ACME certificate expiry: warning <= 21 days, critical <= 7 days
Disk usage: warning >= 80%, critical >= 90%
```

Forced test alerts succeeded:

```bash
NAZAR_DISK_WARN_PERCENT=1 NAZAR_DISK_CRIT_PERCENT=99 /usr/local/sbin/nazar-disk-usage-check
NAZAR_CERT_WARN_DAYS=365 NAZAR_CERT_CRIT_DAYS=1 /usr/local/sbin/nazar-acme-cert-check
systemctl start nazar-boot-alert.service
```

External uptime monitoring is still a future task because a host cannot reliably detect its own complete downtime while it is unreachable.

## 2026-05-10 — External uptime monitoring deferred

Decided to skip true external uptime monitoring for now. Nazar still sends a boot/reboot notice through `nazar-boot-alert.service`, but no third-party/outside monitor will be configured at this stage.

## 2026-05-10 — Private Gogs Git server added

Added a NetBird-only private Gogs Git server in VM 101.

```text
VM ID: 101
VM name: gogs
NAT IP: 10.10.10.21
Web: http://git.nazar.studio/
Git SSH: ssh://git@git.nazar.studio:10022/nazar/nazar.git
Repo: nazar/nazar
```

Implementation notes:

- Created Debian 13 cloud-image VM on `vmbr1`.
- Added DHCP reservation for `gogs -> 10.10.10.21`.
- Installed Docker in the VM and ran `gogs/gogs:next-0.14.2`.
- Configured Gogs with SQLite, sign-in required, registration disabled, forced private repositories, and default branch `main`.
- Created admin user `nazar` and private repo `nazar/nazar`.
- Added Proxmox host push key and `alex@yoga` user SSH key.
- Added local Git remote `nazar` and pushed committed `main` history.
- Deleted temporary API bootstrap tokens after setup.

Credentials are stored root-only on the Proxmox host:

```text
/root/gogs-admin-credentials.txt
```

## 2026-05-10 — `nazar.studio` private DNS and NetBird-only vhosts added

Configured private DNS names for NetBird-only access:

```text
git.nazar.studio -> 100.124.39.100
pve.nazar.studio -> 100.124.39.100
```

Replaced the initial simple Gogs HTTP proxy with nginx virtual hosts bound only to the NetBird IP:

```text
100.124.39.100:80  -> git.nazar.studio -> Gogs VM 101
100.124.39.100:80  -> pve.nazar.studio redirect to HTTPS
100.124.39.100:443 -> pve.nazar.studio -> Proxmox pveproxy on 127.0.0.1:8006
```

Kept Gogs Git SSH as a NetBird-only `socat` proxy:

```text
100.124.39.100:10022 -> 10.10.10.21:10022
```

Added Proxmox firewall allows on `wt0` for TCP `80`, `443`, and `10022`. No public Hetzner interface exposure was added.

`pve.nazar.studio` currently uses a self-signed certificate:

```text
/etc/ssl/certs/pve.nazar.studio.crt
/etc/ssl/private/pve.nazar.studio.key
```

This is intentional for now. Plain HTTP caused Proxmox login errors like `401: No ticket` because Proxmox uses secure auth cookies, so HTTP now redirects to HTTPS.

The existing trusted Let's Encrypt certificate for `pve.ownloom.com` remains intact and unchanged.

## 2026-05-10 — Gogs backup job added

Added scheduled local Proxmox backup for VM 101:

```text
Job ID: gogs-daily
VM ID: 101
Schedule: daily at 03:20
Mode: snapshot
Compression: zstd
Storage: local
Retention: keep-last=7
Notification mode: notification-system
```

Created initial manual backup successfully:

```text
/var/lib/vz/dump/vzdump-qemu-101-2026_05_10-18_38_46.vma.zst
Archive size: ~683 MiB
Result: OK
```

## 2026-05-10 — Backup/docs cleanup and obsolete Gogs HTTP proxy removed

Updated current docs after live audit:

- `runbooks/BACKUPS.md` now reflects actual backup jobs: only `gogs-daily` is scheduled; VM 100 is a stopped installer shell with historical manual backups.
- Restore-test examples now use disposable VM ID `900`, not live VM IDs.
- Interim off-host backup decision: manually download important backup archives from `/var/lib/vz/dump/` to the desktop PC.
- Gogs remains the canonical infra Git remote for now; no GitHub mirror is planned at this stage.
- Proxmox subscription decision: no subscription for now; continue `pve-no-subscription` with enterprise repo disabled.

Removed obsolete failed unit that had been superseded by nginx:

```text
/etc/systemd/system/gogs-http-proxy.service
```

Validation after removal:

```text
systemctl --failed: 0 failed units
nginx.service: active
gogs-ssh-proxy.service: active
git.nazar.studio over NetBird/nginx: HTTP 302 to /user/login
pve.nazar.studio over NetBird/nginx: reachable
```
