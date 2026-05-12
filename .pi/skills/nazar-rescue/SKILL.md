---
name: nazar-rescue
description: Break-glass recovery workflow for the Hetzner Proxmox host nazar. Use when Nazar/Proxmox/NetBird SSH is unreachable, when booted into Hetzner Rescue, or when a temporary SSH key is needed so Pi can inspect/fix the installed system and then remove the key.
---

# Nazar Rescue

This skill guides Pi through safe break-glass recovery for the Hetzner Proxmox host `nazar`.

Current intended access model:

```text
Primary shell:    netbird ssh root@nazar
Proxmox UI:       https://pve.nazar.studio/ over NetBird/private DNS
Public SSH:       disabled in normal boot by Proxmox firewall
Break-glass:      Hetzner Rescue on 167.235.12.22
```

Reference runbooks:

- `runbooks/RESCUE_DRILL.md`
- `runbooks/RECOVERY_RUNBOOK.md`
- `runbooks/PROXMOX_FIREWALL.md`
- `runbooks/NETBIRD_ACCESS.md`

## Safety rules

- Do not store private keys, passwords, Hetzner Rescue passwords, NetBird setup keys, or API tokens in the repo or transcript.
- Do not print private key contents.
- Do not make destructive disk, RAID, VM, or firewall changes without an explicit user checkpoint.
- Prefer non-destructive validation first.
- Public SSH is intentionally disabled in normal boot; do not re-enable it unless the user explicitly asks for rollback.
- In Rescue, remember that `/etc/pve` is not plain disk files. It requires `pmxcfs -l` inside the chroot.
- Remove any temporary SSH key that has marker `nazar-pi-rescue-` before finishing.

## Decide where Pi is running

Start by identifying the environment:

```bash
hostname || true
pwd || true
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS || true
cat /proc/mdstat 2>/dev/null || true
```

Common cases:

1. **Pi is running on the admin PC**: use SSH to connect to Rescue after the user adds a temporary key.
2. **Pi is running inside Hetzner Rescue**: execute Rescue commands directly.
3. **Pi is running on normal Nazar**: validate normal state; do not do Rescue-only mounting.

## Temporary SSH key handoff from admin PC

If Pi is on the admin PC and cannot connect to Rescue yet, ask the user to log in once with the Hetzner Rescue password and add a temporary public key.

Generate a temporary key on the admin PC:

```bash
ssh-keygen -t ed25519 -f /tmp/nazar-pi-rescue -N '' -C "nazar-pi-rescue-$(date -u +%Y%m%dT%H%M%SZ)"
cat /tmp/nazar-pi-rescue.pub
```

Ask the user to paste the printed public key line into this command in the Rescue password session:

```bash
install -d -m 700 /root/.ssh
printf '%s\n' 'PASTE_PUBLIC_KEY_LINE_HERE' >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

Then connect from the admin PC:

```bash
ssh -i /tmp/nazar-pi-rescue root@167.235.12.22
```

Do not use `sshpass`; do not ask the user to reveal the Rescue password.

## Rescue validation workflow

In Rescue, run:

```bash
set -euo pipefail
hostname
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
cat /proc/mdstat
mdadm --detail --scan || true
mdadm --assemble --scan || true
cat /proc/mdstat
```

Expected arrays:

```text
/dev/md0 swap
/dev/md1 /boot
/dev/md2 /
```

Mount installed system:

```bash
mountpoint -q /mnt || mount /dev/md2 /mnt
mountpoint -q /mnt/boot || mount /dev/md1 /mnt/boot
mountpoint -q /mnt/dev || mount --bind /dev /mnt/dev
mountpoint -q /mnt/proc || mount --bind /proc /mnt/proc
mountpoint -q /mnt/sys || mount --bind /sys /mnt/sys
mountpoint -q /mnt/run || mount --bind /run /mnt/run
```

Verify normal disk files:

```bash
ls /mnt
ls /mnt/root/nazar
sed -n '1,80p' /mnt/etc/ssh/sshd_config.d/99-ownloom-hardening.conf
```

## Access `/etc/pve` correctly

Inside Rescue, before chroot, set hostname to the installed node name:

```bash
hostname nazar
```

Then chroot and start pmxcfs local mode:

```bash
chroot /mnt /bin/bash
pmxcfs -l
```

Now inspect access-critical files:

```bash
cat /etc/hostname
ls -l /etc/pve/firewall/cluster.fw /etc/pve/local/host.fw /etc/pve/priv/authorized_keys
sed -n '1,120p' /etc/pve/firewall/cluster.fw
sed -n '1,180p' /etc/pve/local/host.fw
sed -n '1,20p' /etc/pve/priv/authorized_keys
```

Notes:

- `/root/.ssh/authorized_keys` points to `/etc/pve/priv/authorized_keys` on Proxmox.
- Use `/etc/pve/priv/authorized_keys` inside the chroot when editing installed Proxmox root keys.

## Common emergency fixes

Only apply these with explicit user approval.

### Disable native Proxmox firewall for rollback

Inside chroot after `pmxcfs -l`:

```bash
sed -i 's/^enable: 1$/enable: 0/' /etc/pve/firewall/cluster.fw /etc/pve/local/host.fw
```

This should make normal boot easier to access, but it also removes the native firewall until re-enabled.

### Add an installed-system temporary root SSH key

Inside chroot after `pmxcfs -l`:

```bash
cp -a /etc/pve/priv/authorized_keys /etc/pve/priv/authorized_keys.pre-pi-rescue-$(date -u +%Y%m%dT%H%M%SZ)
printf '%s\n' 'PASTE_PUBLIC_KEY_LINE_WITH_nazar-pi-rescue_MARKER' >> /etc/pve/priv/authorized_keys
chmod 600 /etc/pve/priv/authorized_keys
```

Only do this if the user wants temporary SSH into the installed normal system after reboot.

### Temporarily allow password SSH in normal boot

Inside chroot:

```bash
cat > /etc/ssh/sshd_config.d/99-recovery.conf <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
EOF
sshd -t
```

Remove as soon as recovery is complete:

```bash
rm -f /etc/ssh/sshd_config.d/99-recovery.conf
sshd -t
```

## Cleanup

Before finishing Rescue work, remove temporary keys marked for this workflow.

In the Rescue environment:

```bash
sed -i '/nazar-pi-rescue-/d' /root/.ssh/authorized_keys 2>/dev/null || true
```

Inside the installed-system chroot after `pmxcfs -l`, if an installed key was injected:

```bash
sed -i '/nazar-pi-rescue-/d' /etc/pve/priv/authorized_keys
```

On the admin PC:

```bash
shred -u /tmp/nazar-pi-rescue 2>/dev/null || rm -f /tmp/nazar-pi-rescue
rm -f /tmp/nazar-pi-rescue.pub
```

Exit and reboot:

```bash
exit
umount -R /mnt
sync
reboot
```

## Post-normal-boot validation

After booting the installed system again:

```bash
netbird ssh root@nazar
curl -k --connect-timeout 5 https://pve.nazar.studio/
```

On `nazar`:

```bash
hostname
pveversion
pve-firewall status
netbird status
qm status 101
qm agent 101 ping
cat /proc/mdstat
```

Expected:

- NetBird connected as `nazar.netbird.cloud` / `100.124.39.100`.
- NetBird SSH enabled for `nazar`.
- Public SSH remains disabled unless intentionally rolled back.
- Proxmox UI returns HTTP 200 over NetBird/private DNS.
- RAID arrays show `[UU]`.
- Current expected VMs are in their documented states; at minimum VM 101 (`git`) is running and its QEMU guest agent responds.
