# Backups Runbook

## Current state

Backup storage currently configured in Proxmox:

```text
local -> /var/lib/vz
```

This storage is on the host's RAID1 root filesystem. It is useful for quick rollback from VM mistakes, but it is not disaster recovery by itself.

Current backup jobs in `/etc/pve/jobs.cfg`:

```text
git-daily       -> VM 101, daily 03:20, snapshot, zstd, keep-last=7, local storage
minecraft-daily -> VM 110, daily 03:40, snapshot, zstd, keep-last=7, local storage
```

There is currently **no scheduled backup job for VM 120 or VM 121**. Add backup jobs and prove restore before migrating real personal DAV/wiki data.

## Manual off-host copy plan

Decision for now: off-host backup will be manual.

After important changes, manually download the relevant backup archive(s) from `/var/lib/vz/dump/` to the desktop PC and keep them outside this server. This is the current off-host copy path until an automated encrypted target is chosen later.

Recommended minimum manual routine:

1. Before high-risk Proxmox/VM changes, create or confirm a fresh local backup.
2. Download the `.vma.zst`, `.notes`, and `.log` files to the desktop PC.
3. Confirm the downloaded archive size matches the server copy.
4. Keep at least the latest important VM 101 (`git`) backup and any final VM 100 pre-recreate backup on the desktop.
5. Do not treat manual downloads as a full 3-2-1 strategy; they are an interim safety measure.

Example listing command:

```bash
find /var/lib/vz/dump -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %12s %f\n' | sort
```

Example download from an admin desktop over NetBird/OpenSSH, adjust destination path as needed:

```bash
scp root@nazar:/var/lib/vz/dump/vzdump-qemu-101-YYYY_MM_DD-HH_MM_SS.vma.zst ~/Backups/nazar/
scp root@nazar:/var/lib/vz/dump/vzdump-qemu-101-YYYY_MM_DD-HH_MM_SS.vma.zst.notes ~/Backups/nazar/
scp root@nazar:/var/lib/vz/dump/vzdump-qemu-101-YYYY_MM_DD-HH_MM_SS.log ~/Backups/nazar/
```

## What local backups protect against

Local Proxmox backups help recover from:

- accidental VM misconfiguration;
- bad OS/application rebuilds;
- accidental file deletion inside a VM;
- broken package/configuration experiments.

## What local backups do not protect against

Because local backups are stored on the same physical server, they do not protect against:

- total server loss;
- both disks failing;
- datacenter/provider/account issue;
- ransomware or destructive compromise of the Proxmox host;
- accidental deletion of both VM and local backups.

Manual desktop downloads partially reduce this risk, but automated encrypted off-host backups and restore tests remain the stronger long-term standard.

## VM 100 (`ownloom`) backup history

VM 100 is currently a stopped fresh NixOS installer shell:

```text
VM ID: 100
VM name: ownloom
Current disk: 200 GiB
Current status: stopped
Autostart: disabled
```

Historical local backups of the previous VM 100 exist:

```text
/var/lib/vz/dump/vzdump-qemu-100-2026_05_10-13_29_41.vma.zst
/var/lib/vz/dump/vzdump-qemu-100-2026_05_10-15_25_50.vma.zst
/var/lib/vz/dump/vzdump-qemu-100-2026_05_10-16_48_25.vma.zst
```

The final pre-recreate backup is:

```text
/var/lib/vz/dump/vzdump-qemu-100-2026_05_10-16_48_25.vma.zst
Result: OK
Archive size: ~864 MiB
Backed-up disk state: previous 100 GiB VM disk, before VM 100 was recreated as a fresh 200 GiB installer shell
```

Do not destroy these old VM 100 backups until a replacement OwnLoom install exists and the important backup archives have been manually copied off-host.

## VM 101 (`git`) backups

VM 101 is the private NixOS/Forgejo Git server and currently has the only scheduled Proxmox backup job.

Initial manual backup:

```text
/var/lib/vz/dump/vzdump-qemu-101-2026_05_10-18_38_46.vma.zst
/var/lib/vz/dump/vzdump-qemu-101-2026_05_10-18_38_46.vma.zst.notes
/var/lib/vz/dump/vzdump-qemu-101-2026_05_10-18_38_46.log
Result: OK
Archive size: ~683 MiB
```

