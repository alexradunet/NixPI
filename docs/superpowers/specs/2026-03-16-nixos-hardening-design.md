# NixOS Hardening Design

Date: 2026-03-16
Status: Approved

## Goal

Apply NixOS/systemd best practices to the Bloom OS NixOS modules: systemd service sandboxing, SSH configuration fix, and nixpkgs registry pinning.

## Scope

Four targeted changes across five files. No new modules, no new abstractions.

---

## Changes

### 1. `core/os/modules/bloom-matrix.nix` — Full systemd sandboxing

Add the following to `bloom-matrix` `serviceConfig`:

```nix
PrivateTmp              = true;
ProtectSystem           = "strict";
ProtectHome             = true;
NoNewPrivileges         = true;
CapabilityBoundingSet   = "";
AmbientCapabilities     = "";
RestrictNamespaces      = true;
LockPersonality         = true;
# NOTE: safe for Rust/conduwuit (no JIT). If bloom-matrix fails to start,
# disable this option first — it blocks W+X memory mappings.
MemoryDenyWriteExecute  = true;
RestrictRealtime        = true;
RestrictSUIDSGID        = true;
SystemCallFilter        = [ "@system-service" ];
SystemCallArchitectures = "native";
```

`DynamicUser`, `StateDirectory`, and `RuntimeDirectory` are already present and remain unchanged.

### 2. `core/os/modules/bloom-network.nix` — Fix SSH pubkey authentication

Change:
```nix
PubkeyAuthentication = "no";
```
To:
```nix
PubkeyAuthentication = true;
```

`PasswordAuthentication = true` stays for first-boot SSH access before keys are configured.

### 3. `core/os/modules/bloom-update.nix` — Partial hardening on oneshot service

Add to `bloom-update` `serviceConfig`:

```nix
PrivateTmp = true;
# ProtectHome omitted — bloom-update.sh writes status to /home/pi/.bloom/
# ProtectSystem omitted — nixos-rebuild writes to /nix/store and /etc
# NoNewPrivileges omitted — nixos-rebuild requires privilege escalation
```

Only `PrivateTmp` is safe to add here given the script's access requirements.

### 4. `core/os/hosts/x86_64.nix` — Pin nixpkgs in device registry

Add:
```nix
nix.registry.nixpkgs.flake = nixpkgs;
```

Requires two changes:
1. `x86_64.nix` function signature: `{ pkgs, lib, nixpkgs, ... }:` (add `nixpkgs`)
2. `flake.nix`: add `nixpkgs` to `specialArgs` in all four call sites (`qcow2`, `raw`, `iso`, `nixosConfigurations.bloom-x86_64`)

---

## Non-Changes (Deferred)

- `bloom-shell.nix` `mutableUsers`: `initialPassword` is correct for the first-boot wizard flow; `mutableUsers = false` would prevent runtime password changes.
- WiFi PSK secrets: TODO already documented; proper fix requires sops-nix or agenix integration (separate effort).
- `bloom-app.nix` stale lock cleanup: existing `C` tmpfile rule is correct; `/tmp/.bloom-pi-session` is a directory lock cleaned by `trap` in bash_profile.

---

## Risk

`MemoryDenyWriteExecute = true` on bloom-matrix is the only option with runtime risk. conduwuit is a Rust binary (no JIT) so this is expected to be safe. A comment is added in the code so the operator knows to remove it first if the service fails to start.
