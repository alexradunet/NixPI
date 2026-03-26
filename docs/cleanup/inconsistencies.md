# Inconsistencies

Code patterns that are used differently across the codebase without clear reason.

---

## INC-1: `node:fs` import style — default vs named

**Files:** All files under `core/`

**Pattern split:**
| Style | Files |
|-------|-------|
| `import fs from "node:fs"` | `episodes/actions.ts`, `nixpi/actions.ts`, `nixpi/actions-blueprints.ts`, `objects/memory.ts`, `objects/actions.ts`, `objects/actions-query.ts`, `os/actions.ts`, `chat-server/index.ts` |
| `import { readFileSync, ... } from "node:fs"` | `persona/actions.ts`, `os/actions-proposal.ts`, `lib/filesystem.ts`, `lib/repo-metadata.ts` |

**Recommendation:** Pick one. The default import (`import fs from`) is more common in
the codebase (8 vs 4 files). Standardize on that unless tree-shaking matters (it
doesn't for Node server code).

---

## INC-2: Sync vs async fs operations mixed within same files

**Files:**
- `os/actions.ts` — uses `import fs from "node:fs"` (sync) **and**
  `import { readFile, writeFile } from "node:fs/promises"` (async). `handleNixosUpdate`
  uses sync `fs.existsSync`, while `handleUpdateStatus` uses async `readFile`.
- `objects/actions.ts` — all sync `fs.*` operations (readFileSync, writeFileSync,
  existsSync, mkdirSync) despite being importable from async callers.
- `episodes/actions.ts` — all sync `fs.*` operations.
- `chat-server/index.ts` — uses sync `fs.readFileSync` in an async HTTP handler.

**Recommendation:** For code running in the HTTP request path (`chat-server/index.ts`),
use async fs operations. For extension actions, the sync pattern is acceptable since
they run sequentially in the agent loop. Document this policy.

---

## INC-3: Duplicate import from same module

**File:** `core/pi/extensions/objects/actions.ts:7,10`

```ts
import { textToolResult } from "../../../lib/utils.js";           // line 7
import { errorResult, nowIso, truncate } from "../../../lib/utils.js";  // line 10
```

Two separate import statements from the same module. Should be merged into one.

---

## INC-4: `errorResult` vs `textToolResult` usage inconsistency

**Files:** All extension action files

| Extension | Success returns | Error returns |
|-----------|----------------|---------------|
| `objects/actions.ts` | `textToolResult(...)` | `errorResult(...)` |
| `objects/actions-query.ts` | `textToolResult(...)` | `errorResult(...)` |
| `nixpi/actions.ts` | `textToolResult(...)` | `errorResult(...)` |
| `episodes/actions.ts` | Inline `{ content: [...], details }` | `errorResult(...)` |
| `os/actions.ts` | Inline `{ content: [...], details, isError }` | `errorResult(...)` |
| `os/actions-health.ts` | `textToolResult(...)` | — |
| `os/actions-proposal.ts` | Inline `{ content: [...], details }` | `errorResult(...)` |

Three different patterns for success results:
1. `textToolResult(text)` — clean, consistent
2. `{ content: [{ type: "text" as const, text }], details: {...} }` — verbose inline
3. `{ content: [{ type: "text" as const, text }], details: {...}, isError: ... }` — inline with isError

**Recommendation:** Standardize on `textToolResult` for success. Extend it to accept
an optional `isError` parameter for the `os/actions.ts` pattern.

---

## INC-5: `biome.json` file exclusion syntax

**File:** `biome.json:43-53`

```json
"includes": [
  "**",
  "**/!node_modules/**",    // ← incorrect negation
  "**/!dist/**",            // ← incorrect negation
  "**/!services/**/*/node_modules/**",
  "**/!.worktrees",         // ← incorrect negation
  "**/!core/os/output/**",  // ← incorrect negation
  "**/!.pi",                // ← incorrect negation
  "!.claude",               // ← correct negation
  "**/!coverage/**"         // ← incorrect negation
]
```

Most negation patterns use `**/!pattern` form (non-standard for Biome). Biome
expects `!pattern` at the start. Only `"!.claude"` is correct. The VCS/gitignore
integration (`"useIgnoreFile": true`) may be covering for these broken patterns
silently.

**Fix:** Move exclusions to a `files.ignore` array or use `!**/pattern/**` syntax:
```json
"ignore": [
  "**/node_modules/**",
  "**/dist/**",
  "**/coverage/**",
  "**/.worktrees/**",
  "**/core/os/output/**",
  "**/.pi/**",
  "**/.claude/**"
]
```

---

## INC-6: `tsconfig.json` — dead and redundant includes

**File:** `tsconfig.json:15`

```json
"include": ["core/**/*.ts", "core/pi/extensions/**/*.ts", "cli/**/*.ts", "tests/**/*.ts"]
```

Issues:
1. `cli/**/*.ts` — no `cli/` directory exists in the project. Dead path.
2. `core/pi/extensions/**/*.ts` — already covered by `core/**/*.ts`. Redundant.

**Fix:**
```json
"include": ["core/**/*.ts", "tests/**/*.ts"]
```

---

## INC-7: Package version skew across `@mariozechner` packages

**File:** `package.json`

| Package | Version | Location |
|---------|---------|----------|
| `@mariozechner/pi-web-ui` | `0.62.0` | dependencies |
| `@mariozechner/pi-agent-core` | `0.60.0` | devDependencies |
| `@mariozechner/pi-ai` | `0.60.0` | devDependencies |
| `@mariozechner/pi-coding-agent` | `0.60.0` | devDependencies |

`pi-web-ui` is two minor versions ahead. If these packages share internal
interfaces, this can cause subtle type mismatches.

**Fix:** Verify compatibility or bump all to the same version.

---

## INC-8: Wildcard peer dependencies

**File:** `package.json:25-28`

```json
"peerDependencies": {
  "@mariozechner/pi-ai": "*",
  "@mariozechner/pi-coding-agent": "*"
}
```

`"*"` accepts any version. Since the code uses specific APIs (event types,
session interfaces, extension API), breaking changes in upstream packages would
pass silently.

**Fix:** Pin to compatible ranges, e.g., `"^0.60.0"`.

---

## INC-9: Three different "canonical repo path" values

**Files:**
- `AGENTS.md` — states `/home/alex/nixpi`
- `README.md:55-58` — states `/srv/nixpi` and `/etc/nixos`
- `justfile` `update` recipe — uses `~/nixpi`
- `core/lib/filesystem.ts:19` — defines `CANONICAL_REPO_DIR = "/srv/nixpi"`
- `core/pi/skills/recovery/SKILL.md:47` — states `~/.nixpi/pi-nixpi`
- `core/pi/skills/self-evolution/SKILL.md:54` — states `~/.nixpi/pi-nixpi`

Five different paths referenced for the "canonical" repo location.

**Fix:** The source of truth is `filesystem.ts:19` (`/srv/nixpi`). Update all docs
and scripts to reference this consistently.

---

## INC-10: Test assertion style for `isError` checks

**Files:** Multiple test files

Three different patterns for "no error":
```ts
expect(result.isError).toBe(false);      // os-proposal.test.ts, os-update.test.ts
expect(result.isError).toBeFalsy();      // objects.test.ts, episodes.test.ts
expect(result.isError).toBeUndefined();  // object-lifecycle.test.ts
```

These test different things:
- `toBe(false)` — property exists and is exactly `false`
- `toBeFalsy()` — property is `false`, `undefined`, `null`, `0`, or `""`
- `toBeUndefined()` — property does not exist

**Fix:** Determine which semantic is correct (does a successful result omit `isError`
or set it to `false`?) and standardize.

---

## INC-11: Test temp directory patterns mixed in same file

**File:** `tests/extensions/nixpi.test.ts`

The outer scope uses manual `fs.mkdtempSync()` without setting `NIXPI_DIR`:
```ts
nixPiDir = fs.mkdtempSync(path.join(os.tmpdir(), "nixpi-test-"));
```

Inner `describe` blocks use `createTempNixPi()` which does set `NIXPI_DIR`:
```ts
const tmp = createTempNixPi();
```

This means the outer `beforeEach` creates a temp dir that isn't wired to the
env var, potentially causing tests to read from the wrong directory.

**Fix:** Use `createTempNixPi()` consistently throughout the file.

---

## INC-12: `session.ts:85` — unsafe double type cast

**File:** `core/chat-server/session.ts:85`

```ts
piSession: session as unknown as PiSession,
```

Bypasses all TypeScript type checking. If `createAgentSession` returns a
different shape in a future version, the cast silently hides the mismatch.

**Fix:** Extract a minimal interface from the upstream package or use a runtime
type guard to validate the shape.

---

## INC-13: `check.yml` triggers on `master` branch

**File:** `.github/workflows/check.yml:8`

```yaml
branches:
  - main
  - master
```

The repo uses `main` exclusively. The `master` trigger is stale.

**Fix:** Remove `master` from the branches list.

---

## INC-14: `check.yml` doesn't run e2e tests

**File:** `.github/workflows/check.yml`

The `test:ci` npm script runs `test:unit + test:integration + test:e2e + test:coverage`.
But `check.yml` only runs `test:unit` and `test:integration`, skipping `test:e2e`.

**Fix:** Add `npm run test:e2e` to the workflow, or use `npm run test:ci` directly.

---

## INC-15: `test:ci` runs all tests twice

**File:** `package.json:54`

```json
"test:ci": "npm run test:unit && npm run test:integration && npm run test:e2e && npm run test:coverage && npm run test:system:smoke"
```

`test:coverage` runs `vitest run --coverage`, which executes ALL tests again.
Combined with the individual `test:unit`, `test:integration`, `test:e2e` runs,
every test runs twice.

**Fix:** Either run coverage only: `"test:ci": "npm run test:coverage && npm run test:system:smoke"`,
or split coverage into a separate step that doesn't re-run:
`"test:ci": "vitest run --coverage && npm run test:system:smoke"`.

---

## INC-16: `justfile build` vs `package.json build` — different operations

**Files:** `justfile`, `package.json`

- `justfile build` → `nix build .#app` (Nix derivation)
- `package.json build` → `rm -rf dist && tsc --build && vite build` (TS + frontend)

Same name, completely different operations.

**Fix:** Rename one. E.g., justfile could use `build-nix` or `build-derivation`.

---

## INC-17: `filesystem.ts` redundant alias

**File:** `core/lib/filesystem.ts:204-207`

```ts
export function validateCanonicalRepo(args: CanonicalRepoValidationArgs): void {
  assertCanonicalRepo(args);
}
```

Only called in `tests/lib/filesystem.test.ts`. Pure alias with no added logic.

**Fix:** Remove `validateCanonicalRepo`, update the one test to use `assertCanonicalRepo`.

---

## INC-18: `getNixPiRepoDir` is a redundant alias

**File:** `core/lib/filesystem.ts:150-152`

```ts
export function getNixPiRepoDir(): string {
  return getCanonicalRepoDir();
}
```

Pure delegation. Used in `os/actions.ts` and `os/actions-proposal.ts`.

**Fix:** Replace callers with `getCanonicalRepoDir()` directly and remove this export.

---

## INC-19: Guardrails have redundant patterns

**File:** `guardrails.yaml`

Three pipe-to-shell patterns:
1. `\|\s*(bash|sh|zsh|dash)\b` — "pipe to shell" (generic, catches everything)
2. `\bcurl\b.*\|\s*(bash|sh)` — "curl pipe to shell"
3. `\bwget\b.*\|\s*(bash|sh)` — "wget pipe to shell"

Pattern #1 already catches both #2 and #3. The more specific patterns have
different labels but will never be the first match.

**Fix:** Remove patterns #2 and #3, or reorder so specific patterns come first
if distinct labeling is desired.

---

## INC-20: `session.ts:179-188` — aggressive type casting in event translation

**File:** `core/chat-server/session.ts:179-188`

```ts
const msg = (event as { message?: { role?: string; content?: unknown[] } }).message;
// ...
for (const block of msg.content as { type: string; text?: string; ... }[]) {
```

The upstream `AgentSessionEvent` type is cast to an ad-hoc inline shape. Any
change in the upstream event structure will silently produce wrong results.

**Fix:** Import the proper types from `@mariozechner/pi-coding-agent` or define
an explicit interface that mirrors the expected shape with validation.

---

## INC-21: `getCanonicalRepoDir` ignores `primaryUser` parameter

**File:** `core/lib/filesystem.ts:119-122`

```ts
export function getCanonicalRepoDir(primaryUser = getPrimaryUser()): string {
  assertValidPrimaryUser(primaryUser);
  return CANONICAL_REPO_DIR;  // always returns "/srv/nixpi"
}
```

The function accepts a `primaryUser` parameter, validates it, then completely
ignores it — always returning the constant. This is misleading API design.

**Fix:** Either remove the parameter (since the repo dir is a fixed constant) or
use it if the intent was to support per-user paths.

---

## INC-22: `memory.ts:148` — tautological summary assignment

**File:** `core/pi/extensions/objects/memory.ts:148`

```ts
if (!merged.summary && typeof merged.title === "string") {
  merged.summary = `${merged.title}`;
}
```

`\`${merged.title}\`` is equivalent to `merged.title`. The template literal
adds nothing.

**Fix:** `merged.summary = merged.title;`
