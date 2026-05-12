# Hardening Applied

Date: 2026-05-09, updated after rename on 2026-05-10.

## Access model now

Preferred:

```text
Desktop/laptop/mobile -> NetBird SSH -> nazar -> private NAT bridge -> VMs
Shell: netbird ssh root@nazar
       plain shell by default; optional manual workspace: zellij attach --create nazar
Browser terminal:
       https://nazar.studio/zellij/ over NetBird, Zellij token required
VMs:   ssh alex@ownloom / ssh alex@ownloom-data from inside nazar over private NAT aliases
       root VM SSH remains key-only for break-glass and current compatibility
UI:    https://nazar.studio/ private dashboard
       https://pve.nazar.studio/ Proxmox UI
       https://100.124.39.100:8006 direct Proxmox fallback
```

Public exposure rule:

```text
Default state: keep services behind NetBird/private DNS and NetBird policy.
Public toggle: a service may be exposed through NetBird Reverse Proxy or a public forward only after the target VM/service is explicitly hardened for public traffic.
If the service is not being shared publicly yet, leave its public toggle disabled and keep only NetBird-private access.
```

Minimum hardening before enabling a public toggle:

```text
- real application authentication/authorization, not only private-network trust;
- HTTPS or an equivalent TLS-terminating public proxy;
- least-privilege firewall/proxy target ports only;
- no admin/debug endpoints exposed publicly;
- backups and restore path tested for stateful services;
- logs/alerts available for public-facing failures or abuse;
- explicit rollback path: disable the Reverse Proxy service or public-forward unit.
```

Break-glass fallback:

```text
Hetzner Robot Rescue -> assemble RAID -> chroot -> pmxcfs -l -> repair access/firewall
```

See `runbooks/RESCUE_DRILL.md` and `.pi/skills/nazar-rescue/SKILL.md`.

## Names

```text
Proxmox host/node: nazar
Main VM: ownloom
```

## Proxmox web UI

Public direct access to Proxmox UI is blocked on the Hetzner/public NIC.

Blocked publicly on `enp0s31f6`:

```text
TCP 8006       Proxmox web UI
TCP 3128       SPICE proxy
TCP 3389       RDP
TCP 5900-5999  VNC ranges
TCP/UDP 111    rpcbind/NFS portmapper is disabled and denied by host firewall
```

Native Proxmox firewall is also enabled with host inbound default-deny and explicit allows for NetBird/WireGuard, NetBird management access, ICMP/ICMPv6, and VM DHCP. Public SSH is intentionally not allowed in normal boot. See `runbooks/PROXMOX_FIREWALL.md`.

Still reachable through NetBird/private DNS:

```text
https://nazar.studio/          # private dashboard
https://nazar.studio/zellij/   # Zellij web terminal, token required
https://pve.nazar.studio/      # Proxmox UI
https://100.124.39.100:8006    # direct Proxmox fallback
```

TLS note: `nazar.studio` / `pve.nazar.studio` currently use NetBird-only nginx with a self-signed certificate. A trusted certificate should use DNS-01; public `8006`, `80`, and `443` remain unnecessary for private-only access.

## SSH

Public SSH is disabled by the Proxmox firewall. OpenSSH still listens on the host, but public `enp0s31f6:22` is denied; normal shell access is through NetBird SSH.

SSH public password login has been disabled.

Effective SSH settings:

```text
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
AllowTcpForwarding yes
```

Shell access:

```bash
netbird ssh root@nazar       # Proxmox over NetBird SSH; plain shell by default
ssh alex@ownloom             # normal VM access from nazar, via private NAT alias
ssh alex@ownloom-data        # normal VM access from nazar, via private NAT alias
ssh root@ownloom             # key-only fallback for break-glass and current compatibility from nazar
ssh root@ownloom-data        # key-only fallback for break-glass and current compatibility from nazar
ssh nazar-public             # expected to time out unless firewall is intentionally rolled back
```

NetBird policy is least-privilege:

```text
admins -> nazar               NetBird SSH only for shell
admins -> nazar               TCP 80,443,8006,10022 for private services
admins -> ownloom-data        TCP 80 for DAV/bootstrap HTTP
ownloom -> ownloom-data       TCP 80 for DAV-backed wiki/backend access
admins -> nazar               TCP 25565 and UDP 24454 for private Minecraft forwarding
no admins -> VMs TCP/22 policy
no NetBird SSH on VMs
```

## Files changed on Proxmox

SSH hardening:

```text
/etc/ssh/sshd_config.d/99-ownloom-hardening.conf
```

Public admin-port lock-down:

```text
/usr/local/sbin/ownloom-public-lockdown
/etc/network/if-up.d/ownloom-public-lockdown
/etc/systemd/system/ownloom-public-lockdown.service
```

Native Proxmox firewall:

```text
/etc/pve/firewall/cluster.fw
/etc/pve/local/host.fw
```

Proxmox/host alerts:

```text
/etc/pve/notification-templates/default/nazar-alert-*.hbs
/usr/local/sbin/nazar-proxmox-notify
/usr/local/sbin/nazar-mdadm-alert
/usr/local/sbin/nazar-smartd-alert
/usr/local/sbin/nazar-acme-cert-check
/usr/local/sbin/nazar-disk-usage-check
/usr/local/sbin/nazar-boot-alert
/etc/systemd/system/nazar-acme-cert-check.{service,timer}
/etc/systemd/system/nazar-disk-usage-check.{service,timer}
/etc/systemd/system/nazar-boot-alert.service
/etc/mdadm/mdadm.conf
/etc/smartd.conf
```

Unneeded rpcbind/portmapper service disabled:

```text
rpcbind.service
rpcbind.socket
```

## Disable public port lock-down temporarily

From SSH/Rescue:

```bash
/usr/local/sbin/ownloom-public-lockdown remove enp0s31f6
systemctl disable --now ownloom-public-lockdown.service
```

## Re-enable public port lock-down

```bash
systemctl enable --now ownloom-public-lockdown.service
/usr/local/sbin/ownloom-public-lockdown add enp0s31f6
```

## Temporarily re-enable SSH password login in recovery

Only if needed from Hetzner Rescue/chroot:

```bash
cat > /etc/ssh/sshd_config.d/99-recovery.conf <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
EOF
sshd -t
systemctl reload ssh
```

Remove the recovery override after fixing access:

```bash
rm /etc/ssh/sshd_config.d/99-recovery.conf
sshd -t
systemctl reload ssh
```

## Verified

- NetBird Proxmox UI returned HTTP 200.
- Public Proxmox UI on `167.235.12.22:8006` is blocked.
- Native Proxmox firewall reports `enabled/running`.
- NetBird remains connected after firewall enablement.
- Public SSH is blocked by native Proxmox firewall; simulation returns `ACTION: DROP` and `ssh nazar-public` should time out.
- NetBird SSH to `root@nazar` works.
- Password SSH was rejected before public SSH was disabled.
- Rescue drill successfully proved Hetzner Rescue, RAID mount, chroot, `pmxcfs -l`, and temporary key add/remove.
- `alex@pve` exists as daily Proxmox admin with TOTP enabled.
- `root@pam` remains available as break-glass with TOTP enabled.
- Proxmox SMTP notification target `nazar-alerts` delivered a test email.
- mdadm RAID alerts and smartd SMART alerts are routed through `nazar-alerts` and test invocations succeeded.
- ACME certificate expiry, disk usage, and boot/reboot alert checks are configured through `nazar-alerts`; forced test invocations succeeded.
- OwnLoom VM work is paused; VM 100 is stopped with autostart disabled while Proxmox-layer hardening continues.
