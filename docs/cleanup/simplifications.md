# Simplifications

Opportunities to reduce code complexity without changing behavior.

---

## SIMP-1: Merge `errorResult` and `textToolResult`

**File:** `core/lib/utils.ts:13-35`

```ts
// errorResult
return { content: [{ type: "text" as const, text: message }], details: {}, isError: true };

// textToolResult
return { content: [{ type: "text" as const, text }], details };
```

These share the same structure. `errorResult` is just `textToolResult(msg, {})` with
`isError: true`.

**Fix:** Make `textToolResult` accept an optional `isError` parameter:
```ts
export function textToolResult(
  text: string,
  details: Record<string, unknown> = {},
  isError?: boolean,
) {
  return {
    content: [{ type: "text" as const, text }],
    details,
    ...(isError !== undefined ? { isError } : {}),
  };
}

export function errorResult(message: string) {
  return textToolResult(message, {}, true);
}
```

---

## SIMP-2: Replace inline tool results with `textToolResult`

**Files:**
- `core/pi/extensions/episodes/actions.ts` — 6 inline result objects
- `core/pi/extensions/os/actions.ts` — 7 inline result objects
- `core/pi/extensions/os/actions-proposal.ts` — 5 inline result objects

These all construct `{ content: [{ type: "text" as const, text }], details: {...} }`
manually. Replace with `textToolResult(text, details)`.

**Impact:** Removes ~50 lines of boilerplate across 3 files.

---

## SIMP-3: Consolidate path resolver functions into a namespace

**File:** `core/lib/filesystem.ts`

The file exports 14+ single-line path resolvers:
```ts
getNixPiDir(), getNixPiStateDir(), getPiDir(), getWizardStateDir(),
getSystemReadyPath(), getPersonaDonePath(), getQuadletDir(),
getUpdateStatusPath(), getSystemFlakeDir(), getDaemonStateDir(),
getNixPiRepoDir(), getCanonicalRepoDir()
```

**Fix:** Group into a `paths` namespace object:
```ts
export const paths = {
  nixPiDir: () => process.env.NIXPI_DIR ?? path.join(os.homedir(), "nixpi"),
  nixPiStateDir: () => process.env.NIXPI_STATE_DIR ?? path.join(os.homedir(), ".nixpi"),
  piDir: () => process.env.NIXPI_PI_DIR ?? path.join(os.homedir(), ".pi"),
  wizardStateDir: () => path.join(paths.nixPiStateDir(), "wizard-state"),
  systemReadyPath: () => path.join(paths.wizardStateDir(), "system-ready"),
  personaDonePath: () => path.join(paths.wizardStateDir(), "persona-done"),
  // ...
} as const;
```

Keep the old named exports as aliases during migration, then remove.

---

## SIMP-4: Simplify `scoreRecord` repeated filter pattern

**File:** `core/pi/extensions/objects/memory.ts:273-316`

Four consecutive `applyExactFilter` calls with the same shape:
```ts
if (!applyExactFilter(params.type, recordType, 50, "type", state)) return null;
if (!applyExactFilter(params.scope, recordScope, 25, "scope", state)) return null;
if (!applyExactFilter(params.scope_value, recordScopeValue, 15, "scope_value", state)) return null;
if (!applyExactFilter(params.status, recordStatus, 10, "status", state)) return null;
```

**Fix:** Replace with a config-driven loop:
```ts
const exactFilters = [
  { expected: params.type, actual: recordType, score: 50, reason: "type" },
  { expected: params.scope, actual: recordScope, score: 25, reason: "scope" },
  { expected: params.scope_value, actual: recordScopeValue, score: 15, reason: "scope_value" },
  { expected: params.status, actual: recordStatus, score: 10, reason: "status" },
];
for (const f of exactFilters) {
  if (!applyExactFilter(f.expected, f.actual, f.score, f.reason, state)) return null;
}
```

---

## SIMP-5: Remove `contentIndex` variable in `app.ts`

**File:** `core/chat-server/frontend/app.ts:118`

```ts
let contentIndex = 0;
```

Initialized to 0 and never changed. Used in 3 places but always passes 0.

**Fix:** Replace all `contentIndex` references with the literal `0` and remove the
variable.

---

## SIMP-6: Remove redundant aliases in `filesystem.ts`

**File:** `core/lib/filesystem.ts`

