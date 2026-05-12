# Hardening and Standards Roadmap

This roadmap lists future work to make the `nazar` Proxmox host and `ownloom` VM more resilient, auditable, and closer to common operational/security standards.

It is intentionally practical rather than tied to one formal framework. The checklist borrows from common controls in CIS-style hardening, NIST/CIS operational practices, and Proxmox/NetBird best practices.

## Current baseline

Already completed:

- Proxmox UI is not publicly exposed.
- Private dashboard is reachable via NetBird at `https://nazar.studio/`.
- Zellij web terminal is reachable via NetBird at `https://nazar.studio/zellij/` with Zellij token auth and a localhost-only backend.
- Proxmox UI is reachable privately via NetBird at `https://pve.nazar.studio/` or direct fallback `https://100.124.39.100:8006`.
- Browser-trusted Let's Encrypt certificate is installed via ACME DNS-01.
- SSH is key-only; password authentication is disabled.
- Proxmox `root@pam` has TOTP enabled.
- Hetzner public firewall, local host lockdown, and native Proxmox firewall block public admin ports.
- NetBird ACLs restrict admin access to required ports.
- Unused rpcbind/portmapper service is disabled.
- Previous VM 100 (`ownloom`) states have local manual backups; current VM 100 is a stopped installer shell with no scheduled job.
- RAID1 and SMART monitoring are active.
- Recovery runbooks exist.
- Pi is installed as a CLI tool on `nazar`; no daemon or port was opened.

## Priority 0 — must preserve

These are invariants. Future changes should not violate them.

- Do not expose Proxmox UI publicly.
- Keep public SSH disabled in normal boot; if temporarily re-enabled during recovery, keep it key-only/passwordless and remove it again.
- Keep Proxmox 2FA enabled.
- Keep NetBird ACLs least-privilege.
- Do not commit secrets to git.
- Keep Hetzner Robot Rescue recovery path documented.
- Keep at least one tested backup before high-risk changes.

## Priority 1 — disaster recovery and backup maturity

### Off-host backups

Status: Manual interim path chosen.

Local backups protect against VM mistakes but not host loss. For now, important backup archives will be manually downloaded from `/var/lib/vz/dump/` to the desktop PC after important changes. This gives an off-host copy, but it is still weaker than automated encrypted backups with regular restore tests.

Future automated options, if manual downloads become insufficient:

1. Proxmox Backup Server on separate infrastructure.
2. Hetzner Storage Box via encrypted backup workflow.
3. Restic/Borg from guest/host to off-host storage.
4. S3-compatible encrypted backup target.

Target standard:

```text
3-2-1 backup model:
3 copies of important data
2 different media/storage systems
1 off-site/off-host copy
```

Manual interim requirements:

- Download `.vma.zst`, `.notes`, and `.log` files to the desktop PC after important changes.
- Verify downloaded file sizes against the server copy.
- Keep at least the latest important Forgejo/Git VM backup and final pre-recreate OwnLoom backup off-host.
- Document restore procedure and restore-test evidence.

Future automated backup requirements:

- Encryption at rest.
- Documented restore procedure.
- At least quarterly restore test.
- Backup retention policy.
- Alerting for failed backups.

### Restore tests

Status: TODO

At least once after setup and then periodically:

```bash
qmrestore /var/lib/vz/dump/vzdump-qemu-101-YYYY_MM_DD-HH_MM_SS.vma.zst 900 --storage local
```

Verify the restored VM boots, networking works, and guest agent responds. Destroy test VM after validation.

## Priority 2 — monitoring and alerting

Status: Partially complete.

Configured and tested:

```text
Proxmox SMTP target: nazar-alerts
Provider: Brevo
From: alerts@nazar.help
Recipient: eucico@proton.me
Test delivery: confirmed
```

Covered now:

- Proxmox notification framework.
- Proxmox backup/task notifications routed through `nazar-alerts`.
- RAID/mdadm monitor alerts routed through `nazar-alerts` via `/usr/local/sbin/nazar-mdadm-alert`.
- SMART/smartd warnings routed through `nazar-alerts` via `/usr/local/sbin/nazar-smartd-alert`.
- ACME/TLS certificate expiry check via `nazar-acme-cert-check.timer`.
- High disk usage check via `nazar-disk-usage-check.timer`.
- Boot/reboot alert via `nazar-boot-alert.service`.

Intentionally skipped for now:

- External uptime monitoring from outside Nazar for true downtime detection.

Recommended approach:

- Keep dedicated alert sender account/key in Proton Pass.
- Keep personal mailbox as recipient.
- Use Proxmox notification target where possible.
- Keep credentials out of git.

## Priority 3 — identity and access management

### Named Proxmox admin user

Status: DONE

A named daily admin account exists and should be preferred for Proxmox UI use.

Current state:

```text
User: alex@pve
Role: Administrator on /
2FA: enabled
root@pam: kept as break-glass only, TOTP enabled
```

### SSH user model

Status: Partially hardened

Current normal shell access to Proxmox is NetBird SSH as `root`; public SSH is disabled by firewall. Regular OpenSSH remains key-only if reachable over approved private paths or recovery rollback.

