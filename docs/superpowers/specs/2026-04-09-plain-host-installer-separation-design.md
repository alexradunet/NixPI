# Plain Host Installer Separation Design

## Summary

Separate plain remote NixOS installation from NixPI within the same repo by creating a distinct generic product surface for minimal host provisioning.

End state:

- the repo exposes a neutral plain-host installer surface that installs standard NixOS through `nixos-anywhere`
- OVH is treated as the first provider-specific runbook and preset, not as a NixPI-owned install path
- NixPI becomes an explicit second-stage bootstrap layered onto an already installed NixOS host
- shared internals remain shared, but public entrypoints, docs, and tests reflect the separation clearly

This is a product-surface separation, not a repo split.

## Problem

The repo has already moved toward a two-stage model:

1. install a plain base NixOS system
2. bootstrap NixPI on top of that host

But the public surface still leaks NixPI ownership into plain provisioning:

- the OVH installer wrapper is still named `nixpi-deploy-ovh`
- OVH base provisioning is still described mostly through NixPI operator language
- users who only want a standard NixOS host on OVH still encounter NixPI-branded entrypoints

That makes the architecture direction better than the product story.

The desired mental model is simpler:

1. install plain NixOS
2. optionally layer NixPI later

If a user never wants NixPI, the repo should still provide a clean path for a standard OVH NixOS installation.

## Goals

- Create a generic plain-host installer product surface inside this repo.
- Keep the installed host intentionally minimal and standard.
- Keep OVH as the first supported provider runbook without baking OVH assumptions into the generic contract.
- Preserve shared implementation internals between the generic installer and NixPI workflows.
- Make NixPI an explicit second-stage consumer of the plain-host install surface.
- Keep the install workflow compatible with current `nixos-anywhere` best practices and recent OVH operational guidance.

## Non-Goals

- Splitting the code into a separate repository.
- Turning the base installer into a full fleet-management framework.
- Making secrets management, app bootstrap, or NixPI setup part of the default plain-host install story.
- Designing every future provider abstraction now.
- Preserving NixPI branding in the generic installer surface for compatibility.

## External Inputs and Constraints

### `nixos-anywhere` product constraints

The official `nixos-anywhere` docs still center the install flow on:

- a flake-defined `nixosConfigurations` target
- disko-backed partitioning
- phase control through `--phases`
- optional hardware generation
- optional custom `--kexec`
- optional `--extra-files`

This strongly supports a generic installer surface that is declarative, boring, and close to upstream expectations rather than a custom imperative installer.

### OVH-specific operational constraints

The 2024 to 2026 OVH/Kimsufi material consistently shows:

- rescue-mode netboot can make the default reboot phase undesirable
- disk identities can change after kexec, so persistent disk identifiers matter
- provider recovery often depends on OVH KVM and rescue mode
- monitoring or intervention systems may react badly to kexec on OVH dedicated offerings
- software RAID requires explicit boot-time assembly configuration such as `boot.swraid.enable = true;`

Therefore OVH behavior must live in provider-specific presets and docs, not in the generic installer contract.

### Source-environment instability

The OCI deployment writeup shows that kexec success can vary by source environment. The same `nixos-anywhere` flow failed from Ubuntu and worked from Oracle Linux on the same provider class.

The installer surface must therefore support staged execution and troubleshooting. It must not pretend that a single one-shot command is universally reliable.

### `--extra-files` is an escape hatch, not the mainline contract

The OCI/secrets article shows `--extra-files` can be useful, but it also produced root-owned files that needed cleanup through `systemd.tmpfiles`.

That makes `--extra-files` valuable for advanced users, but a poor default design center for the plain-host installer. The generic product should allow pass-through use of advanced `nixos-anywhere` features without owning secrets workflows itself.

## Product Decision

Adopt a same-repo, separate-product-surface model with shared internals.

There will be two explicit operator stories:

### Story A: Plain host install

For users who want a minimal standard NixOS host:

1. choose a provider runbook or preset
2. run the generic installer surface
3. land on a standard reachable NixOS system

No NixPI knowledge is required.

### Story B: NixPI bootstrap

For users who want NixPI:

1. install the plain host first
2. reconnect to the installed system
3. run `nixpi-bootstrap-host`
4. operate the system through the installed host-owned `/etc/nixos`

This makes NixPI clearly downstream of the base install.

## Architecture

### Layer 1: Generic plain-host product surface

This layer owns the neutral public contract:

- install minimal NixOS remotely via `nixos-anywhere`
- accept explicit target host and target disk
- expose staged execution when needed
- support pass-through advanced `nixos-anywhere` arguments
- install only what is required for a bootable reachable base system

This surface must be named and documented without `nixpi-*` branding.

### Layer 2: Provider-specific overlays and runbooks

This layer owns provider quirks and operational guidance:

- OVH rescue mode steps
- recommended phase selection for OVH
- disk-ID guidance for providers where names change across kexec
- firmware and bootloader caveats
- monitoring and recovery warnings

OVH is the first provider implementation of this layer.

### Layer 3: NixPI bootstrap and steady-state integration

This layer owns:

- `nixpi-bootstrap-host`
- NixPI-specific host integration
- post-install user-facing docs for layering NixPI onto an existing host

It must not own base provisioning anymore.

## Minimal Installed-System Contract

The plain-host installer should install a deliberately boring host:

- standard NixOS base
- reachable SSH configuration
- provider-safe bootloader and disk layout defaults
- no NixPI services or options
- no secrets management workflow
- no opinionated higher-level app bootstrap

