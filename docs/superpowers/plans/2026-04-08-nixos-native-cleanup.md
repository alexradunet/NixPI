# NixOS Native Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace custom update and networking glue with more native NixOS configuration while restoring clean flake evaluation.

**Architecture:** Fix the currently broken options-validation test first, then migrate the updater to `system.autoUpgrade` and simplify status reporting around that native path. After that, move WireGuard from hand-built `systemd.network` and boot-time mutation scripts toward native `networking.wireguard` configuration, removing imperative NetworkManager profile rewriting where possible.

**Tech Stack:** Nix flakes, NixOS modules, NixOS test driver, systemd, WireGuard

---

### Task 1: Restore Options Validation Coverage

**Files:**
- Modify: `tests/nixos/nixpi-options-validation.nix`
- Run: `XDG_CACHE_HOME=/tmp/nix-cache nix flake check --no-build`

- [ ] **Step 1: Write the failing test**

Keep the stale override in `tests/nixos/nixpi-options-validation.nix` so eval still fails on the removed `nixpi.services.home.port` option.

- [ ] **Step 2: Run test to verify it fails**

Run: `XDG_CACHE_HOME=/tmp/nix-cache nix flake check --no-build`
Expected: FAIL mentioning `nodes.overrides.nixpi.services`

- [ ] **Step 3: Write minimal implementation**

Replace the removed override with an override that still exercises supported module options, such as `nixpi.agent.autonomy = "observe";` and any security overrides already asserted in the test script.

- [ ] **Step 4: Run test to verify it passes**

Run: `XDG_CACHE_HOME=/tmp/nix-cache nix flake check --no-build`
Expected: the options-validation failure is gone

### Task 2: Migrate Updates to Native NixOS Auto Upgrade

**Files:**
- Modify: `core/os/modules/update.nix`
- Modify: `tests/nixos/nixpi-update.nix`
- Delete or stop referencing: `core/os/system-update.ts`
- Delete or stop referencing: `core/os/pkgs/nixpi-update/default.nix`

- [ ] **Step 1: Write the failing test**

Update `tests/nixos/nixpi-update.nix` so it expects a native `nixpi-update.service` built from `system.autoUpgrade`, while preserving the repo-specific flake target and status-file expectations.

- [ ] **Step 2: Run test to verify it fails**

Run: `XDG_CACHE_HOME=/tmp/nix-cache nix build .#checks.x86_64-linux.nixpi-update --no-link`
Expected: FAIL because the module still defines the custom updater

- [ ] **Step 3: Write minimal implementation**

Refactor `core/os/modules/update.nix` to use `system.autoUpgrade.enable`, `system.autoUpgrade.flake = "/etc/nixos";`, and the existing timing options. Keep only the smallest native wrapper needed for any NixPI-specific status output, or remove status output if tests no longer require it.

- [ ] **Step 4: Run test to verify it passes**

Run: `XDG_CACHE_HOME=/tmp/nix-cache nix build .#checks.x86_64-linux.nixpi-update --no-link`
Expected: PASS

### Task 3: Move WireGuard Toward Native NixOS WireGuard

**Files:**
- Modify: `core/os/modules/network.nix`
- Modify: `core/os/modules/options/wireguard.nix`
- Modify: `tests/nixos/nixpi-wireguard.nix`

- [ ] **Step 1: Write the failing test**

Adjust `tests/nixos/nixpi-wireguard.nix` to assert the artifacts and behavior of the native `networking.wireguard.interfaces` path instead of the custom `systemd.network` compatibility layer.

- [ ] **Step 2: Run test to verify it fails**

Run: `XDG_CACHE_HOME=/tmp/nix-cache nix build .#checks.x86_64-linux.nixpi-wireguard --no-link`
Expected: FAIL because the module still emits the old networkd-based files and compatibility unit behavior

- [ ] **Step 3: Write minimal implementation**

Replace custom `systemd.network` netdev/network declarations and `wireguard-${interface}` compatibility service with native `networking.wireguard.interfaces.${interface}` configuration. Re-enable support for options like `dynamicEndpointRefreshSeconds` if the native module exposes them.

- [ ] **Step 4: Run test to verify it passes**

Run: `XDG_CACHE_HOME=/tmp/nix-cache nix build .#checks.x86_64-linux.nixpi-wireguard --no-link`
Expected: PASS

### Task 4: Remove Imperative NetworkManager Preference Mutation

**Files:**
- Modify: `core/os/modules/network.nix`
- Update tests only if coverage needs to move

- [ ] **Step 1: Write the failing test**

Add or adjust assertions so the repo no longer depends on the `nixpi-prefer-wifi` oneshot service or the `nmcli` mutation script existing.

- [ ] **Step 2: Run test to verify it fails**

Run: `XDG_CACHE_HOME=/tmp/nix-cache nix flake check --no-build`
Expected: FAIL if any test or topology still depends on the custom service

- [ ] **Step 3: Write minimal implementation**

Delete the `nixpi-prefer-wifi` script/service from `core/os/modules/network.nix`. If specific declarative NetworkManager profiles are actually needed later, introduce them via `networking.networkmanager.ensureProfiles`.

- [ ] **Step 4: Run test to verify it passes**

Run: `XDG_CACHE_HOME=/tmp/nix-cache nix flake check --no-build`
Expected: PASS for this slice, modulo any unrelated pre-existing failures
