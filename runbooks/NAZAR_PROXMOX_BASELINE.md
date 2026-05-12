# Nazar Proxmox Baseline

This is the current Proxmox host baseline for `nazar`. OwnLoom public/application expansion remains intentionally narrow; the hypervisor layer, access model, backups, and VM fleet deploy path are the priority.

Proxmox VE on Debian remains the current production host platform. Do not migrate the production host to NixOS+microVM, Proxmox-on-NixOS, or Incus without a separate lab proof, backup/restore plan, and explicit migration decision. See `runbooks/CANONICAL_OPERATING_MODEL.md`.

## Current access model

```text
Primary shell:    netbird ssh alex@nazar (or OpenSSH as alex over an allowed private path)
Shell workspace:  plain login shell by default; optional manual Zellij session `nazar`
Browser terminal: https://nazar.studio/zellij/ over NetBird, Zellij token required
Host sudo:        alex has passwordless sudo; root remains break-glass
VM shell access:  from nazar, ssh alex@<vm-name> over vmbr1 private NAT aliases
Private dashboard:https://nazar.studio/ over NetBird
Proxmox UI:       https://pve.nazar.studio/ or https://100.124.39.100:8006 over NetBird
Public SSH:       disabled in normal boot
Break-glass:      Hetzner Rescue drill, documented and tested
```

Current host/Linux users:

```text
root        break-glass/admin fallback; password stored in password manager
alex        daily shell admin, SSH key-only, password locked, sudo NOPASSWD
```

Root password note: the `nazar` Linux/root@pam password was rotated on 2026-05-11 and saved in the password manager. The temporary handoff file on the host was shredded after confirmation. SSH password login remains disabled.

Current Proxmox UI users:

```text
root@pam   enabled, TOTP configured, break-glass/admin fallback
alex@pve   enabled, TOTP configured, Administrator on /
```

Daily UI login remains `alex@pve` in the Proxmox VE authentication realm. Do not migrate this blindly to `alex@pam`: PAM UI login would depend on the Linux `alex` password, which is intentionally locked for shell access. If a PAM UI account is desired later, create and test `alex@pam` with TOTP and equivalent ACLs before disabling `alex@pve`.

Break-glass UI login:

```text
User: root
Realm: Linux PAM
```

NixOS VM admin-user policy:

- `alex` is the canonical human admin user on all NixOS VMs.
- VM passwords remain locked for normal operation; SSH is key-only through `nazar` and private NAT aliases.
- Do not add a shared VM password. If console emergency passwords are ever needed, they must be unique per VM and delivered through encrypted `sops-nix`/secret material, not plaintext Nix or git.
- Root VM SSH remains key-only for break-glass and current compatibility.

Store root passwords, `alex@pve` credentials, and TOTP recovery material in a password manager.

## Current network/firewall state

Native Proxmox firewall is enabled/running.

Normal inbound exposure:

```text
enp0s31f6 public NIC:
  UDP 51820      NetBird/WireGuard listener
  ICMP/ICMPv6    diagnostics and required IPv6 behavior
  TCP 22         denied
  TCP 8006       denied
  TCP 3128       denied
  TCP 5900-5999  denied

wt0 NetBird:
  TCP 22022      NetBird SSH; canonical shell entrypoint
  TCP 80/443     private reverse-proxy HTTP(S)
  TCP 8006       Proxmox UI
  TCP 10022      Forgejo SSH proxy
  TCP 22         not allowed by normal NetBird policy; use NetBird SSH instead
  TCP/UDP 53     NetBird DNS listener if DNS is enabled; currently disabled on nazar

vmbr1 private VM bridge:
  UDP 67         dnsmasq DHCP for VM NAT network
  TCP 22         host-to-VM SSH using aliases: git, minecraft, ownloom, ownloom-data, ownloom-vault
```

Validation:

```bash
pve-firewall status
pve-firewall simulate --from outside --to host --protocol tcp --dport 22 --source 1.2.3.4 --dest 167.235.12.22
curl -k --connect-timeout 5 https://nazar.studio/          # private dashboard
curl -k --connect-timeout 5 https://nazar.studio/zellij/   # Zellij web login
curl -k --connect-timeout 5 https://pve.nazar.studio/      # Proxmox UI
netbird status
```

