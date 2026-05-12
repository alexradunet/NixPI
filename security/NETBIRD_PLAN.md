# NetBird Access Plan

> Historical note: this was the initial NetBird plan. The current implemented policy matrix is in `runbooks/NETBIRD_ACCESS.md`: public SSH is disabled, NetBird SSH is canonical only on `nazar`, VM shell access goes through `nazar` over the private NAT bridge, and direct VM service access is limited to explicit TCP ports such as OwnLoom Data DAV.

Assumption: "netbord" means **NetBird**, the WireGuard-based zero-trust overlay network.

## Why NetBird fits this host

NetBird is a good fit if you want:

- access from desktop, laptop, and mobile without exposing Proxmox publicly;
- WireGuard-based encrypted connectivity;
- open-source/self-hostable option;
- an EU-friendly alternative to Tailscale;
- policies/ACLs so only your devices can reach Proxmox.

## Recommended architecture

```text
Desktop / Laptop / Mobile
        |
        | NetBird private network
        v
Proxmox host nazar
        |
        | vmbr1 NAT network
        v
VMs / containers
```

Public internet should not reach Proxmox UI directly.

## Cloud vs self-hosted NetBird

### Recommended now: NetBird Cloud

Use NetBird Cloud first because it avoids circular dependency during initial hardening.

If Proxmox breaks, the NetBird control plane is still available.

### Self-hosted later

If self-hosting NetBird, preferably host the NetBird management/control plane on a **separate small VPS**, not on this same Proxmox host.

Avoid this circular dependency:

```text
Need NetBird to fix Proxmox, but NetBird controller is down because Proxmox is broken.
```

## Target public exposure

Implemented publicly allowed baseline:

```text
UDP 51820 NetBird/WireGuard listener
ICMP/ICMPv6 diagnostics
```

Public SSH (`TCP 22`) is not allowed in normal boot.

Publicly blocked:

```text
TCP 8006 Proxmox UI
TCP 3128 SPICE proxy
TCP 3389 Windows RDP
Any VM admin ports
```

## Target private access over NetBird

Allow only admin devices to reach the Proxmox host:

```text
NetBird SSH to nazar for shell
TCP 80, 443, 8006, 10022 to nazar for private services
```

Selected VM service ports are explicit policies, e.g. TCP/80 to `ownloom-data` for DAV. Do not add admin-to-VM TCP/22 policies by default.

## Suggested NetBird groups

```text
Group: admins
- desktop
- laptop
- mobile phone

Group: proxmox-hosts
- nazar

Group: vms
- future VMs if NetBird is installed inside them
```

## Suggested NetBird policies

```text
admins -> proxmox-hosts: TCP 22, TCP 8006
admins -> vms: TCP 22, TCP 3389, as needed
```

Default should be deny or least-privilege where possible.

## Install outline

Do not blindly run these until checking the latest NetBird docs.

Typical flow:

1. Create NetBird account.
2. Install NetBird on desktop/laptop/mobile.
3. Create a setup key for `nazar`.
4. Install NetBird on Proxmox host.
5. Join Proxmox host to your NetBird network.
6. Confirm you can open Proxmox via NetBird IP:

```text
https://NETBIRD_PROXMOX_IP:8006
```

7. Only after this works, block public `8006`.

## No-lockout order of operations

1. Keep current SSH access working.
2. Install NetBird on your desktop/laptop/mobile.
3. Install NetBird on Proxmox.
4. Confirm Proxmox UI over NetBird.
5. Confirm SSH over NetBird.
6. Add your own SSH key.
7. Remove temporary setup key.
8. Enable Proxmox 2FA.
9. Block public Proxmox UI.
10. Disable public SSH password login.

## Password SSH stance with NetBird

Best final state:

```text
Public SSH: key-only
Proxmox web login: password + 2FA, reachable only through NetBird/SSH tunnel
Emergency recovery: Hetzner Robot Rescue
```

Keeping password SSH publicly enabled is not the preferred final state, even with a complex password.

## VM access strategy

For VMs, prefer installing NetBird inside each VM.

Linux VM:

```text
NetBird IP -> SSH
```

Windows VM:

```text
NetBird IP -> RDP
```

Avoid public RDP forwarding.