Two exported functions that are pure aliases:
```ts
// Line 68-70: safePath just delegates to safePathWithin
export function safePath(root: string, ...segments: string[]): string {
  return safePathWithin(root, ...segments);
}

// Line 150-152: getNixPiRepoDir just delegates to getCanonicalRepoDir
export function getNixPiRepoDir(): string {
  return getCanonicalRepoDir();
}

// Line 204-207: validateCanonicalRepo just delegates to assertCanonicalRepo
export function validateCanonicalRepo(args: CanonicalRepoValidationArgs): void {
  assertCanonicalRepo(args);
}
```

**Fix:** Replace all callers with the underlying function and remove the aliases.
For `safePath`, consider whether the shorter name is worth keeping as the primary
export (rename `safePathWithin` to `safePath` and drop the alias).

---

## SIMP-7: Simplify `assertCanonicalRepo` validation chain

**File:** `core/lib/filesystem.ts:173-202`

Six sequential if-checks with near-identical structure. The origin and branch
checks are symmetric pairs (check actual-without-expected, expected-without-actual,
then mismatch).

**Fix:** Extract a `assertFieldMatch(field, expected, actual)` helper:
```ts
function assertFieldMatch(field: string, expected?: string, actual?: string): void {
  if (actual !== undefined && expected === undefined)
    throw new Error(`Canonical repo ${field} expectation missing`);
  if (expected !== undefined && actual === undefined)
    throw new Error(`Canonical repo ${field} actual value missing`);
  if (expected !== undefined && actual !== expected)
    throw new Error(`Canonical repo ${field} mismatch: expected ${expected}, got ${actual}`);
}
```
Then call: `assertFieldMatch("origin", expectedOrigin, actualOrigin)` and
`assertFieldMatch("branch", expectedBranch, actualBranch)`.

---

## SIMP-8: Simplify `validation.ts` regex caching

**File:** `core/lib/validation.ts:6-13`

```ts
export function guardServiceName(name: string, prefix = "nixpi"): string | null {
  const escapedPrefix = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = new RegExp(`^${escapedPrefix}-[a-z0-9][a-z0-9-]*$`);
  if (!pattern.test(name)) { ... }
}
```

Creates a new RegExp every call. Since the prefix is almost always `"nixpi"`,
cache the compiled regex.

**Fix:**
```ts
const cache = new Map<string, RegExp>();

export function guardServiceName(name: string, prefix = "nixpi"): string | null {
  let pattern = cache.get(prefix);
  if (!pattern) {
    const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    pattern = new RegExp(`^${escaped}-[a-z0-9][a-z0-9-]*$`);
    cache.set(prefix, pattern);
  }
  // ...
}
```

---

## SIMP-9: Episode accessor helpers could be a single function

**File:** `core/pi/extensions/episodes/actions.ts:140-154`

Four nearly identical accessor functions:
```ts
function episodeKind(episode: Record<string, unknown>): string {
  return typeof episode.kind === "string" ? episode.kind : "observation";
}
function episodeImportance(episode: Record<string, unknown>): string { ... }
function episodeRoom(episode: Record<string, unknown>): string { ... }
function episodeTags(episode: Record<string, unknown>): string[] { ... }
```

**Fix:** Replace with a generic getter:
```ts
function episodeField(episode: Record<string, unknown>, key: string, fallback: string): string {
  return typeof episode[key] === "string" ? episode[key] : fallback;
}
```

---

## SIMP-10: `objects/actions.ts` path resolution is duplicated across CRUD methods

**File:** `core/pi/extensions/objects/actions.ts`

The pattern of resolving a filepath from `params.path ?? safePath(objectsDir, slug)`
with a try-catch returning `errorResult("Path traversal blocked")` is repeated in:
- `createObject` (lines 35-39)
- `updateObject` (lines 67-81)
- `upsertObject` (lines 106-113)
- `readObject` (lines 134-148)
- `linkObjects` (lines 173-179)

**Fix:** Extract a `resolveObjectPath(params)` helper:
```ts
function resolveObjectPath(params: { slug: string; path?: string }):
  string | ReturnType<typeof errorResult> {
  try {
    return params.path
      ? safePath(os.homedir(), params.path)
      : safePath(path.join(getNixPiDir(), "Objects"), `${params.slug}.md`);
  } catch {
    return errorResult("Path traversal blocked: invalid path");
  }
}
```
