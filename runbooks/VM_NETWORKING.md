# VM Networking Runbook

The host uses a private NAT bridge for VMs and containers.

## Bridge

```text
Bridge: vmbr1
Host bridge IP: 10.10.10.1/24
Guest subnet: 10.10.10.0/24
```

The host masquerades outbound VM traffic through the main Hetzner NIC `enp0s31f6`.

## Proxmox VM network setting

When creating a VM, set:

```text
Bridge: vmbr1
Model: VirtIO paravirtualized
```

## Static guest IP example

Inside a Linux or Windows VM:

```text
IP address: 10.10.10.40
Prefix:     /24 or 255.255.255.0
Gateway:    10.10.10.1
DNS:        1.1.1.1 or 8.8.8.8
```

Current reservations and Proxmox-host aliases:

```text
10.10.10.21 -> git VM 101
10.10.10.30 -> minecraft VM 110
10.10.10.40 -> ownloom VM 120
10.10.10.41 -> ownloom-data VM 121
10.10.10.42 -> ownloom-vault VM 122 reserved, not deployed
```

`nazar` has matching `/etc/hosts` entries, so after entering the Proxmox host with `netbird ssh root@nazar`, use the canonical `alex` VM admin account:

```bash
ssh alex@git
ssh alex@minecraft
ssh alex@ownloom
ssh alex@ownloom-data
```

VM passwords remain locked and normal access is key-only. Root VM SSH remains available key-only for break-glass and current compatibility, not as the canonical human login.

Use unique IPs per VM:

```text
10.10.10.21
10.10.10.30
10.10.10.40
10.10.10.41
10.10.10.42 (reserved)
```

## Remote access to VMs

Recommended admin path:

```bash
netbird ssh root@nazar
ssh alex@ownloom        # or another VM alias from the table above
```

NetBird inside VMs is useful for private service access and diagnostics, but VM shell administration should normally go through `nazar` and the private NAT bridge. Current NetBird service policy is deliberately narrow: VM 120 (`ownloom`) and admin peers can reach VM 121 (`ownloom-data`) on TCP/80 for DAV; direct NetBird/OpenSSH to VMs is not canonical.

For Windows:

1. Install Windows using Proxmox noVNC console.
2. Install VirtIO drivers.
3. Enable Remote Desktop.
4. Access it through the private/NetBird administrative path only; do not expose RDP publicly.

## Do not expose RDP publicly

Avoid forwarding public port `3389` to Windows VMs. Use Tailscale/WireGuard instead.

The Minecraft VM has an explicit public-service toggle, but the current deployed posture is NetBird-private forwarding only. If public Minecraft exposure is intentionally enabled later, only `25565/tcp` for Minecraft Java and `24454/udp` for Simple Voice Chat should be forwarded to `10.10.10.30`; SSH/admin access should remain private. OwnLoom VMs 120/121/122 are private-only; do not add public routes or Proxmox port forwards for them.

## If VM has no internet

On the Proxmox host, check:

```bash
ip addr show vmbr1
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
```

Expected:

```text
vmbr1 has 10.10.10.1/24
net.ipv4.ip_forward = 1
POSTROUTING has MASQUERADE for 10.10.10.0/24 via enp0s31f6
```

Re-apply networking:

```bash
ifreload -a
```
