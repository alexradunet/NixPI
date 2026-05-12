# Hetzner Robot Rescue Recovery Runbook

Use this if you lock yourself out of SSH/Proxmox or break networking/firewall.

## Goal

Boot Hetzner Rescue, mount the installed system, chroot into it, fix access, then reboot.

## 1. Boot Rescue System

In Hetzner Robot:

```text
Server -> Rescue -> Linux 64-bit -> Activate Rescue
Server -> Reset/Reboot
```

SSH into rescue using the password shown by Robot:

```bash
ssh root@167.235.12.22
```

## 2. Inspect disks and RAID

```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
cat /proc/mdstat
mdadm --detail --scan
```

Expected arrays:

```text
/dev/md0 swap
/dev/md1 /boot
/dev/md2 /
```

If arrays are not active:

```bash
mdadm --assemble --scan
cat /proc/mdstat
```

## 3. Mount installed system

```bash
mount /dev/md2 /mnt
mount /dev/md1 /mnt/boot
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mount --bind /run /mnt/run
hostname nazar
chroot /mnt /bin/bash
```

You are now inside the installed Proxmox system.

Important: `/etc/pve` is a Proxmox cluster filesystem, not plain disk files. To access firewall config and Proxmox-managed root SSH authorized keys from Rescue/chroot, start pmxcfs in local mode:

```bash
pmxcfs -l
```

Then these paths become available:

```text
/etc/pve/firewall/cluster.fw
/etc/pve/local/host.fw
/etc/pve/priv/authorized_keys
/root/.ssh/authorized_keys -> /etc/pve/priv/authorized_keys
```

## 4. Restore SSH access

### Option A: reset root password

```bash
passwd root
```

Make sure SSH allows the method you need:

```bash
nano /etc/ssh/sshd_config
ls -la /etc/ssh/sshd_config.d/
```

Current hardening file:

```text
/etc/ssh/sshd_config.d/99-ownloom-hardening.conf
```

If you need temporary password SSH, add a recovery override:

```bash
cat > /etc/ssh/sshd_config.d/99-recovery.conf <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
EOF
sshd -t
```

Remove this recovery file after logging in normally:

```bash
rm /etc/ssh/sshd_config.d/99-recovery.conf
sshd -t
systemctl reload ssh
```

### Option B: add your SSH public key

In normal Proxmox, `/root/.ssh/authorized_keys` points to the Proxmox-managed key file. In Rescue/chroot, run `pmxcfs -l` first, then edit:

```bash
nano /etc/pve/priv/authorized_keys
chmod 600 /etc/pve/priv/authorized_keys
```

Paste your public key. For temporary Pi-assisted rescue keys, use a marker such as `nazar-pi-rescue-YYYYMMDDTHHMMSSZ` and remove the line before finishing.

Project skill for this workflow:

```text
.pi/skills/nazar-rescue/SKILL.md
```

## 5. Fix network config

Main network file:

```bash
nano /etc/network/interfaces
```

Known-good config at install time:

```text
# network interface settings; Proxmox/Hetzner
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
iface lo inet6 loopback

auto enp0s31f6
iface enp0s31f6 inet static
        address 167.235.12.22/26
        gateway 167.235.12.1
        up route add -net 167.235.12.0 netmask 255.255.255.192 gw 167.235.12.1 dev enp0s31f6 || true

iface enp0s31f6 inet6 static
        address 2a01:4f8:262:1b01::2/64
        gateway fe80::1

auto vmbr1
iface vmbr1 inet static
        address 10.10.10.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0
        post-up iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o enp0s31f6 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s 10.10.10.0/24 -o enp0s31f6 -j MASQUERADE
```

Enable forwarding:

```bash
cat > /etc/sysctl.d/ip-forwarding.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
```

## 6. Disable accidental firewall lockout

If native Proxmox firewall caused lockout, run this inside chroot after `pmxcfs -l`:

```bash
sed -i 's/^enable: 1$/enable: 0/' /etc/pve/firewall/cluster.fw /etc/pve/local/host.fw 2>/dev/null || true
systemctl disable pve-firewall || true
```

You can re-enable later from the Proxmox UI or with `pve-firewall restart` after fixing the rules. The intended firewall policy is documented in `runbooks/PROXMOX_FIREWALL.md`.

The current host-side public admin-port lock-down is managed by:

```text
/usr/local/sbin/ownloom-public-lockdown
/etc/systemd/system/ownloom-public-lockdown.service
/etc/network/if-up.d/ownloom-public-lockdown
```

To temporarily remove those public-interface blocks:

```bash
/usr/local/sbin/ownloom-public-lockdown remove enp0s31f6
systemctl disable --now ownloom-public-lockdown.service
```

If nftables/iptables custom rules caused lockout, inspect:

```bash
nft list ruleset
iptables -S
iptables -t nat -S
```

Clear only if necessary:

```bash
nft flush ruleset
iptables -F
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
```

Note: flushing iptables also removes NAT until networking is reloaded after boot.

## 7. Fix Proxmox web services

Inside chroot:

```bash
systemctl enable pve-cluster pvedaemon pveproxy pvestatd
```

After normal boot, check:

```bash
systemctl status pveproxy pvedaemon pvestatd pve-cluster
ss -tlnp | grep 8006
```

## 8. Reinstall GRUB if the server will not boot

This system is BIOS-booted and uses GRUB PC.

Inside chroot:

```bash
apt install --reinstall grub-pc proxmox-default-kernel
update-initramfs -u -k all
grub-install /dev/nvme0n1
grub-install /dev/nvme1n1
update-grub
```

## 9. Exit rescue and reboot

Inside chroot:

```bash
exit
```

Unmount:

```bash
umount -R /mnt
reboot
```

Wait 1-3 minutes, then test:

```bash
ssh root@167.235.12.22
```

For Proxmox via tunnel:

```bash
ssh -L 8006:127.0.0.1:8006 root@167.235.12.22
```

Open:

```text
https://127.0.0.1:8006
```

## 10. After recovery

- Remove any temporary `99-recovery.conf` SSH override.
- Re-enable desired hardening.
- Confirm your own SSH key works.
- Confirm Proxmox 2FA/recovery codes.
- Re-enable firewall carefully.
