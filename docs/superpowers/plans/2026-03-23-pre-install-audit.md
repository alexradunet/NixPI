# Pre-Install Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare Bloom OS for real-hardware installation on any x86_64 UEFI PC (Beelink EQ14 and friends), with improved resilience, QoL, and documentation.

**Architecture:** Targeted changes across NixOS modules, installer shell script, setup wizard, and docs. No new subsystems — the codebase is already clean. Each task is independent and commits cleanly.

**Tech Stack:** NixOS/Nix, bash, shellcheck (linting), `just config` (nix flake check), `just lint` (shellcheck)

**Spec:** `docs/superpowers/specs/2026-03-23-pre-install-audit-design.md`

---

## Pre-Work Notes (Read Before Starting)

- **§3b is already done:** `system-update.sh` already has `mkdir -p "$STATUS_DIR"` at line 24. Skip it.
- **hardware-configuration.nix is already imported:** `firstboot.nix` already generates a `configuration.nix` that imports `./hardware-configuration.nix` (line 55). The missing pieces are: adding `--no-filesystems` to the `nixos-generate-config` call, and replacing the virtio disk paths in `x86_64.nix`.
- **WiFi check (§3a) is mostly already done:** `step_network` at line 404 already has `|| ! has_wifi_device ||` guarding the internet-connected WiFi preference prompt. §3a only needs a log message when no WiFi device is detected, and to avoid offering WiFi setup in the no-internet branch.
- **`just config`** runs `nix flake check` — use it after every Nix change.
- **`just lint`** runs shellcheck — use it after every shell script change.
- **Wizard state directory** is `~/.nixpi/wizard-state/` (confirmed at wizard line 15). The spec incorrectly says `~/.nixpi/checkpoints/` — use `wizard-state`.

---

## File Map

| File | Change |
|------|--------|
| `core/os/hosts/x86_64.nix` | Replace `/dev/vda` paths with label-based paths; wire nixpi.timezone/keyboard |
| `core/os/modules/firstboot.nix` | Replace hardcoded `"x86_64-linux"` with Nix build-time interpolation |
| `core/os/modules/options.nix` | Add `nixpi.timezone` and `nixpi.keyboard` options |
| `core/os/modules/network.nix` | Add explanatory comment above firewall.interfaces line |
| `core/os/pkgs/installer/nixpi-installer.sh` | `--no-filesystems`, ESP 512MiB→1GiB, progress banners |
| `core/scripts/setup-wizard.sh` | Add `step_locale`, WiFi guard in no-internet branch |
| `tools/run-installer-iso.sh` | Confirmation prompt before `rm -rf ~/.nixpi` |
| `tools/check-real-hardware.sh` | New smoke test script |
| `docs/install.md` | Expand installation documentation |

---

## Task 1: Fix hardcoded disk paths in x86_64.nix

**Files:**
- Modify: `core/os/hosts/x86_64.nix:35-42`

The installer labels the root partition as `nixos` (`-L nixos`) and the boot partition as `boot` (`-L boot`). Using `/dev/disk/by-label/` references makes the config portable across NVMe, SATA, and USB installs without editing.

- [ ] **Step 1: Replace fileSystems entries**

In `core/os/hosts/x86_64.nix`, replace:
```nix
  fileSystems."/" = lib.mkDefault {
    device = "/dev/vda";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/vda1";
    fsType = "vfat";
  };
```
With:
```nix
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };
```

- [ ] **Step 2: Verify**

```bash
just config
```
Expected: exits 0. The label paths are valid Nix strings — the check validates module structure.

- [ ] **Step 3: Commit**

```bash
git add core/os/hosts/x86_64.nix
git commit -m "fix: use disk labels in x86_64.nix for real-hardware portability"
```

---

## Task 2: Make firstboot.nix system string dynamic

**Files:**
- Modify: `core/os/modules/firstboot.nix:72`