The installed machine should look like a normal NixOS system that happens to have been provisioned from this repo.

This is important both for user trust and for architectural alignment with the desired NixPI second-stage model.

## Public Surface Recommendation

The generic installer surface should provide:

- a neutral command/package name for remote plain-host deployment
- a neutral minimal host profile or profiles
- provider-specific docs/presets for OVH
- clear pass-through support for `nixos-anywhere` flags such as `--phases`

The existing `nixpi-bootstrap-host` command should remain, but its docs must start after the base host already exists.

## Naming and Ownership Rules

To make the separation real rather than cosmetic:

- the generic installer must not use `nixpi-*` names in its public entrypoints
- plain OVH provisioning must not be described as a NixPI install
- NixPI docs must not present themselves as owners of day-0 base provisioning
- shared implementation modules may remain in the same repo, but ownership in names and docs must follow the product split

## Behavior Contract for the Generic Installer

The generic installer should:

- install only a minimal plain host
- require explicit destructive targeting inputs
- expose or forward `nixos-anywhere` staged execution controls
- allow troubleshooting flows such as `--phases kexec` followed by resumed phases
- allow advanced callers to pass through upstream features like `--extra-files`, `--generate-hardware-config`, and `--kexec`

The generic installer should not:

- accept NixPI bootstrap parameters
- generate or manage age keys by default
- mutate external secrets repositories
- perform second-stage user or application setup beyond minimal host reachability
- claim a provider-agnostic abstraction that exceeds what the repo actually supports

## OVH-Specific Guidance Model

OVH should be represented as the first provider runbook/preset, not as the definition of the whole installer product.

The OVH layer should document and validate:

- rescue-mode boot flow
- persistent disk-ID selection
- disk remapping after kexec
- when to omit the default reboot phase
- recovery through OVH console or rescue mode
- bootloader and firmware assumptions for the supported OVH host shape

OVH-specific recommendations are allowed to be strong, but they remain recommendations within the OVH provider surface rather than rules of the generic installer everywhere.

## Testing and Verification Shape

Tests should mirror the product split:

### Generic installer tests

- package and script interface tests for the neutral deploy entrypoint
- generated flake/profile tests for minimal plain-host output
- argument-forwarding tests for `nixos-anywhere` pass-through behavior
- checks that generic output contains no NixPI bootstrap configuration

### Provider-specific tests

- OVH base profile evaluation
- OVH disk layout and boot assumptions
- OVH-specific troubleshooting or staged-execution expectations where practical

### NixPI integration tests

- bootstrap-host integration onto an already installed host tree
- verification that NixPI stays second-stage and host-owned

This keeps the test suite aligned with the new boundary rather than only renaming commands.

## Migration Plan

### Phase 1: Establish the generic product language

- define the neutral product name and neutral entrypoints
- rewrite top-level install docs around plain-host first, NixPI second
- stop presenting plain OVH provisioning as a NixPI-branded operation

### Phase 2: Rename and reorganize public entrypoints

- rename the public OVH deploy wrapper to a neutral generic installer command
- move shared helper names away from `nixpi-ovh-*`
- keep the implementation shared where it makes sense

### Phase 3: Reorganize profiles and tests around the split

- keep or rename the minimal host profile under the generic installer surface
- keep OVH as a provider-specific profile/runbook
- update tests so they validate generic installer behavior independently of NixPI

### Phase 4: Tighten NixPI documentation and boundaries

- make NixPI install docs start from an already installed host
- keep `nixpi-bootstrap-host` as the only endorsed second-stage entrypoint
- remove any remaining public implication that NixPI owns day-0 provisioning

## Risks

- A superficial rename without test and doc restructuring would preserve the same conceptual coupling.
- Over-generalizing too early could create abstractions for providers that are not yet real.
- Exposing too many advanced upstream features directly in the friendly wrapper could weaken the minimal-product story.
- Some existing users may rely on NixPI-branded OVH commands and need an explicit migration note.

## Recommendation

Proceed with the same-repo, shared-internals, separate-product-surface design.

This gives the repo two clean stories:

- a generic minimal plain-host installer for users who just want standard NixOS on providers such as OVH
- an explicit NixPI second-stage bootstrap for users who want the higher-level NixPI layer

That is the smallest design that resolves the conceptual confusion without duplicating implementation.

## Sources

- Official `nixos-anywhere` reference: <https://nix-community.github.io/nixos-anywhere/reference.html>
- Official `nixos-anywhere` quickstart: <https://nix-community.github.io/nixos-anywhere/quickstart.html>
- Official `nixos-anywhere` custom kexec guide: <https://nix-community.github.io/nixos-anywhere/howtos/custom-kexec.html>
- Ian Johannesen, “Deploying NixOS on OVH Kimsufi with nixos-anywhere” (2026-03-14): <https://perlpimp.net/blog/nixos-anywhere-ovh-kimsufi/>
- Raghav Sood, “Installing NixOS on OVH” notes (2024-06-21): <https://raghavsood.com/blog/2024/06/21/ovh-nixos-install/>
- User-provided article: “Remote deployments with NixOS-Anywhere” by Anarion Dunedain (2026-03-07)
- User-provided article: “NixOS in 10 minutes” containerized `nixos-anywhere` walkthrough by Seán Murphy
- User-provided article: Bradford Toney, “Installing NixOS on OVH” (2023-09-23)