Longer-term stronger pattern:

```text
admin user with sudo -> root disabled for direct SSH
```

Only implement after named admin login, NetBird policy, and recovery path are tested again.

### Infra Git remote

Status: Forgejo canonical for now

The canonical infra Git remote is the NetBird-only private Forgejo server:

```text
ssh://git@git.nazar.studio:10022/nazar/nazar.git
```

Do not push `/root/nazar` to GitHub for now. A private GitHub mirror can be reconsidered later if an additional off-host Git copy is wanted. Do not copy a broad personal SSH private key to `nazar` unless unavoidable.

## Priority 4 — network segmentation and firewall standardization

### NetBird hardening

Status: Initial ACLs done; more possible.

Future improvements:

- Add laptop/mobile to `admins` group and test.
- Remove/disable any broad default all-to-all policy after all needed policies are verified.
- Add posture checks where useful, e.g. OS, NetBird client version, device approval.
- Separate future VMs into groups by sensitivity, e.g. `prod-vms`, `dev-vms`, `windows-vms`.

### Proxmox firewall

Status: Enabled on host with auditable policy in `/etc/pve/firewall/cluster.fw` and `/etc/pve/local/host.fw`.

Current intent:

- host inbound default-deny;
- deny public SSH on `enp0s31f6` in normal boot;
- allow NetBird/WireGuard listener;
- allow Proxmox UI/SSH/SPICE over NetBird;
- allow VM DHCP on `vmbr1`;
- keep the older custom iptables lockdown as defense in depth.

Future improvements:

- Re-check policy after adding more VMs/services.
- Consider guest-level Proxmox firewall rules where useful.
- Keep Hetzner Rescue path ready before any future tightening.

## Priority 5 — update and vulnerability management

### Patch cadence

Status: TODO

Define routine:

```text
Weekly or biweekly:
  apt update
  apt list --upgradable
  review Proxmox release notes
  apt full-upgrade when safe
  reboot if kernel/proxmox kernel updated
```

Before major updates:

- Confirm backups are recent.
- Read Proxmox release notes.
- Ensure Hetzner Rescue access works.

### Package repositories

Current:

```text
pve-no-subscription
```

Decision for now: no Proxmox subscription. Continue using `pve-no-subscription` with the enterprise repository disabled. Reconsider a subscription later if support requirements change.

## Priority 6 — logging, audit, and evidence

Status: TODO

Future improvements:

- Document admin changes in `CHANGELOG.md`.
- Keep git history in the private Forgejo remote; optionally mirror off-host later if needed.
- Export important Proxmox task logs for major maintenance.
- Consider remote log shipping later.
- For major maintenance, save concise evidence in the relevant runbook or `CHANGELOG.md`; avoid committing raw command dumps unless they are still actively useful.

## Priority 7 — secrets management

Status: Partially handled by policy/docs.

Rules:

- Never commit API tokens, private keys, setup keys, provider credentials, or `.env` files.
- Store secrets in a password manager.
- Prefer scoped tokens:
  - Hetzner DNS token only for DNS project.
  - If an external Git mirror is added later, use a repo-scoped deploy key or fine-scoped token only.
  - NetBird setup keys one-time and short-lived.
- Rotate tokens after suspected exposure.

Known persistent secrets:

- Hetzner Console API token stored in Proxmox ACME plugin config. Rotate it and update the plugin config after any exposure.
- SSH private key stored on admin devices.
- Proxmox 2FA secret/recovery info in password manager.

## Priority 8 — VM and workload standardization

### NixOS VM template

Status: TODO

Create a reusable NixOS VM template with:

- QEMU guest agent.
- NetBird optional module or bootstrap instructions.
- SSH hardening.
- Standard users/groups.
- Firewall defaults.
- Flake-based config.

### Infrastructure as code

Status: TODO/future

Potential future repo layout:

```text
infra/
  proxmox/
  netbird/
  dns/
  nixos/
  runbooks/
```

Possible tools:

- Nix flakes for NixOS guests.
- Terraform/OpenTofu for DNS/Proxmox if desired.
- SOPS/age for encrypted secrets if config becomes code-heavy.

## Priority 9 — recovery exercises

Status: TODO

Practice at least once:

- Hetzner Rescue login.
- Mount RAID/root filesystem.
- Chroot into Proxmox install.
- Re-enable SSH password temporarily if key access is broken.
- Remove public lockdown temporarily if needed.
- Restore VM backup to alternate ID.

Document timestamps and findings in `CHANGELOG.md`.

## Acceptance criteria for mature baseline

The system can be considered a mature small-production baseline when:

- [ ] Important local backup archives have been manually copied off-host to the desktop PC, or automated encrypted off-host backups exist.
- [ ] Restore test was completed successfully.
- [ ] Alerts reach a real mailbox or notification channel.
- [ ] NetBird broad/default policy is removed or confirmed safe.
- [x] Named admin account exists with 2FA.
- [ ] Canonical Forgejo repo and important backup archives have an off-host copy or mirror if required.
- [ ] Recovery artifacts are in password manager.
- [ ] Update cadence is documented and followed.
- [ ] No secrets are committed to git.