`bootstrapInstallHostFlake` is a `pkgs.writeShellScriptBin` that writes `/etc/nixos/flake.nix`. Inside its `''...''` Nix string, `${...}` is Nix build-time interpolation. Replace the hardcoded `"x86_64-linux"` with `${pkgs.stdenv.hostPlatform.system}` — Nix evaluates it at build time and bakes the correct arch string into the script binary.

- [ ] **Step 1: Edit firstboot.nix line 72**

Find:
```nix
      system = "x86_64-linux";
```
Replace with:
```nix
      system = "${pkgs.stdenv.hostPlatform.system}";
```

Note: line 84 also references `system` indirectly via `\${system}` (shell interpolation inside the Nix string). That line is fine — it references the shell variable `system` set on line 72/73 at runtime. Only line 72 needs changing.

- [ ] **Step 2: Verify**

```bash
just config
```
Expected: exits 0.

- [ ] **Step 3: Commit**

```bash
git add core/os/modules/firstboot.nix
git commit -m "fix: bake build platform into generated flake via pkgs.stdenv.hostPlatform.system"
```

---

## Task 3: Add --no-filesystems to installer nixos-generate-config call

**Files:**
- Modify: `core/os/pkgs/installer/nixpi-installer.sh:334`

The installer labels partitions (`-L nixos`, `-L boot`). Without `--no-filesystems`, `nixos-generate-config` also generates `fileSystems` entries using UUIDs — redundant with the labels already in `x86_64.nix`. The flag suppresses filesystem entries; available since NixOS 23.05 (the flake pins nixos-unstable).

- [ ] **Step 1: Edit nixpi-installer.sh line 334**

Find:
```bash
  nixos-generate-config --root "$ROOT_MOUNT"
```
Replace with:
```bash
  nixos-generate-config --no-filesystems --root "$ROOT_MOUNT"
```

- [ ] **Step 2: Lint**

```bash
just lint
```
Expected: no shellcheck errors.

- [ ] **Step 3: Commit**

```bash
git add core/os/pkgs/installer/nixpi-installer.sh
git commit -m "fix: add --no-filesystems to nixos-generate-config in installer"
```

---

## Task 4: Increase ESP from 512 MiB to 1 GiB

**Files:**
- Modify: `core/os/pkgs/installer/nixpi-installer.sh:23-24,306,309,312,272,274`

systemd-boot stores each NixOS generation's kernel+initrd in the ESP (~50-100 MB per generation). 512 MiB fills up at 3-4 generations. 1 GiB supports 10+ comfortably.

- [ ] **Step 1: Update usage comment (lines 23-24)**

Find:
```bash
- EFI system partition: 1 MiB - 512 MiB
- ext4 root partition: 512 MiB - end of disk or swap
```
Replace with:
```bash
- EFI system partition: 1 MiB - 1 GiB
- ext4 root partition: 1 GiB - end of disk or swap
```

- [ ] **Step 2: Update parted commands (lines 306-312)**

Find:
```bash
  parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 512MiB
  parted -s "$TARGET_DISK" set 1 esp on
  if [[ "$LAYOUT_MODE" == "swap" ]]; then
    parted -s -- "$TARGET_DISK" mkpart root ext4 512MiB "-$SWAP_SIZE"
    parted -s -- "$TARGET_DISK" mkpart swap linux-swap "-$SWAP_SIZE" 100%
  else
    parted -s "$TARGET_DISK" mkpart root ext4 512MiB 100%
  fi
```
Replace with:
```bash
  parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 1GiB
  parted -s "$TARGET_DISK" set 1 esp on
  if [[ "$LAYOUT_MODE" == "swap" ]]; then
    parted -s -- "$TARGET_DISK" mkpart root ext4 1GiB "-$SWAP_SIZE"
    parted -s -- "$TARGET_DISK" mkpart swap linux-swap "-$SWAP_SIZE" 100%
  else
    parted -s "$TARGET_DISK" mkpart root ext4 1GiB 100%
  fi
```

- [ ] **Step 3: Update layout summary strings (lines ~272-274)**

Find (two separate lines):
```bash
    layout_summary="EFI 512 MiB + ext4 root + swap (${SWAP_SIZE})"
```
and:
```bash
    layout_summary="EFI 512 MiB + ext4 root"
```
Replace both `512 MiB` occurrences with `1 GiB`.

