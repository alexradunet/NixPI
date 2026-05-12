# Security Plan

> Historical baseline plan. The implemented/current model is documented in `security/HARDENING_APPLIED.md` and `runbooks/NETBIRD_ACCESS.md`: public SSH is blocked, shell access is NetBird SSH to `nazar`, Proxmox UI is NetBird/private-only, and VM shell access goes through `nazar` over the private NAT bridge.

## Security model

Current preferred model:

```text
Public internet -> no admin SSH/UI
Admin device -> NetBird SSH -> nazar -> private NAT bridge -> VMs
Admin device -> NetBird/private DNS -> Proxmox UI/private services
VM service access -> explicit NetBird policies only
```

## Important answer: is SSH password login acceptable?

Keeping SSH password login is not instantly catastrophic if the password is long, unique, and stored in a password manager. But for a public root server, key-only SSH is significantly safer.

Best compromise:

1. Keep password SSH temporarily while setting up recovery docs and your own key.
2. Add your own SSH key and test it.
3. Enable Proxmox 2FA.
4. Restrict public ports with Hetzner firewall.
5. Disable SSH password login once key-based recovery is confirmed.

Keep the root password in your password manager for Proxmox login and Hetzner rescue/chroot recovery. Disabling password SSH does not mean forgetting the root password.

## Immediate safe hardening

### 1. Add your own SSH key

On your PC:

```bash
ssh-keygen -t ed25519 -C "nazar"
cat ~/.ssh/id_ed25519.pub
```

On the server:

```bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo 'YOUR_PUBLIC_KEY_HERE' >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

Test from a new terminal:

```bash
ssh root@167.235.12.22
```

### 2. Remove temporary setup SSH key

After your own key works:

```bash
sed -i '/pi-temp-proxmox-setup/d' /root/.ssh/authorized_keys /etc/pve/priv/authorized_keys 2>/dev/null
```

### 3. Use NetBird for Proxmox

```bash
netbird ssh root@nazar
```

Then browse through NetBird/private DNS:

```text
https://nazar.studio/          # private dashboard
https://nazar.studio/zellij/   # Zellij web terminal, token required
https://pve.nazar.studio/      # Proxmox UI
```

### 4. Enable Proxmox 2FA

In Proxmox UI:

```text
Datacenter -> Permissions -> Two Factor -> Add TOTP
```

Add TOTP for:

```text
root@pam
```

Store recovery codes, if offered.

## Recommended firewall approach

Use Hetzner Robot Firewall first because it protects the host before Linux receives traffic.

Minimum allowed inbound:

```text
TCP 22 from your IP, or from all if your IP changes often
```

Preferred:

```text
TCP 22 only from your home/VPN IP
TCP 8006 blocked publicly
TCP 3389 blocked publicly
```

If you need to access from changing locations, consider Tailscale/WireGuard before restricting SSH to one source IP.

## Optional: local host firewall

If using Proxmox firewall, do it cautiously. Do not enable a drop policy until SSH tunnel access has been tested and Hetzner Robot Rescue runbook is understood.

## Final SSH hardening once your key works

Create `/etc/ssh/sshd_config.d/99-hardening.conf`:

```text
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
X11Forwarding no
```

Apply:

```bash
sshd -t
systemctl reload ssh
```

Test in a new terminal before closing the old one:

```bash
ssh root@167.235.12.22
```

## If you intentionally keep password SSH

Use all of these mitigations:

- Very long unique password, preferably 24+ random characters.
- Proxmox 2FA enabled.
- Hetzner Firewall restricts SSH to your IP if possible.
- Install fail2ban or sshguard.
- Keep password login for root only if you accept the risk.

A complex password helps, but key-only SSH remains the better target state.
