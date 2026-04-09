# Host-Owned NixPI Bootstrap Design

## Summary

Move NixPI to a host-owned integration model with no backward-compatibility lane.

End state:

- `/etc/nixos` is always the authoritative system root
- steady-state rebuilds always target `/etc/nixos#nixos`
- NixPI is layered into the host configuration as a module, not installed as the whole machine profile
- `nixos-anywhere` is used only to install a plain machine/provider-appropriate NixOS base system
- OVH uses the same post-install bootstrap path as any other NixOS machine

This is a clean break. Existing product assumptions that `nixos-anywhere` installs the final NixPI system directly are removed rather than preserved.

## Problem

The current repository mixes two competing ownership models:

1. host-owned `/etc/nixos` as the steady-state rebuild target
2. repo-owned host profiles such as `#ovh-vps` as effective machine definitions

That conflict appears in several places:

- OVH install currently lands directly on the final NixPI host configuration
- day-2 docs say `/etc/nixos#nixos` is authoritative
- operator workflows still include repo-driven update/rebuild behavior

This makes the product boundary unclear:

- is NixPI a reusable layer applied to an existing NixOS host?
- or is NixPI a whole-machine appliance profile?

For supporting already-installed NixOS systems safely, the second model is the wrong default.

## Goals

- Make `/etc/nixos` the only steady-state system root.
- Make NixPI a reusable module layer that integrates into host-owned NixOS systems.
- Add one shared bootstrap path for any existing NixOS machine.
- Change OVH to install a plain base NixOS first, then run the shared bootstrap flow.
- Remove repo-profile steady-state rebuild semantics.
- Keep the bootstrap tool conservative around existing custom host flakes.

## Non-Goals

- Backward compatibility with the direct-final-install OVH model.
- Automatic invasive rewriting of existing custom `/etc/nixos/flake.nix` files.
- A generic multi-provider deployment abstraction.
- Full hermetic purity. The host-owned `/etc/nixos` model remains intentionally operational rather than fully pure.

## Constraints

- Existing host configuration files must not be overwritten casually.
- The bootstrap flow must preserve machine-specific host ownership.
- Existing flake hosts must be handled conservatively.
- The install story must remain understandable to operators:
  1. install plain NixOS
  2. bootstrap NixPI
  3. rebuild through `/etc/nixos`

## Architecture Decision

Adopt the host-owned model everywhere.

### Ownership Model

#### Host-owned layer: `/etc/nixos`

This remains the source of truth for:

- hardware configuration
- filesystems
- bootloader and initrd
- firmware and microcode
- virtualization/provider quirks
- desktop or display stack if present
- machine-specific networking and local policy

#### NixPI-owned layer: imported module

NixPI provides:

- `nixpi.nixosModules.nixpi`
- reusable services and defaults
- operator tooling
- generated helper files for host integration

NixPI does not own the whole machine definition.

## Install and Bootstrap Flows

### Flow A: Existing NixOS machine

1. ensure a local NixPI source checkout or flake input is available
2. inspect `/etc/nixos`
3. create narrowly-scoped helper files for NixPI integration
4. rebuild via `/etc/nixos#nixos`

### Flow B: OVH VPS

1. boot into rescue mode
2. run `nixos-anywhere` against a plain OVH base profile
3. boot the installed base NixOS system
4. run the same shared bootstrap flow as any other NixOS machine
5. rebuild and operate through `/etc/nixos#nixos`

This makes OVH only a day-0 base-install concern, not a special NixPI architecture.

## Repo Shape

### New or renamed artifacts

- `core/os/hosts/ovh-base.nix`
  - plain OVH-compatible base NixOS profile for install-time use
- `core/scripts/nixpi-bootstrap-host.sh`
  - shared host integration/bootstrap entrypoint

### Existing artifacts to change

- `core/scripts/nixpi-deploy-ovh.sh`
  - installs `ovh-base`, not final NixPI
- `core/scripts/nixpi-rebuild.sh`
  - remains the canonical rebuild wrapper targeting `/etc/nixos#nixos --impure`
- docs
  - rewritten to describe base-install then bootstrap

### Existing artifacts to remove or redesign

- `core/os/hosts/ovh-vps.nix`
  - remove as a steady-state product profile
- `core/scripts/nixpi-rebuild-pull.sh`
  - remove if it remains a repo-profile rebuild path

## Bootstrap Contract

### Case 1: Classic non-flake `/etc/nixos`

Bootstrap may:

- preserve `configuration.nix`
- preserve `hardware-configuration.nix`
- generate a minimal `flake.nix`
- generate `nixpi-integration.nix`
- generate `nixpi-host.nix`
- rebuild through `/etc/nixos#nixos`

Bootstrap must not:

- overwrite preserved host files
- replace host logic wholesale

### Case 2: Existing flake host

Bootstrap may:

- generate `nixpi-integration.nix`
- generate `nixpi-host.nix`
- print exact manual integration instructions

Bootstrap must not:

- auto-rewrite or auto-patch the existing host flake
- guess how to merge into custom flake structure

This keeps the tool conservative and avoids brittle rewriting logic.

## Composition Contract

The intended host flake composition order is:

1. existing host modules
2. `nixpi.nixosModules.nixpi`
3. host-local NixPI override module such as `nixpi-host.nix`

This preserves host ownership while still allowing local NixPI-specific overrides.

## Determinism Model

This design is not fully pure in the strict flake sense.

The deliberate impurity boundary is the host-owned `/etc/nixos` tree and local integration files. That tradeoff is accepted because the product goal is safe host layering, not machine-appliance purity.

What must still remain deterministic:

- flake inputs for the NixPI source itself
- declarative machine rebuilds from `/etc/nixos`
- no steady-state rebuilds from mutable repo profiles or moving branch heads

## Removed Product Assumptions

The following assumptions are intentionally removed:

- `nixos-anywhere` installs the final NixPI system directly
- OVH is a special steady-state NixPI host profile
- repo profile rebuilds are valid day-2 operations
- NixPI owns the machine root on installed systems

## Migration Plan

### Phase 1: Introduce the shared host bootstrap path

- add `nixpi-bootstrap-host`
- make `/etc/nixos#nixos` the only steady-state rebuild target
- stop relying on repo host profiles for day-2 semantics

### Phase 2: Split OVH into base install plus shared bootstrap

- add `ovh-base`
- change `nixpi-deploy-ovh` to install the base profile
- rewrite OVH docs to describe bootstrap after first boot

### Phase 3: Remove contradictory workflows

- remove repo-profile rebuild paths
- remove direct-final-install docs and tests
- remove product messaging that treats NixPI as the whole installed machine

## Verification Criteria

1. `/etc/nixos#nixos` is the only steady-state rebuild target.
2. No supported workflow rebuilds from repo host profiles.
3. OVH install documentation describes plain base install followed by bootstrap.
4. Bootstrap never overwrites existing host-owned config files.
5. Existing flake hosts are handled by helper-file generation plus manual integration instructions only.
6. NixPI remains an imported layer, not the system root.

## Risks

- Users accustomed to direct repo-driven rebuild workflows will need to adapt.
- Removing compatibility means the diff must update code, docs, and tests consistently in one pass.
- Existing custom flake hosts will require explicit human integration work rather than automation.

## Recommendation

Proceed with the clean-break host-owned model.

It is the clearest architecture for supporting both:

- existing NixOS systems
- provider-installed fresh systems such as OVH

The important product decision is to treat NixPI as a reusable NixOS layer rather than a whole-machine profile.