- [ ] **Step 4: Lint**

```bash
just lint
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add core/os/pkgs/installer/nixpi-installer.sh
git commit -m "fix: increase ESP from 512 MiB to 1 GiB for multi-generation systemd-boot"
```

---

## Task 5: Resilience fixes — 3c and 3d

**Files:**
- Modify: `tools/run-installer-iso.sh:28-31`
- Modify: `core/os/modules/network.nix:107-109`

§3b (mkdir in system-update.sh) is already done — skip it.

- [ ] **Step 1: Add confirmation prompt in run-installer-iso.sh**

In `tools/run-installer-iso.sh`, find the reset block (lines 28-31):
```bash
echo "Resetting installer VM state..."
rm -f "$disk"
rm -f "$ovmf_vars"
rm -rf "$HOME/.nixpi"
```
Replace with:
```bash
echo "WARNING: This will delete ~/.nixpi (VM state reset). Continue? [y/N]"
read -r confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
echo "Resetting installer VM state..."
rm -f "$disk"
rm -f "$ovmf_vars"
rm -rf "$HOME/.nixpi"
```

- [ ] **Step 2: Add comment in network.nix**

In `core/os/modules/network.nix`, find lines 107-109:
```nix
    networking.firewall.interfaces = lib.mkIf securityCfg.enforceServiceFirewall {
      "${securityCfg.trustedInterface}".allowedTCPPorts = exposedPorts;
    };
```
Replace with:
```nix
    # trustedInterface defaults to "wt0" (NetBird mesh interface).
    # These firewall rules are inert until NetBird connects and wt0 exists.
    # During first-boot setup, SSH access relies on the physical interface,
    # which is opened separately via nixpi.security.ssh options.
    networking.firewall.interfaces = lib.mkIf securityCfg.enforceServiceFirewall {
      "${securityCfg.trustedInterface}".allowedTCPPorts = exposedPorts;
    };
```

- [ ] **Step 3: Verify**

```bash
just lint    # for run-installer-iso.sh
just config  # for network.nix
```
Expected: no errors from either.

- [ ] **Step 4: Commit**

```bash
git add tools/run-installer-iso.sh core/os/modules/network.nix
git commit -m "fix: add VM state wipe confirmation; document NetBird firewall timing"
```

---

## Task 6: Add nixpi.timezone and nixpi.keyboard options

**Files:**
- Modify: `core/os/modules/options.nix` (near end of `options.nixpi` block, before closing `};`)
- Modify: `core/os/hosts/x86_64.nix` (header and lines 29-33)

Note: The spec defines `nixpi.locale` but the wizard collects *keyboard layout*, which is a different thing from i18n locale. To avoid wiring a keyboard string into `i18n.defaultLocale`, this plan adds `nixpi.keyboard` (→ `console.keyMap` + `xkb.layout`) alongside `nixpi.timezone`. The `i18n.defaultLocale` stays hardcoded at `"en_US.UTF-8"` for now.

- [ ] **Step 1: Add options to options.nix**

In `core/os/modules/options.nix`, find the closing `};` of the `options.nixpi` block (line ~261, after the `update` sub-block closes). Insert before it:

```nix
    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = ''
        System timezone. Any valid IANA timezone string (e.g. "Europe/Paris").
        Set interactively by the first-boot setup wizard.
      '';
    };

    keyboard = lib.mkOption {
      type = lib.types.str;
      default = "us";
      description = ''
        Console and X keyboard layout (e.g. "fr", "de", "us").
        Set interactively by the first-boot setup wizard.
      '';
    };
```

- [ ] **Step 2: Wire options into x86_64.nix**

Change the `{ lib, ... }:` header to `{ lib, config, ... }:` so `config` is available.

