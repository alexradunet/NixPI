# Hetzner Rescue Drill Checklist

Purpose: rehearse and document the break-glass path for `nazar` now that normal public SSH is disabled.

Current access model:

```text
Primary shell:    netbird ssh root@nazar
Proxmox UI:       https://pve.nazar.studio/ over NetBird/private DNS
Public SSH:       disabled by Proxmox firewall
Break-glass:      Hetzner Rescue
```

This drill was completed successfully on 2026-05-10. It verified that we can boot Hetzner Rescue, assemble RAID, mount/chroot into the installed Proxmox system, access `/etc/pve` via `pmxcfs -l`, add/remove a temporary SSH key, and return to normal boot.

## Known-good disk layout

```text
/dev/md0 swap
/dev/md1 /boot
/dev/md2 /
```

Safety backup before first drill:

```text
/var/lib/vz/dump/vzdump-qemu-100-2026_05_10-15_25_50.vma.zst
```

## 1. Boot Hetzner Rescue

This reboots the server and temporarily stops Proxmox/VMs.

1. Open Hetzner Robot.
2. Go to `Server -> Rescue`.
3. Select `Linux 64-bit`.
4. Add/select your SSH key if Robot offers that option, otherwise save the temporary Rescue password.
5. Activate Rescue.
6. Reset/reboot the server.

Then connect:

```bash
ssh root@167.235.12.22
```

## 2. Inspect and assemble RAID in Rescue

```bash
set -euo pipefail
hostname
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
cat /proc/mdstat
mdadm --detail --scan || true
mdadm --assemble --scan || true
cat /proc/mdstat
```

Expected: `md0`, `md1`, and `md2` active with `[UU]`.

## 3. Mount installed Proxmox system

```bash
mount /dev/md2 /mnt
mount /dev/md1 /mnt/boot
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mount --bind /run /mnt/run
```

Verify ordinary disk files:

```bash
ls /mnt
ls /mnt/root/nazar
sed -n '1,80p' /mnt/etc/ssh/sshd_config.d/99-ownloom-hardening.conf
```

Important: `/etc/pve` is not plain disk files. It is the Proxmox cluster filesystem backed by `pmxcfs`; use the next section before inspecting or editing `/etc/pve` files.

## 4. Chroot and start pmxcfs local mode

```bash
hostname nazar
chroot /mnt /bin/bash
pmxcfs -l
```

Now these are accessible inside the chroot:

```text
/etc/pve/firewall/cluster.fw
/etc/pve/local/host.fw
/etc/pve/priv/authorized_keys
/root/.ssh/authorized_keys -> /etc/pve/priv/authorized_keys
```

Verify:

```bash
cat /etc/hostname
ls -l /etc/pve/firewall/cluster.fw /etc/pve/local/host.fw /etc/pve/priv/authorized_keys
sed -n '1,120p' /etc/pve/firewall/cluster.fw
sed -n '1,160p' /etc/pve/local/host.fw
sed -n '1,20p' /etc/pve/priv/authorized_keys
```

## 5. Temporary SSH key workflow for Pi-assisted recovery

Use this when you want to let Pi connect to the Rescue system with a temporary key after you log in once with the Hetzner Rescue password.

On your admin PC, create a temporary key:

```bash
ssh-keygen -t ed25519 -f /tmp/nazar-pi-rescue -N '' -C "nazar-pi-rescue-$(date -u +%Y%m%dT%H%M%SZ)"
cat /tmp/nazar-pi-rescue.pub
```

In the Rescue password SSH session, add the public key to the Rescue environment:

```bash
install -d -m 700 /root/.ssh
printf '%s\n' 'PASTE_PUBLIC_KEY_LINE_HERE' >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

Then Pi or an admin can connect from the PC without the Rescue password:

```bash
ssh -i /tmp/nazar-pi-rescue root@167.235.12.22
```

Cleanup before leaving Rescue:

```bash
sed -i '/nazar-pi-rescue-/d' /root/.ssh/authorized_keys
```

On the admin PC, delete the temporary private key after use:

```bash
shred -u /tmp/nazar-pi-rescue 2>/dev/null || rm -f /tmp/nazar-pi-rescue
rm -f /tmp/nazar-pi-rescue.pub
```

If a temporary key was intentionally injected into the installed Proxmox key store, remove it from inside the chroot after `pmxcfs -l`:

```bash
sed -i '/nazar-pi-rescue-/d' /etc/pve/priv/authorized_keys
```

A project Pi skill for this workflow exists at:

```text
.pi/skills/nazar-rescue/SKILL.md
```

## 6. Emergency firewall/SSH fixes

Do not apply these during a drill unless intentionally testing rollback.

### Re-enable public SSH by disabling native Proxmox firewall

Inside chroot after `pmxcfs -l`:

```bash
sed -i 's/^enable: 1$/enable: 0/' /etc/pve/firewall/cluster.fw /etc/pve/local/host.fw
```

Normal boot will then come up without native Proxmox firewall enforcement. Re-enable only after fixing rules.

### Temporarily allow password SSH in installed system

Only for real emergencies, inside chroot:

```bash
cat > /etc/ssh/sshd_config.d/99-recovery.conf <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
EOF
sshd -t
```

Remove after recovery:

```bash
rm -f /etc/ssh/sshd_config.d/99-recovery.conf
sshd -t
```

## 7. Exit cleanly and boot normal system

Inside chroot:

```bash
exit
```

Back in Rescue:

```bash
umount -R /mnt
sync
reboot
```

In Hetzner Robot, deactivate Rescue / return to normal disk boot if Robot requires it. Then reset/reboot into the installed Proxmox system.

## 8. Post-drill validation after normal boot

From admin machine:

```bash
netbird ssh root@nazar
curl -k --connect-timeout 5 https://pve.nazar.studio/
ssh nazar-public   # expected to time out now
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
ls -lh /var/lib/vz/dump/ | tail
```

Acceptance criteria:

- Rescue SSH login works.
- RAID arrays assemble and root filesystem mounts.
- `/etc/pve`, firewall config, SSH config, and Proxmox authorized keys are reachable after `pmxcfs -l`.
- Temporary SSH key can be added and removed.
- Normal boot returns successfully.
- NetBird reconnects.
- NetBird SSH to `nazar` works.
- Proxmox UI works over `pve.nazar.studio`.
- Public SSH times out.
- Current expected VMs are in their documented states; validate at least `qm status 101` and `qm agent 101 ping` for the Forgejo VM.