Manual command used:

```bash
vzdump 101 \
  --storage local \
  --mode snapshot \
  --compress zstd \
  --notes-template 'gogs private git server initial backup' \
  --remove 0
```

Post-rebuild manual backup:

```text
/var/lib/vz/dump/vzdump-qemu-101-2026_05_10-21_33_33.vma.zst
/var/lib/vz/dump/vzdump-qemu-101-2026_05_10-21_33_33.vma.zst.notes
/var/lib/vz/dump/vzdump-qemu-101-2026_05_10-21_33_33.log
Result: OK
Archive size: ~668 MiB
Notes: manual post-rebuild Forgejo Git VM backup
```

The old `gogs-daily` scheduled job was removed when VM 101 was intentionally destroyed/recreated with `qm destroy 101 --purge`. A new scheduled local job is configured for the rebuilt Forgejo VM:

```text
Job ID: git-daily
VM ID: 101
Schedule: daily at 03:20
Mode: snapshot
Compression: zstd
Storage: local
Retention: keep-last=7
Notes template: {{guestname}} private git server
Notification mode: notification-system
```

Current job config:

```text
vzdump: git-daily
    comment Daily backup for private Forgejo Git VM
    schedule 03:20
    compress zstd
    enabled 1
    mode snapshot
    notes-template {{guestname}} private git server
    notification-mode notification-system
    prune-backups keep-last=7
    storage local
    vmid 101
```

## Restore test command

To inspect available backups in Proxmox UI:

```text
Datacenter/Node -> local -> Backups
```

CLI listing:

```bash
ls -lh /var/lib/vz/dump/
```

Restore to a disposable test VM ID, for example `900`:

```bash
qmrestore /var/lib/vz/dump/vzdump-qemu-101-YYYY_MM_DD-HH_MM_SS.vma.zst 900 --storage local
```

Do **not** restore a test backup onto VM ID `100` or `101` unless intentionally performing disaster recovery and willing to replace the current VM.

After testing, verify the restored VM boots, networking works, and the guest agent responds. Then destroy the disposable test VM when finished:

```bash
qm stop 900
qm destroy 900 --purge 1
```

## Restore evidence

During post-rescue verification on 2026-05-10, VM 100's Proxmox config/disk was missing. It was restored successfully from a local pre-rescue backup:

```bash
qmrestore /var/lib/vz/dump/vzdump-qemu-100-2026_05_10-15_25_50.vma.zst 100 --storage local
qm set 100 --onboot 1
qm start 100
qm agent 100 ping
```

Result:

```text
VM 100 restored as ownloom
onboot: 1
status: running
QEMU guest agent: OK
NAT IPv4: 10.10.10.20/24
```

This proved same-host local VM restore works. It does not replace manual off-host downloads or future alternate-ID restore tests.

## OwnLoom data backup gate

Before real personal data moves to VM 121 (`ownloom-data`), define and test backups for:

```text
/var/lib/radicale/collections
/var/lib/ownloom-data/webdav
```

Minimum gate: local Proxmox backup job for VM 121, manual off-host copy of the backup archive, and a restore test to a disposable VM ID such as `900`. Do not rely on the WebDAV cache on VM 120 as the canonical backup.

## Recommended next backup steps

1. Manually download important current backup archives to the desktop PC.
2. Perform and document a restore test to a disposable VM ID such as `900`.
3. Add VM 120/121 backup jobs before production OwnLoom migration, with VM 121 treated as personal-data critical.
4. Later, consider automated encrypted backups with Proxmox Backup Server, Hetzner Storage Box, restic/Borg, or S3-compatible storage.

## Repository split is not a runtime backup

The `minecraft`, `ownloom`, and `ownloom-data` repositories contain service code/config and runbooks only. They do not replace Proxmox VM backups, Minecraft world backups, OwnLoom wiki/data backups, or the existing `nazar/personal-wiki-backup` snapshot repository.

Keep the VM 120/121 backup gate in place before migrating real personal data: local Proxmox backup job, manual off-host copy, and restore test to a disposable VM ID.
