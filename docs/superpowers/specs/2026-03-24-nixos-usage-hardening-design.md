# NixOS Usage Hardening & Simplification

**Date:** 2026-03-24
**Status:** Approved

## Summary

After a thorough audit of the NixOS feature usage in pi-bloom (comparing against current
nixpkgs documentation and source), all five major NixOS features in use are correct. This
spec captures two targeted improvements: full portability compliance for `system.services`
service modules, and a minor type-alias simplification in `options.nix`.

## Background

### Features audited

| Feature | Status in nixpkgs | Current usage |
|---|---|---|
| `system.services` + `_class = "service"` + `process.argv` | New (NixOS 25.11), "in development" | Correct |
| `lib.types.pathWith { absolute; inStore }` | Stable | Correct |
| `lib.modules.importApply` | Stable (since 24.11) | Correct and idiomatic |
| `services.matrix-continuwuity` | Stable (since 25.05) | Correct |
| `services.netbird.clients` | Stable | Correct |

### Gap identified

The nixpkgs contributor guide (`nixos/README-modular-services.md`) requires that
`systemd.service` blocks inside `_class = "service"` modules be wrapped in
`lib.optionalAttrs (options ? systemd) { ... }`. This guard makes the service module
portable across init systems that may be supported in the future. All five service files
in this repo set `systemd.service` directly without the guard — technically correct for
NixOS today, but non-compliant with the contributor spec and fragile against future
`system.services` API evolution.

## Changes

### 1. `core/os/modules/options.nix` — type alias simplification

Replace the manual `pathWith` call for `externalAbsolutePath` with the named alias:

```nix
# before
absolutePath         = lib.types.pathWith { absolute = true; };
externalAbsolutePath = lib.types.pathWith { absolute = true; inStore = false; };

# after
absolutePath         = lib.types.pathWith { absolute = true; };  # unchanged — no named alias exists
# Absolute path that must not be a Nix store path (user-managed external state).
externalAbsolutePath = lib.types.externalPath;
```

`lib.types.externalPath` is exactly `pathWith { absolute = true; inStore = false; }`.
`absolutePath` (`pathWith { absolute = true; }`) has no equivalent named alias and is
intentionally left as-is.

### 2–6. All five service files — portability guard + comment

Apply to:
- `core/os/services/nixpi-broker.nix`
- `core/os/services/nixpi-daemon.nix`
- `core/os/services/nixpi-home.nix`
- `core/os/services/nixpi-element-web.nix`
- `core/os/services/nixpi-update.nix`

**Module signature change:** `options` must be added as an explicit module argument so
`options ? systemd` can be evaluated inside the `config` block. `options` is a standard
module argument available in all `lib.evalModules`-based module systems, including the
`system.services` evaluator.

```nix
# before (e.g. nixpi-broker.nix)
{ config, lib, ... }:

# after
{ config, lib, options, ... }:
```

For service files that use the `importApply` outer-curry pattern, the `options` argument
goes on the inner (module) function:

```nix
# before (e.g. nixpi-daemon.nix)
{ pkgs }:
{ config, lib, ... }:

# after
{ pkgs }:
{ config, lib, options, ... }:
```

**Config block pattern:** All non-systemd config keys (`process.argv`, `configData`, etc.)
remain in the base `config = { ... }` attrset. Only `systemd.service` moves outside it
into the `optionalAttrs` block:

```nix
# before
config = {
  process.argv = [ ... ];
  configData = { ... };        # present in nixpi-home.nix and nixpi-element-web.nix
  systemd.service = { ... };
};

# after
config = {
  process.argv = [ ... ];
  configData = { ... };        # stays here — not systemd-specific
  # `system.services` portability: guard systemd-specific config so this module
  # can be consumed by non-systemd init systems if NixOS ever supports them.
  # See nixpkgs nixos/README-modular-services.md.
} // lib.optionalAttrs (options ? systemd) {
  systemd.service = { ... };
};
```

No service behaviour changes. The guard evaluates to the same result on NixOS (where
`options ? systemd` is always true).

## Files changed

1. `core/os/modules/options.nix` — swap `pathWith` → `lib.types.externalPath` for `externalAbsolutePath`
2. `core/os/services/nixpi-broker.nix` — add `options` arg, portability guard + comment
3. `core/os/services/nixpi-daemon.nix` — add `options` arg, portability guard + comment
4. `core/os/services/nixpi-home.nix` — add `options` arg, portability guard + comment (keep `configData` in base config)
5. `core/os/services/nixpi-element-web.nix` — add `options` arg, portability guard + comment (keep `configData` in base config)
6. `core/os/services/nixpi-update.nix` — add `options` arg, portability guard + comment

## Testing

- `nix flake check` (specifically `checks.config`) validates the full module evaluation
- `nixpi-modular-services` NixOS test directly exercises `system.services` and `_class = "service"` behavior — most relevant for this change
- Existing `nixos-smoke` and `nixos-full` lanes exercise all service files at runtime
- No new tests needed — this is a refactor with no behaviour change
