# Stable Bootstrap CI and Manual QEMU Lab Design

## Summary

Add a first-class stable bootstrap validation lane plus a Nix-first manual QEMU lab
for scratch installs and repeatable post-install bootstrap testing.

This closes the gap between:

- the repo's current unstable-oriented default flake checks
- the public bootstrap contract, which writes `/etc/nixos/flake.nix` against
  `nixos-25.11` by default

It also gives operators two manual validation paths:

- an interactive installer ISO VM for end-to-end scratch installs
- a reusable fresh stable NixOS VM disk for faster bootstrap and reboot checks

## Problem

The current repo validation surface does not make the stable bootstrap path a
first-class check.

Today:

- `flake.nix` defaults to `nixos-unstable`
- bootstrap-generated `/etc/nixos/flake.nix` defaults to stable `nixos-25.11`
- the existing VM checks mostly validate repo-native test nodes or fresh-install
  flows that override the nixpkgs input to the local `pkgs.path`

This means:

- a dependency pin or `buildNpmPackage` fetcher-mode drift can pass normal repo
  checks
- the same repo can still fail during `nixos-rebuild switch --flake /etc/nixos#nixos`
  on a real stable bootstrap install

There is also no repo-native manual environment for scratch ISO testing. Manual
validation currently requires ad hoc host setup and repeated QEMU argument
rediscovery.

## Goals

- Make the documented stable bootstrap path fail in CI before users hit it.
- Preserve the current unstable-oriented repo validation lanes.
- Provide a manual installer ISO VM flow that remains intentionally interactive.
- Provide a faster preinstalled stable NixOS VM flow for repeated bootstrap and
  reboot testing.
- Keep the host-side tooling Nix-first and reproducible.

## Non-Goals

- Full installer UI automation.
- Replacing the current NixOS test driver lanes with QEMU shell scripts.
- Supporting arbitrary host hypervisor stacks outside QEMU.
- Inventing a new deployment contract different from the current bootstrap flow.

## Constraints

- The public bootstrap contract is stable-first by default.
- The NixOS VM tests must continue to work with the existing flake structure.
- The manual lab should minimize host assumptions beyond a Nix-capable Linux
  environment.
- The installer path must remain manually controlled inside the guest.
- No new third-party dependencies should be introduced if existing Nix/QEMU
  tooling is sufficient.

## Approach Options

### Option 1: Add only a stable build check and two minimal helper scripts

Pros:

- smallest diff
- fastest to land

Cons:

- weak manual ergonomics
- no clear reusable lab structure

### Option 2: Add a stable CI lane plus a small reusable QEMU lab

Pros:

- closes the automated coverage gap
- gives operators a durable manual workflow
- keeps manual install steps explicit and low-fragility

Cons:

- more moving parts than a single check
- requires some host-side documentation and wrapper polish

### Option 3: Build a fully scripted installer automation harness

Pros:

- strongest theoretical end-to-end coverage

Cons:

- high complexity
- fragile against installer UX/environment shifts
- unnecessary before the stable build path is explicitly covered

## Recommended Approach

Implement Option 2.

This keeps the fix aligned with the actual shipped contract:

- CI gets a stable-target proof
- operators get a repeatable manual lab
- the install and bootstrap steps themselves remain human-controlled where UI and
  operator judgment matter

## Design

### 1. Stable Bootstrap Validation Lane

Add one new first-class stable-oriented validation surface in the flake.

The new check should prove that the installed system target builds when the
`nixpkgs` input matches the bootstrap default release line instead of the repo
default unstable channel.

Expected shape:

- keep the existing `checks.config`, `checks.boot`, and VM lanes unchanged
- add a stable install-target check named
  `checks.x86_64-linux.config-stable-bootstrap`
- define that check against a stable nixpkgs input instead of requiring
  ad hoc `--override-input` usage

This check should validate the exact contract used by bootstrap-generated
`/etc/nixos/flake.nix`:

- host-owned `/etc/nixos/configuration.nix`
- host-owned `/etc/nixos/hardware-configuration.nix`
- layered `nixpi.nixosModules.nixpi`
- stable release line by default

### 2. Stable Fresh-Install VM Coverage

Add a stable variant of the current fresh-install bootstrap VM test.

The current fresh-install harness in
`tests/nixos/nixpi-bootstrap-fresh-install.nix` intentionally points
`NIXPI_NIXPKGS_FLAKE_URL` at `path:${pkgs.path}`. That is useful for one class of
repo-local testing, but it is not the shipped bootstrap default.

Add a second test:

- `tests/nixos/nixpi-bootstrap-fresh-install-stable.nix`

This test should:

- start from a pristine NixOS VM
- run `nixpi-bootstrap-vps`
- allow bootstrap to use the stable default release line
- verify that `/etc/nixos/flake.nix` resolves and that the rebuild contract is
  invoked successfully

This gives the repo an automated proof for the real documented install path,
instead of only the repo-local overridden path.

### 3. Stable Alignment Guard

Add a small guard that makes drift between bootstrap defaults and stable checks
visible.

The guard should assert that:

- the bootstrap helper still defaults to stable
- the stable CI/check lane is targeting the same release family

This can be implemented as a lightweight flake/runCommand check or a small
integration test that greps the bootstrap script and flake wiring.

The purpose is not to encode every detail, only to ensure that future edits do
not silently desynchronize:

- `core/scripts/nixpi-init-system-flake.sh`
- the stable check definition
- the operator-facing docs

### 4. Manual QEMU Lab

Add a small repo-local manual lab under a path such as:

- `tools/qemu/`

The lab should expose two entrypoints:

- `installer`
- `preinstalled-stable`

The host-side workflow should be Nix-first:

- use repo-defined Nix tooling or flake apps for QEMU/OVMF and related runtime
  requirements
- avoid assuming a host-installed `qemu-system-x86_64` outside the repo contract

#### 4.1 Installer ISO Path

Purpose:

- boot the official stable NixOS installer ISO
- let the operator perform the install manually inside the VM
- then run NixPI bootstrap manually in the guest

Host-side conveniences:

- fresh qcow2 disk creation/reset
- OVMF firmware wiring
- host port forwards for SSH and web checks
- optional serial console logging
- optional shared folder or bind mount access to the repo checkout

Guest-side actions remain manual:

- partitioning and install
- first boot login
- running `nix run .#nixpi-bootstrap-vps` or repo-equivalent path

#### 4.2 Preinstalled Stable Disk Path

Purpose:

- boot an already-installed fresh stable NixOS disk image
- skip repeated installer work when testing bootstrap/reboot regressions

Host-side conveniences:

- command to create or refresh the base stable qcow2 image
- command to launch it with the same networking and logging profile as the
  installer path
- optional snapshot/overlay support so repeated runs can reset cheaply

Guest-side actions remain manual:

- login
- run bootstrap
- reboot
- verify services and public surface

### 5. Shared Runtime Defaults

Both QEMU entrypoints should share a common runtime wrapper that standardizes:

- VM directory layout
- disk/image naming
- forwarded ports
- firmware and machine defaults
- logging locations
- reset semantics

Suggested runtime defaults:

- qcow2 images stored in a repo-local cache directory or `/tmp/nixpi-qemu/`
- SSH forwarded to a predictable high port
- HTTP/HTTPS optionally forwarded for surface checks
- serial output captured to a file for debugging

The wrapper should prioritize transparency over magic:

- print the exact QEMU command it is using
- print the guest access details after launch
- avoid hidden guest mutations

## Documentation Changes

Update:

- `docs/operations/live-testing.md`
- `tests/nixos/README.md`

Document:

- new stable CI/check lane
- how to launch the installer ISO lab
- how to launch the preinstalled stable lab
- where disks/logs live
- how to reset the environment
- which steps remain manual inside the guest

## Verification Plan

Implementation is complete only when all of the following are true:

- the stable install-target check builds successfully
- the new stable fresh-install VM test passes
- at least one existing VM lane still passes unchanged
- the installer QEMU entrypoint boots to the NixOS installer environment
- the preinstalled-stable entrypoint boots to a loginable stable NixOS guest
- the docs describe both manual flows accurately

Minimum proving commands should include:

- a stable install-target flake build
- the stable fresh-install VM test
- an existing firstboot VM test
- the manual lab launch commands

## Risks

### QEMU runtime mismatch

Mitigation:

- keep the runtime Nix-first
- print resolved tool paths and launch args

### Stable/unstable drift returns later

Mitigation:

- add the stable lane as a first-class CI check
- add an alignment guard between bootstrap defaults and stable check wiring

### Manual lab becomes opaque

Mitigation:

- keep guest actions manual
- keep host scripts thin and inspectable

### Installer path remains slower than desired

Mitigation:

- provide the preinstalled stable disk path for daily iteration
- reserve the installer ISO path for periodic full scratch validation

## Acceptance Criteria

- A PR that breaks the stable bootstrap path fails before merge.
- An operator can launch a scratch installer ISO VM from one repo command.
- An operator can launch a preinstalled fresh stable VM from one repo command.
- Both manual flows keep install/bootstrap actions under operator control.
- The repo docs describe the manual and automated validation story without
  ambiguity.
