# Repo-Root QEMU Lab Design

## Summary

Move the manual QEMU lab out of `.omx/qemu-lab` and make `qemu-lab/` at the
repo root the single canonical runtime location.

The new layout keeps operator-visible VM state separate from implementation
scripts:

- code stays under `tools/qemu/`
- local runtime data lives under `qemu-lab/`

The repo should commit only a small `qemu-lab/README.md` and ignore the rest of
the lab contents.

## Problem

The current manual QEMU lab defaults to `.omx/qemu-lab`, which makes the lab
look like OMX-internal state instead of part of the operator-facing validation
workflow.

That causes two problems:

- the expected installer ISO location looks like hidden tool state instead of a
  first-class local asset
- the repo mixes a user-facing manual validation flow with a path that feels
  implementation-specific

The desired contract is simpler: `qemu-lab/` should be an explicit local runtime
area at the repo root.

## Goals

- Make `qemu-lab/` at repo root the only default lab location.
- Keep `tools/qemu/` as code-only script location.
- Commit an empty `qemu-lab/` directory with a README.
- Ignore all generated lab runtime artifacts except the README.
- Update helper output and docs to point only at `qemu-lab/`.
- Preserve `NIXPI_QEMU_DIR` as an explicit override for advanced use.

## Non-Goals

- Supporting both `.omx/qemu-lab` and `qemu-lab/` as equal defaults.
- Moving the helper scripts out of `tools/qemu/`.
- Automating the install flow inside the guest.
- Changing the stable bootstrap validation semantics beyond the lab path move.

## Constraints

- The result should have one canonical default path, not two.
- Generated disks, logs, firmware vars, and local ISO files should not be
  committed.
- The committed footprint should stay minimal and reviewable.
- Existing environment-variable overrides should remain available.

## Approach Options

### Option 1: Move only the installer ISO path

Pros:

- smallest code change
- fixes the immediate missing-ISO complaint

Cons:

- leaves disks/logs under `.omx`
- preserves a split mental model
- does not fully remove `.omx` from the manual lab contract

### Option 2: Move the full lab to `qemu-lab/` at repo root

Pros:

- one clear runtime location
- clean separation between scripts and generated state
- matches operator expectations for a repo-local manual lab

Cons:

- requires doc and ignore-rule updates
- intentionally breaks the old default path

### Option 3: Nest the lab under `tools/qemu/`

Pros:

- keeps runtime state physically near the scripts

Cons:

- mixes generated operator state with implementation files
- makes `tools/` less clearly code-only
- creates uglier ignore rules and a less clean repository shape

## Recommended Approach

Implement Option 2.

This keeps the repository boundaries clean:

- `tools/qemu/` contains helper logic
- `qemu-lab/` contains local runtime state

It also aligns the manual lab with the user-facing workflow instead of making it
look like OMX-internal scratch data.

## Design

### 1. Canonical Lab Root

Change the default lab root from:

- `.omx/qemu-lab`

to:

- `qemu-lab`

The canonical repo-root layout becomes:

- `qemu-lab/README.md` — committed
- `qemu-lab/nixos-stable-installer.iso` — local operator-provided ISO
- `qemu-lab/disks/` — generated disks
- `qemu-lab/logs/` — serial logs and related outputs
- `qemu-lab/OVMF_VARS-*.fd` — generated local firmware variable files

### 2. Script Behavior

Update the QEMU helper layer so every default path resolves from the new repo
root lab:

- `tools/qemu/common.sh`
- `tools/qemu/run-installer.sh`
- `tools/qemu/run-preinstalled-stable.sh`
- `tools/qemu/prepare-preinstalled-stable.sh`

The environment override remains:

- `NIXPI_QEMU_DIR`

If it is set, the scripts should use that explicit directory. Otherwise, they
should default to `${REPO_DIR}/qemu-lab`.

This is a migration, not a dual-path compatibility layer. The old `.omx/qemu-lab`
location should not remain as a fallback default.

### 3. Git Tracking Rules

Commit the directory placeholder and documentation:

- `qemu-lab/README.md`

Ignore all other lab contents with a narrow rule set so runtime artifacts remain
local and the directory still exists in the repo.

The ignore behavior should ensure:

- the README is tracked
- generated ISO, qcow2, logs, and OVMF vars are ignored
- future runtime files default to ignored unless intentionally unignored

### 4. Documentation Updates

Update operator-facing docs and helper output so they point only at `qemu-lab/`,
including:

- `tools/qemu/README.md`
- `docs/operations/live-testing.md`
- any launcher or preparation output that currently mentions `.omx/qemu-lab`

The docs should describe `qemu-lab/` as the canonical repo-local runtime area,
not as an optional alternative.

### 5. Verification

The migration is complete when all of the following are true:

1. A direct launcher invocation fails early with:
   `missing installer ISO: .../qemu-lab/nixos-stable-installer.iso`
2. The QEMU helper scripts pass shell syntax checks.
3. A repo-wide path sweep shows no remaining operator-facing references to
   `.omx/qemu-lab`.
4. `qemu-lab/README.md` is tracked while the rest of `qemu-lab/` is ignored.

## Risks and Mitigations

### Risk: stale local state remains under `.omx/qemu-lab`

Mitigation:

- do not automatically migrate or delete old local state
- document only the new canonical path

### Risk: ignore rules accidentally hide the README

Mitigation:

- verify tracked/untracked behavior explicitly with `git status --ignored`

### Risk: partial path migration leaves mixed operator messages

Mitigation:

- run a repo-wide search for both `.omx/qemu-lab` and `nixos-stable-installer.iso`
  before completion

## Testing Strategy

- Write or update a regression check for the missing-ISO message path first.
- Run targeted shell syntax checks for the QEMU helper scripts.
- Run the missing-ISO launcher path directly after the change.
- Sweep docs and helper output for stale references.
