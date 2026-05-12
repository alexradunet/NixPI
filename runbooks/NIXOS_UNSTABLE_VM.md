# Legacy Ownloom NixOS VM Runbook

> Historical note: this documents the earlier VM 100 experiment. The current canonical OwnLoom deployment is VM 120 (`ownloom`, `10.10.10.40`) and VM 121 (`ownloom-data`, `10.10.10.41`). Current admin access is a plain `netbird ssh root@nazar` shell by default; optionally run `zellij attach --create nazar`, then `ssh alex@ownloom` / `ssh alex@ownloom-data` using `nazar`'s private `/etc/hosts` aliases.

## VM installed

```text
VM ID: 100
Proxmox VM name: ownloom
Guest hostname: ownloom
OS: NixOS unstable / 26.05 pre-release
CPU: 6 vCPU, host CPU type
RAM: 16 GiB, no ballooning
Disk: 100 GiB qcow2 on local storage
Firmware: OVMF/UEFI, q35
Network: virtio on vmbr1 NAT
MAC: BC:24:11:5D:1F:17
NAT IP/DHCP reservation: 10.10.10.20
NetBird IP: 100.124.2.197
NetBird FQDN: ownloom.netbird.cloud
```

## Access

Legacy access for this retired VM used direct NetBird/OpenSSH and a NAT fallback. For current VMs, use the canonical model instead:

```bash
netbird ssh root@nazar
ssh alex@ownloom
ssh alex@ownloom-data
```

## VM network

```text
VM IP: 10.10.10.20/24
Gateway: 10.10.10.1
DNS: 1.1.1.1, 8.8.8.8
```

DHCP service on Proxmox:

```text
Service: ownloom-vm-dhcp.service
Range: 10.10.10.100-10.10.10.199
Reservation: ownloom -> 10.10.10.20
```

## NixOS config location

Inside the VM:

```text
/etc/nixos/configuration.nix
/etc/nixos/flake.nix
```

The flake output is:

```text
nixosConfigurations.ownloom
```

The flake tracks:

```text
github:NixOS/nixpkgs/nixos-unstable
```

Apply changes:

```bash
nixos-rebuild switch --flake /etc/nixos#ownloom
```

## Installed baseline features

- UEFI boot via systemd-boot.
- DHCP on `ens18`.
- OpenSSH enabled.
- SSH password login disabled.
- Root SSH login key-only.
- User `alex` exists and is in `wheel`.
- Passwordless sudo for wheel.
- QEMU guest agent enabled and verified.
- NetBird installed and joined.
- Useful packages: git, curl, wget, vim, htop, jq, tree, tmux, netbird.

## SSH security

```text
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
```

Authorized key/comment:

```text
ownloom-proxmox-root
```

## NetBird inside VM

```text
NetBird IP: 100.124.2.197/16
NetBird FQDN: ownloom.netbird.cloud
Management: Connected
```

NetBird FQDN is aligned with the VM name: `ownloom.netbird.cloud`.

## NetBird SSH note

NetBird SSH on individual VMs is not canonical. Keep the normal admin path simple: NetBird SSH into `nazar`, then regular OpenSSH over the private `vmbr1` NAT bridge using VM-name aliases.

## Proxmox commands

Show VM config:

```bash
qm config 100
```

Start/stop:

```bash
qm start 100
qm shutdown 100
```

QEMU guest agent check:

```bash
qm agent 100 ping
qm agent 100 network-get-interfaces
```

## ISO used

Downloaded to Proxmox:

```text
/var/lib/vz/template/iso/nixos-unstable-minimal-x86_64-linux.iso
```

Source URL:

```text
https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso
```

SHA256 at download time:

```text
45d793314903d9aab7b7659319ead334213fb506138970f7a52c70dc18c338f0
```

The ISO is detached from VM boot order; VM boots from disk.
