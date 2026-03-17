# Prefill Dev UX Design

**Date:** 2026-03-17
**Status:** Approved

## Problem

`just vm` always boots from a fresh qcow2, so any `prefill.env` placed inside the VM is wiped on every run. The existing fallback reads from `~/.bloom/prefill.env` on the host (shared via 9p virtfs), but developers without Bloom installed locally have no reason for `~/.bloom/` to exist.

## Goal

Let developers place `prefill.env` in the repo (gitignored, co-located with the example) and have `just vm` automatically use it — no manual host setup required.

## Design

### Approach

Option A — justfile pre-stage. Before launching QEMU, the VM targets copy `core/scripts/prefill.env` to `~/.bloom/prefill.env` if the project file exists. The existing virtfs already shares `~/.bloom/` into the VM, so the wizard picks it up through the current fallback path. No changes to the wizard or NixOS config.

### Files Changed

**`.gitignore`**
Add `core/scripts/prefill.env` so the file with real credentials is never committed.

**`justfile`**
In `vm`, `vm-gui`, and `vm-daemon` targets (not `vm-run`, which reuses an existing disk), insert a staging block immediately before the `qemu-system-x86_64` call:

```bash
# Stage project prefill into host-bloom share if present
if [[ -f "core/scripts/prefill.env" ]]; then
  mkdir -p "$HOME/.bloom"
  cp "core/scripts/prefill.env" "$HOME/.bloom/prefill.env"
  echo "Staged core/scripts/prefill.env → ~/.bloom/prefill.env"
fi
```

The project file always wins (overwrite) when present — it is the dev source of truth.

**`core/scripts/prefill.env.example`**
Update the header comment to describe the new workflow instead of the old "copy to VM" instruction.

### Developer Workflow

```
cp core/scripts/prefill.env.example core/scripts/prefill.env
# fill in values
just vm
```

### What Is Not Changed

- `bloom-wizard.sh` — no changes; it already has the `/mnt/host-bloom/prefill.env` fallback
- `core/os/hosts/x86_64.nix` — no new virtfs mounts needed
- `vm-run` — not modified; it reuses an existing disk where the wizard may have already run

## Trade-offs Considered

| Option | Pros | Cons |
|--------|------|------|
| A (chosen) | Minimal diff, no NixOS rebuild | Writes one file outside the repo (`~/.bloom/prefill.env`) |
| Second virtfs mount | No host mutation | Requires NixOS rebuild + wizard + 4 justfile targets |
| Symlink instead of copy | Edits reflected immediately | Slightly surprising across virtfs boundary |