Replace:
```nix
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  networking.networkmanager.enable = true;
  services.xserver.xkb = { layout = "us"; variant = ""; };
  console.keyMap = "us";
```
With:
```nix
  time.timeZone = config.nixpi.timezone;
  i18n.defaultLocale = "en_US.UTF-8";
  networking.networkmanager.enable = true;
  services.xserver.xkb = { layout = config.nixpi.keyboard; variant = ""; };
  console.keyMap = config.nixpi.keyboard;
```

- [ ] **Step 3: Verify**

```bash
just config
```
Expected: exits 0. Default values preserve existing UTC/us behavior.

- [ ] **Step 4: Commit**

```bash
git add core/os/modules/options.nix core/os/hosts/x86_64.nix
git commit -m "feat: add nixpi.timezone and nixpi.keyboard options wired into system config"
```

---

## Task 7: Add locale wizard step and WiFi guard (§5a + §3a)

**Files:**
- Modify: `core/scripts/setup-wizard.sh`

Both changes touch the same file — do them in one pass.

**§3a — WiFi guard in no-internet branch**

The internet-connected branch already guards correctly at line 404 (`|| ! has_wifi_device ||`). The no-internet branch (line ~459) offers "Launch WiFi setup" even if no WiFi hardware exists — confusing on Ethernet-only machines.

- [ ] **Step 1: Add WiFi guard to no-internet branch**

In `step_network()`, find (line ~459):
```bash
	echo "No network connection detected."
	if [[ "$NONINTERACTIVE_SETUP" -eq 1 ]]; then
		echo "Skipping interactive network setup in noninteractive mode."
		mark_done network
		return
	fi
	echo ""
	echo "Options:"
	echo "  1) Launch WiFi setup (recommended)"
	echo "  2) Skip and configure network later"
```
Replace with:
```bash
	echo "No network connection detected."
	if [[ "$NONINTERACTIVE_SETUP" -eq 1 ]]; then
		echo "Skipping interactive network setup in noninteractive mode."
		mark_done network
		return
	fi
	if ! has_wifi_device; then
		log "no WiFi hardware detected, skipping WiFi preference"
		echo ""
		echo "Options:"
		echo "  1) Skip and configure network later (connect Ethernet before continuing)"
		echo ""
	else
		echo ""
		echo "Options:"
		echo "  1) Launch WiFi setup (recommended)"
		echo "  2) Skip and configure network later"
		echo ""
	fi
```

**Important:** Do not call `mark_done network` here. The user still has no network — let the existing loop below handle the choice and `mark_done`. Only the *display* of options changes.

**§5a — step_locale function**

The new step writes timezone and keyboard to `/etc/nixos/nixpi-host.nix` by rewriting the whole file (idempotent — safe to re-run). It then triggers `nixos-rebuild switch` to apply.

- [ ] **Step 2: Add step_locale function**

Find `step_password()` at line 353 and insert the new function immediately before it:

```bash
step_locale() {
	echo ""
	echo "--- Locale & Timezone ---"
	echo "Common timezones: UTC, Europe/Paris, Europe/London, America/New_York, America/Los_Angeles, Asia/Tokyo"
	echo "Common keyboard layouts: us, uk, fr, de, es"
	echo ""

	local tz kb
	tz="${NIXPI_TIMEZONE:-}"
	kb="${NIXPI_KEYBOARD:-}"

	if [[ -z "$tz" ]]; then
		read -rp "Timezone [UTC]: " tz
		tz="${tz:-UTC}"
	else
		echo "Timezone (prefill): $tz"
	fi

	if [[ -z "$kb" ]]; then
		read -rp "Keyboard layout [us]: " kb
		kb="${kb:-us}"
	else
		echo "Keyboard layout (prefill): $kb"
	fi

	# Read existing values from nixpi-host.nix (preserve hostname and primaryUser)
	local hostname primary_user
	hostname="$(grep 'networking\.hostName' /etc/nixos/nixpi-host.nix 2>/dev/null \
		| sed 's/.*= "\(.*\)".*/\1/' || echo "nixpi")"
	primary_user="$(grep 'nixpi\.primaryUser' /etc/nixos/nixpi-host.nix 2>/dev/null \
		| sed 's/.*= "\(.*\)".*/\1/' || echo "pi")"

	# Rewrite nixpi-host.nix in full (idempotent)
	local tmpfile
	tmpfile="$(mktemp /tmp/nixpi-host.XXXXXX.nix)"
	cat > "$tmpfile" <<EOF
{ ... }:
{
  networking.hostName = "$hostname";
  nixpi.primaryUser = "$primary_user";
  nixpi.timezone = "$tz";
  nixpi.keyboard = "$kb";
}
EOF
	root_command sh -c "cat > /etc/nixos/nixpi-host.nix" < "$tmpfile"
	rm -f "$tmpfile"

	echo "Applying locale settings (this may take a minute)..."
	root_command nixpi-bootstrap-nixos-rebuild-switch "$hostname" || {
		echo "warning: nixos-rebuild failed; locale settings saved but not applied yet." >&2
	}

	mark_done locale
}
```

