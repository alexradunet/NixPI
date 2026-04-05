# Simplified Install Flow Design

**Date:** 2026-04-05  
**Status:** Approved  
**Targets:** Intel N150 mini PC, x86_64 VPS

---

## Problem

The current install flow has two stages and too many moving parts:

1. Installer ISO boots, installs a **minimal** NixOS (a fragile `nixpi-install-module.nix.in` template with `@placeholder@` substitutions)
2. Web wizard clones the repo from GitHub and runs `nixos-rebuild switch` to promote to full system

This causes: template drift, GitHub dependency during setup, complex `nixpi-setup-apply.sh` (~100 lines), two separate VM flows (qcow2 dev VM + installer ISO) that diverge, and fail2ban banning itself during dev.

---

## Design

### Core Principle

The ISO contains the **full NixOS system closure pre-baked**. The installer copies it to disk. The web wizard does minimal post-install config only. No nixos-rebuild, no internet required, no git clone.

---

### Install Flow (end to end)

1. `just iso` — builds ISO with full system closure included
2. Boot ISO on target machine (mini PC or VPS)
3. `nixpi-installer` runs — collects disk, hostname, username, password
4. Installer partitions disk, writes `nixpi-install.nix` (4 lines: primaryUser, hostname, hashedPassword, passwordAuthentication), calls `nixos-install --system <pre-built-closure>`
5. Reboot — nixpi-chat is running on port 80 from first boot
6. Browser opens `http://<ip>` → redirected to `/setup`
7. Wizard shows: welcome message + Netbird setup key field (optional, recommended) + Complete button
8. On submit: `sudo -n nixpi-setup-apply` runs `netbird up` (if key provided), writes system-ready marker
9. Redirects to chat UI — user runs `pi /login` and `pi /model` in the terminal to configure AI provider

**No nixos-rebuild. No git clone. No internet required.**

---

### Components

#### Installer (`nixpi-installer.sh`)

- Reads `prefill.env` (from same dir as script, or via `--prefill <file>` flag) to skip interactive prompts
- Writes `/etc/nixos/nixpi-install.nix` as a clean bash heredoc — no placeholder substitution:
  ```nix
  { ... }: {
    nixpi.primaryUser = "alex";
    networking.hostName = "nixpi-mini";
    users.users.alex.hashedPassword = "$6$...";
    nixpi.security.ssh.passwordAuthentication = true;
  }
  ```
- Writes `/etc/nixos/configuration.nix` importing hardware-configuration.nix + nixpi-install.nix + x86_64 host module from nix store
- Calls `nixos-install --no-channel-copy` — all packages already in the ISO's nix store (no downloads). If usernames are always fixed (e.g. always "nixpi"), `--system <pre-built-closure>` can be used instead to skip evaluation entirely.

#### Web Wizard (`setup.ts`)

Stripped to minimum:
- Welcome message explaining Netbird (mesh VPN — lets you reach machine from anywhere)
- Netbird setup key field — optional, marked "strongly recommended"
- Complete Setup button
- On completion → redirect to chat UI with notice to run `pi /login` in the terminal

Removed fields: name, email, username, password, Claude API key.

#### Apply Script (`nixpi-setup-apply.sh`)

Rewritten from scratch, ~15 lines:
```bash
if [[ -n "${SETUP_NETBIRD_KEY:-}" ]]; then
  netbird up --setup-key "${SETUP_NETBIRD_KEY}" --foreground=false
fi
mkdir -p "$(dirname "${SYSTEM_READY_FILE}")"
touch "${SYSTEM_READY_FILE}"
chown "${PRIMARY_USER}:${PRIMARY_USER}" "${SYSTEM_READY_FILE}"
```

Still called via `sudo -n` from the chat server (netbird requires root).

#### Dev Testing (prefill)

`prefill.env` in project root (gitignored) provides non-interactive values:
```
PREFILL_HOSTNAME=nixpi-test
PREFILL_USERNAME=alex
PREFILL_PASSWORD=testpass
PREFILL_NETBIRD_KEY=
```

`just vm-install-iso` reads this file and passes values to the installer. The installer writes a `/etc/nixpi/prefill.env` on the installed system if prefill values are present. On first boot the wizard backend checks for this file — if found, it auto-submits (calls the apply script immediately and redirects to chat without showing the form).

---

### What Gets Deleted

| File/Recipe | Reason |
|---|---|
| `nixpi-install-module.nix.in` | Replaced by clean heredoc in installer |
| `core/os/hosts/x86_64-vm.nix` | No more qcow2 dev VM |
| `tools/run-qemu.sh` | No more qcow2 dev VM |
| `justfile`: `vm`, `vm-daemon`, `vm-ssh`, `vm-stop`, `vm-kill`, `vm-logs`, `qcow2` | No more qcow2 dev VM |
| `NIXPI_BOOTSTRAP_REPO` / git clone logic | Setup no longer clones repo |
| Wizard fields: name, email, username, password, Claude API key | Not needed |

### What Gets Kept

| File | Change |
|---|---|
| `tools/run-installer-iso.sh` | Add prefill support |
| `tools/dev-key` + `tools/dev-key.pub` | Still used for SSH into installed VM |
| `core/os/pkgs/installer/nixpi-installer.sh` | Read prefill, write clean nixpi-install.nix, use --system |
| `core/chat-server/setup.ts` | Strip to Netbird field only |
| `core/os/modules/` | All kept as-is |
| `flake.nix` | Remove desktop-vm, add pre-built closure to installer ISO |

### New

| File | Purpose |
|---|---|
| `prefill.env.example` | Documents dev prefill variables (committed) |
| `prefill.env` | Actual dev values (gitignored) |

---

### fail2ban

Disabled in the installer ISO host config (`core/os/hosts/installer-iso.nix`) to prevent it from banning `10.0.2.2` (the QEMU NAT host address) during dev testing.

---

### Testing

- `just iso` — build ISO (only needed when NixOS config changes)
- `just vm-install-iso` — full install cycle, non-interactive with prefill
- `just vm-ssh` — SSH into installed VM with dev key
- Existing checks (`check-installer`, `check-installer-smoke`) remain valid