Expected public SSH simulation: `ACTION: DROP`.

## VM policy

Default rule for VMs on `nazar`:

- New VMs should run NixOS unless an exception is explicitly documented.
- VM configuration should be fully declarative and reproducible from version-controlled Nix code.
- Manual guest changes, mutable service setup, and ad-hoc installed packages are not acceptable as final production state.
- Runtime data is allowed, but its location, ownership, backup, and restore path must be documented.

See `runbooks/NIXOS_DECLARATIVE_VM_POLICY.md`.

VM 101 (`git`) now follows this rule: NixOS + Forgejo from the fleet flake.

## Current VM state

Legacy VM 100 exists only as a fresh NixOS installer shell and is stopped to free host resources. Current OwnLoom work uses the declarative VM 120/121 profiles documented in their runbooks.

```text
VMID: 100
Name: ownloom
CPU: 5 vCPU
RAM: 32 GiB
Disk: 200 GiB
Boot media: NixOS 26.05pre minimal ISO
Status: stopped
Autostart: disabled
```

Final backup of the previous VM 100 before recreation:

```text
/var/lib/vz/dump/vzdump-qemu-100-2026_05_10-16_48_25.vma.zst
```

## Health checks

Run regularly:

```bash
pveversion
apt-get update
apt list --upgradable
pve-firewall status
netbird status
cat /proc/mdstat
systemctl --failed --no-pager
pvesm status
ls -lh /var/lib/vz/dump/ | tail
```

Current package status at last check: no upgradable packages.

## Nix tooling on Proxmox host

Nix is installed on the Debian/Proxmox host as a multi-user package-manager install for fleet flake tooling only.

```text
Nix version: 2.34.7
Daemon: nix-daemon.service / nix-daemon.socket
Config: /etc/nix/nix.conf
Store: /nix/store
Purpose: evaluate/build NixOS VM configurations, not manage the Proxmox host OS
```

Useful commands from `/root/nazar`:

```bash
. /etc/profile.d/nix.sh
nix flake check
nix build .#nixosConfigurations.git.config.system.build.toplevel
```

## Notifications

Proxmox SMTP notification target is configured:

```text
Target: nazar-alerts
Type: SMTP
Server: smtp-relay.brevo.com:587 STARTTLS
From: alerts@nazar.help
Recipient: eucico@proton.me
Matcher: nazar-alerts-all -> nazar-alerts
Default mail-to-root matcher: disabled
```

Validation command:

```bash
pvesh create /cluster/notifications/targets/nazar-alerts/test
```

Test notification has been confirmed delivered to the Proton recipient inbox. SMTP key is stored in Proxmox notification config and Proton Pass; do not commit or print it.

RAID/mdadm, SMART/smartd, ACME certificate expiry, disk usage, and boot/reboot alerts are also routed through the same Proxmox notification path using local wrappers under `/usr/local/sbin` plus `nazar-*` systemd services/timers.

See `runbooks/ALERTS.md` for validation commands and alert bridge details.

## Remaining Proxmox-layer hardening

Priority order:

1. Store remaining recovery/provider items in Proton Pass: Hetzner Robot, NetBird admin, Brevo SMTP key, and ACME token location. (`root@pam` and `alex@pve` are already stored.)
2. Manually download important backup archives from `/var/lib/vz/dump/` to the desktop PC after important changes. Automated encrypted off-host backups can be reconsidered later.
3. Rotate the Hetzner DNS API token used for Proxmox ACME and update the plugin config without exposing the token in logs.
4. Periodically rerun Hetzner Rescue exercise.
5. Keep Forgejo as the canonical infra Git remote for now; do not add a GitHub mirror unless that decision changes.
6. Continue hardening the NixOS fleet architecture with canary deploys and focused per-VM validation.

## Do not do yet

- Do not disable `root@pam`.
- Do not expose Proxmox UI publicly.
- Do not re-enable public SSH unless intentionally rolling back during recovery.
- Do not destroy the final old-VM backup until important backup archives have been manually copied to the desktop PC and VM 120/121 backup/restore is proven.