- [ ] **Step 3: Insert locale step in main()**

In `main()` (line ~830), find:
```bash
	step_done network  || step_network
	step_done password || step_password
```
Replace with:
```bash
	step_done network  || step_network
	step_done locale   || step_locale
	step_done password || step_password
```

- [ ] **Step 4: Update prefill comment**

Find lines 31-33:
```bash
# Supported vars: PREFILL_NETBIRD_KEY, PREFILL_NAME, PREFILL_EMAIL,
#                 PREFILL_USERNAME, PREFILL_MATRIX_PASSWORD,
#                 PREFILL_PRIMARY_PASSWORD
```
Replace with:
```bash
# Supported vars: PREFILL_NETBIRD_KEY, PREFILL_NAME, PREFILL_EMAIL,
#                 PREFILL_USERNAME, PREFILL_MATRIX_PASSWORD,
#                 PREFILL_PRIMARY_PASSWORD, NIXPI_TIMEZONE, NIXPI_KEYBOARD
```

- [ ] **Step 5: Verify sudo coverage**

`step_locale` calls `root_command nixpi-bootstrap-nixos-rebuild-switch "$hostname"`. Confirm this is already covered by the passwordless sudo rule in `firstboot.nix`:

```bash
grep "nixos-rebuild-switch" core/os/modules/firstboot.nix
```
Expected: line with `"/run/current-system/sw/bin/nixpi-bootstrap-nixos-rebuild-switch *"` and `"NOPASSWD"`. If present, no change needed. If missing, add the rule to the sudo rules list in `firstboot.nix`.

- [ ] **Step 6: Lint**

```bash
just lint
```
Expected: no shellcheck errors.

- [ ] **Step 7: Commit**

```bash
git add core/scripts/setup-wizard.sh
git commit -m "feat: add locale/timezone wizard step; guard WiFi menu on no-WiFi hardware"
```

---

## Task 8: Real-hardware smoke test script

**Files:**
- Create: `tools/check-real-hardware.sh`

- [ ] **Step 1: Confirm service unit names**

```bash
grep -r "systemd.services\." core/os/modules/ --include="*.nix" | grep -o '"[a-z-]*\.service"' | sort -u
```
Expected units include: `continuwuity.service`, `nixpi-daemon.service`, `nixpi-home.service`, `nixpi-element-web.service`.

Also confirm Element Web port:
```bash
grep "elementWeb.*port\|port.*8081" core/os/modules/options.nix
```
Expected: port 8081 (default).

- [ ] **Step 2: Write check-real-hardware.sh**

Create `tools/check-real-hardware.sh`:

```bash
#!/usr/bin/env bash
# check-real-hardware.sh — Post-install smoke test for Bloom OS on real hardware.
# Usage: ./tools/check-real-hardware.sh <ip-or-hostname>
#
# SSHes in as the 'pi' user and runs 10 checks. Prints PASS/FAIL per check.
# Exits 0 if all pass, 1 if any fail.
set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <ip-or-hostname>" >&2
  exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"
SSH="ssh $SSH_OPTS pi@$TARGET"
PASS=0
FAIL=0

check() {
  local name="$1"
  local cmd="$2"
  if $SSH "$cmd" &>/dev/null; then
    printf "  PASS  %s\n" "$name"
    PASS=$((PASS + 1))
  else
    printf "  FAIL  %s\n" "$name"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Bloom OS Real-Hardware Smoke Test: $TARGET ==="
echo ""

check "UEFI boot mode"          "test -d /sys/firmware/efi"
check "Root filesystem mounted" "mountpoint -q /"
check "Boot filesystem mounted" "mountpoint -q /boot"
check "systemd-boot present"    "test -f /boot/EFI/systemd/systemd-bootx64.efi"
check "Network reachable"       "ping -c1 -W3 1.1.1.1"
check "NetworkManager active"   "systemctl is-active NetworkManager"
check "Matrix service active"   "systemctl is-active continuwuity"
check "Pi daemon active"        "systemctl is-active nixpi-daemon"
check "Element Web accessible"  "curl -sf http://localhost:8081 > /dev/null"
check "Wizard state dir exists" "test -d ~/.nixpi/wizard-state"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
```

- [ ] **Step 3: Make executable**

```bash
chmod +x tools/check-real-hardware.sh
```

- [ ] **Step 4: Lint**

```bash
shellcheck tools/check-real-hardware.sh
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add tools/check-real-hardware.sh
git commit -m "feat: add check-real-hardware.sh post-install smoke test"
```

---

## Task 9: Installer progress banners

**Files:**
- Modify: `core/os/pkgs/installer/nixpi-installer.sh:419-428` (inside `main()`)

The installer's `main()` calls functions in this order (lines 420-428):
```
ensure_root → choose_disk → prompt_inputs → prompt_password → choose_layout
→ normalize_layout_inputs → confirm_install → run_install → echo "NixPI install completed."
```

`run_install_steps` (called inside `run_install`) handles partitioning, formatting, generate-config, and nixos-install. It already uses `log_step` for internal steps. We add 5 user-visible banners at the major phase boundaries in `main()` and one inside `run_install_steps`.

- [ ] **Step 1: Add banners in main()**

In `main()`, find lines 419-428:
```bash
  ensure_root
  choose_disk
  prompt_inputs
  prompt_password
  choose_layout
  normalize_layout_inputs
  confirm_install
  run_install

  echo "NixPI install completed. Reboot when ready."
```
Replace with:
```bash
  ensure_root
  echo ""
  echo "=== [1/5] Disk selection ==="
  choose_disk
  prompt_inputs
  prompt_password
  choose_layout
  normalize_layout_inputs
  confirm_install
  echo ""
  echo "=== [2/5] Partitioning & formatting ==="
  echo ""
  echo "=== [3/5] Installing NixOS — this may take 10-20 minutes ==="
  run_install
  echo ""
  echo "=== [5/5] Finalizing ==="
  echo "NixPI install completed. Reboot when ready."
```

- [ ] **Step 2: Add [4/5] banner inside run_install_steps**

In `run_install_steps()`, find the nixos-install block (lines ~345-353):
```bash
  if [[ -n "$SYSTEM_CLOSURE" ]]; then
    log_step "Installing prebuilt system closure"
    nixos-install --no-root-passwd --system "$SYSTEM_CLOSURE" --root "$ROOT_MOUNT"
  else
    log_step "Running nixos-install from configuration.nix"
    NIX_CONFIG="experimental-features = nix-command flakes" \
      NIXOS_INSTALL_BOOTLOADER=1 \
      nixos-install --no-root-passwd --root "$ROOT_MOUNT" --no-channel-copy -I "nixos-config=$ROOT_MOUNT/etc/nixos/configuration.nix"
  fi
```
Insert before the `if` block:
```bash
  echo ""
  echo "=== [4/5] Writing boot configuration ==="
```

- [ ] **Step 3: Lint**

```bash
just lint
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add core/os/pkgs/installer/nixpi-installer.sh
git commit -m "feat: add progress banners [1/5]-[5/5] to nixpi-installer"
```

---

## Task 10: Expand docs/install.md

**Files:**
- Modify: `docs/install.md`

