# Codebase Minimization Design

**Date:** 2026-03-20
**Status:** Approved

## Overview

Two independent changes that reduce file count and simplify the install flow:

1. Consolidate small TypeScript lib files by merging single-consumer modules into their callers or natural parent modules.
2. Replace the tar-based repo download in install docs with a proper `git clone` using a temporary `nix run`-provided git binary.

---

## Part 1: TypeScript lib consolidation

### Goal

Reduce `core/lib/` from 12 files to 8 by eliminating files that are dead code, have a single consumer, or are naturally absorbed by a parent module.

No behavior changes. All live exported symbols remain identical — only file boundaries change.

### Changes

#### Delete `core/lib/room-alias.ts` (4 lines, 1 consumer)

Move `sanitizeRoomAlias` verbatim into `core/daemon/agent-supervisor.ts`. Remove the import.

#### Delete `core/lib/git.ts` (20 lines, 0 consumers — dead code)

`parseGithubSlugFromUrl` and `slugifyBranchPart` are defined but never imported anywhere in the codebase. Delete the file outright.

Also remove the `hosted-git-info` npm dependency from `package.json` — it is used only in `git.ts` and nowhere else.

#### Delete `core/lib/fs-utils.ts` → merge into `core/lib/filesystem.ts`

`filesystem.ts` already imports `safePathWithin` from `fs-utils.ts` internally. Move all three functions (`ensureDir`, `atomicWriteFile`, `safePathWithin`) into `filesystem.ts`, remove the `import { safePathWithin } from "./fs-utils.js"` line, and export `ensureDir` and `atomicWriteFile` from `filesystem.ts`.

`core/pi/extensions/setup/actions.ts` updates its import from `../../../lib/fs-utils.js` → `../../../lib/filesystem.js`.

#### Delete `core/lib/interactions.ts` → merge into `core/lib/shared.ts`

`interactions.ts` (299 lines) has exactly one importer: `shared.ts`. Append the entire module body of `interactions.ts` to `shared.ts`. Remove the `import { requestInteraction } from "./interactions.js"` line from `shared.ts`.

### Remaining lib files (8)

| File | Role |
|------|------|
| `exec.ts` | Shell command execution |
| `extension-tools.ts` | Tool registration helpers (5 consumers — kept) |
| `filesystem.ts` | Path helpers, env-based dirs, atomic write, safe path |
| `frontmatter.ts` | YAML frontmatter parse/serialize |
| `matrix-format.ts` | Matrix HTML rendering |
| `matrix.ts` | Matrix API operations |
| `setup.ts` | Setup wizard state helpers |
| `shared.ts` | Logger, truncate, confirmation, interaction helpers |

---

## Part 2: Install flow — git clone

### Goal

Replace the tar-based repo download with a proper `git clone` so the working directory retains an upstream remote reference, enabling `git pull` for later updates.

### Change

**File:** `docs/quick_deploy.md`, Step 2

**Before:**
```bash
curl -L https://github.com/alexradunet/nixpi/archive/refs/heads/main.tar.gz | tar xz -C ~
mv ~/nixpi-main ~/nixpi
cd ~/nixpi
```

**After:**
```bash
nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- clone https://github.com/alexradunet/nixpi.git ~/nixpi
cd ~/nixpi
```

`nix run nixpkgs#git` provides a temporary git binary from nixpkgs without permanent installation. The `--extra-experimental-features 'nix-command flakes'` flag is required on a stock NixOS install from the official ISO, which does not enable these features by default. The resulting `~/nixpi` clone has `origin` set to upstream, so `git pull` and `git log` work normally after the initial setup.

No changes to NixOS modules, services, or scripts.

---

## Testing

- All existing TypeScript unit and integration tests cover the same logic — no new tests required since no behavior changes.
- After Part 1: run `npx tsc --noEmit` to verify all import rewrites are correct, then `npm run build` and `npm test` must pass.
- Manually verify the `nix run` git clone command works on a stock NixOS ISO install before publishing the doc update.
