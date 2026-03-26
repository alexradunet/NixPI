# Core Library

> Shared TypeScript helpers used across the local runtime and Pi extensions

## What lives here

Keep additions here narrow and shared. If logic is only used by one feature, prefer keeping it inside that feature module instead of growing `core/lib/`.

- `filesystem.ts` owns path resolution and NixPI directory conventions.
- `exec.ts` owns guarded subprocess execution.
- `frontmatter.ts` owns markdown frontmatter parsing and serialization.
- `interactions.ts` owns pending user-input requests and reply resolution.
- `logging.ts` owns logger construction.
- `repo-metadata.ts` owns canonical repo metadata read/write helpers.
- `retry.ts`, `utils.ts`, and `validation.ts` own small reusable primitives.

## Cleanup rule

Before adding a new lib file or export, check:

1. Is it used by more than one subsystem?
2. Does it reduce duplication rather than move it?
3. Is it smaller than the coupling cost it introduces?

If the answer is no, keep it local to the caller.

---

### `core/lib/filesystem.ts`

**Responsibility**: Canonical path resolution and filesystem safety checks.

**Key Exports**:
- `safePathWithin()` / `safePath()` - traversal-safe path resolution
- `getNixPiDir()` / `getNixPiStateDir()` / `getPiDir()` - runtime directory conventions
- `getSystemReadyPath()` / `getPersonaDonePath()` - wizard marker paths
- `getCanonicalRepoDir()` / `assertCanonicalRepo()` - canonical repo policy helpers
- `resolvePackageDir()` / `readPackageVersion()` - package metadata helpers

---

### `core/lib/frontmatter.ts`

**Responsibility**: Parse and generate YAML frontmatter.

**Key Exports**:
- `parseFrontmatter(content)` - extract frontmatter from markdown
- `stringifyFrontmatter(data, content)` - serialize metadata back into markdown
- `FrontmatterData` - type used by markdown-backed objects

**Used By**:
- Episode extension for episode files
- Object extension for durable objects
- `AGENTS.md` parsing for local agent configuration

**Outbound Dependencies**:
- `js-yaml` for YAML parsing

---

### `core/lib/interactions.ts`

**Responsibility**: Tracks prompts that require explicit user interaction.

**Key Exports**:
- `requestInteraction()` / `resolveInteractionReply()` - create and complete pending prompts
- `requestTextInput()` / `requestSelection()` / `requireConfirmation()` - higher-level helpers
- `getPendingInteractions()` - inspect unresolved prompts

---

### `core/lib/repo-metadata.ts`

**Responsibility**: Reads and validates canonical repo metadata for supported rebuild flows.

**Key Exports**:
- `getCanonicalRepoMetadataPath()` - resolve the metadata file location
- `readCanonicalRepoMetadata()` - load repo metadata from disk
- `writeCanonicalRepoMetadata()` - persist canonical repo metadata

This file works with `filesystem.ts` to keep rebuild and update flows pinned to the supported checkout.

---

## Related Tests

| Test File | Coverage |
|-----------|----------|
| `tests/lib/filesystem.test.ts` | Filesystem operations and path safety |
| `tests/lib/exec.test.ts` | Command execution with guardrails |
| `tests/lib/retry.test.ts` | Retry helpers |
| `tests/lib/shared.test.ts` | Frontmatter, interactions, logging, utils, and validation helpers |

---

## Related

- [Pi Extensions](./pi-extensions) - Primary consumers of lib utilities
- [Daemon](./daemon) - Uses filesystem and runtime helpers
- [Tests](./tests) - Test coverage details