- [ ] **Step 1: Read current install.md**

```bash
cat docs/install.md
```

- [ ] **Step 2: Replace contents**

Overwrite `docs/install.md` with:

```markdown
# Installing Bloom OS

## Supported Hardware

Any modern x86_64 UEFI PC with:
- **CPU:** 64-bit Intel or AMD (x86_64)
- **RAM:** 4 GB minimum, 8 GB+ recommended
- **Storage:** 32 GB minimum (installer creates a 1 GiB EFI partition + ext4 root)
- **Boot:** UEFI (not legacy BIOS)
- **Tested on:** Beelink EQ14

**Disable Secure Boot** in your UEFI settings before installing.

---

## Creating the Installer USB

Build the ISO (from a NixOS machine with the repo checked out):

```bash
just iso
```

Write it to a USB drive — **this erases the USB**:

```bash
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

Replace `/dev/sdX` with your USB device (use `lsblk` to identify it). You can also use [Balena Etcher](https://etcher.balena.io/) or [Ventoy](https://www.ventoy.net/).

---

## Installing

1. Boot the target machine from the USB (UEFI boot menu: usually F12 or Del at startup)
2. The installer starts automatically. If not, run `nixpi-installer` in the terminal
3. Select the target disk — **all data on the disk will be erased**
4. Choose a disk layout (with or without swap)
5. Enter a hostname, username, and temporary password
6. Confirm and wait — installation takes 10-30 minutes (most time is downloading Nix packages)
7. When complete, remove the USB and reboot

The installer log is saved to `/tmp/nixpi-installer.log`.

---

## First Boot

After rebooting, the XFCE desktop appears and the setup wizard launches automatically in a terminal:

1. **Network** — connect to WiFi or confirm Ethernet is active
2. **Locale & Timezone** — choose your timezone and keyboard layout
3. **Password** — set your permanent user password
4. **System upgrade** — promotes the installer image to the full Bloom OS appliance (requires internet, 5-15 minutes)
5. **NetBird** — optionally join the mesh network for remote access
6. **Matrix** — creates your local Matrix account for Pi to talk to you
7. **Done** — Pi agent starts

If the wizard is interrupted, re-open the terminal — it resumes from the last completed step.

Logs: `~/.nixpi/wizard.log`

---

## Setting Up for a Friend

Pre-fill setup answers by creating a `prefill.env` file on the installed machine before first boot:

```bash
# Place at: ~/.nixpi/prefill.env
PREFILL_NETBIRD_KEY=your-netbird-setup-key
PREFILL_NAME="Alex Doe"
PREFILL_EMAIL=alex@example.com
PREFILL_USERNAME=alex
PREFILL_MATRIX_PASSWORD=your-matrix-password
PREFILL_PRIMARY_PASSWORD=their-login-password
NIXPI_TIMEZONE=Europe/Paris
NIXPI_KEYBOARD=fr
```

When running the dev VM (`just vm`), this file is automatically shared from `~/.nixpi/prefill.env` on your host.

---

## Troubleshooting

**Installer failed:**
Check `/tmp/nixpi-installer.log`. Common causes: insufficient disk space, no internet during package download.

**Setup wizard failed or stuck:**
Check `~/.nixpi/wizard.log`. Re-run with: open a terminal and type `setup-wizard`. It resumes from the last completed step.

**Services not starting:**
```bash
systemctl status continuwuity      # Matrix server
systemctl status nixpi-daemon      # Pi agent
systemctl status nixpi-home        # Home page
systemctl status nixpi-element-web # Element Web client
```

**Validate a fresh install remotely:**
```bash
./tools/check-real-hardware.sh <machine-ip>
```
```

- [ ] **Step 3: Commit**

```bash
git add docs/install.md
git commit -m "docs: expand install.md with hardware, steps, first boot, and troubleshooting"
```

---

## Final Verification

- [ ] `just config` — all Nix checks pass
- [ ] `just lint` — all shell scripts pass shellcheck
- [ ] `git log --oneline -12` — all 10 commits present and clean
