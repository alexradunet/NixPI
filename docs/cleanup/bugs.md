# Bugs

Confirmed bugs that affect correctness or can cause runtime failures.

---

## BUG-1: Text duplication in chat streaming (Critical)

**Files:**
- `core/chat-server/session.ts:189-190`
- `core/chat-server/frontend/app.ts:136`

**Problem:**
`chatEventsFromAgentEvent` emits the **full accumulated text** from `message_update`
events (`block.text` is the entire message so far). The frontend client does
`accText += event.content`, treating each event as a delta. When
`message_update` fires multiple times with growing text, the client doubles/triples
the displayed text.

**Evidence:**
```ts
// session.ts:189 — emits full block text
if (block.type === "text" && block.text) {
  events.push({ type: "text", content: block.text });
}

// app.ts:136 — accumulates as if delta
accText += event.content;
```

**Fix:**
Track the previously emitted text length per message in `chatEventsFromAgentEvent`
and emit only the new characters as a delta:
```ts
// session.ts — add delta tracking
let lastTextLength = 0;
if (block.type === "text" && block.text) {
  const delta = block.text.slice(lastTextLength);
  lastTextLength = block.text.length;
  if (delta) events.push({ type: "text", content: delta });
}
```

---

## BUG-2: Env var cleanup sets `"undefined"` string instead of deleting (High)

**File:** `tests/helpers/temp-nixpi.ts:24,29`

**Problem:**
```ts
process.env._NIXPI_DIR_RESOLVED = undefined;
process.env.NIXPI_DIR = undefined;
```
In Node.js, assigning `undefined` to a `process.env` property coerces it to the
string `"undefined"`. Downstream code calling `process.env.NIXPI_DIR ?? fallback`
will get `"undefined"` (truthy string) instead of falling back to defaults.

**Fix:**
```ts
delete process.env._NIXPI_DIR_RESOLVED;
delete process.env.NIXPI_DIR;
```

---

## BUG-3: No JSON.parse error handling in NDJSON stream reader (High)

**File:** `core/chat-server/frontend/app.ts:130`

**Problem:**
```ts
const event = JSON.parse(line) as { ... };
```
If the server sends a malformed or partial line (network interruption, server
crash mid-write), `JSON.parse` throws and crashes the entire async IIFE. The
stream reader dies silently with no error feedback to the user.

**Fix:**
Wrap in try-catch:
```ts
let event;
try {
  event = JSON.parse(line);
} catch {
  continue; // skip malformed lines
}
```

---

## BUG-4: Floating promise on `init()` (Medium)

**File:** `core/chat-server/frontend/app.ts:242`

**Problem:**
```ts
init();
```
Called without `.catch()`. If `chatPanel.setAgent()` throws, the rejection is
unhandled. Biome has `noFloatingPromises: "error"` but this file is excluded
from tsc (compiled by Vite), so the rule may not fire.

**Fix:**
```ts
init().catch((err) => {
  console.error("Failed to initialize chat:", err);
  document.body.textContent = "Failed to load chat. Refresh to retry.";
});
```

---

## BUG-5: CI workflow references nonexistent Nix check (Critical)

**File:** `.github/workflows/check.yml:25`

**Problem:**
```yaml
- run: nix build .#checks.x86_64-linux.installer-calamares --no-link
```
The check `installer-calamares` does not exist in `flake.nix`. This CI step
fails on every PR and push to main.

**Fix:**
Replace with the correct check name from `flake.nix` (e.g., `installer-helper`,
`installer-backend`, `installer-frontend`, or remove the step if the check was
dropped).
