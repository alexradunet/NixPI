# Enhancements

Improvements to robustness, security, and developer experience.

---

## ENH-1: Add request body size limit on `POST /chat`

**File:** `core/chat-server/index.ts:20-21`

```ts
let body = "";
for await (const chunk of req) body += chunk;
```

No size limit. A client sending a multi-GB payload could exhaust server memory.

**Fix:** Add a body size limit (e.g., 1 MB):
```ts
const MAX_BODY = 1024 * 1024; // 1 MB
let body = "";
for await (const chunk of req) {
  body += chunk;
  if (body.length > MAX_BODY) {
    res.writeHead(413).end(JSON.stringify({ error: "Request body too large" }));
    req.destroy();
    return;
  }
}
```

---

## ENH-2: Use async file reads in HTTP handler

**File:** `core/chat-server/index.ts:74`

```ts
const data = fs.readFileSync(filePath);
```

Synchronous read in an async HTTP handler blocks the event loop.

**Fix:**
```ts
import { readFile } from "node:fs/promises";
// ...
const data = await readFile(filePath);
```

---

## ENH-3: Expand MIME type map for static file serving

**File:** `core/chat-server/index.ts:76-82`

Current map: `.html`, `.js`, `.css`, `.json`, `.ico`

Missing types the Vite frontend may need:
```ts
const mime: Record<string, string> = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".ico": "image/x-icon",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".map": "application/json",
};
```

---

## ENH-4: Add coverage enforcement for `core/chat-server/`

**File:** `vitest.config.ts:13`

Currently only tracks coverage for `core/lib/**/*.ts` and `core/pi/extensions/**/*.ts`.
The chat server has tests but no coverage thresholds.

**Fix:** Add a threshold entry:
```ts
include: ["core/lib/**/*.ts", "core/pi/extensions/**/*.ts", "core/chat-server/**/*.ts"],
thresholds: {
  "core/lib/**/*.ts": { lines: 72, functions: 77, branches: 57, statements: 69 },
  "core/pi/extensions/**/*.ts": { lines: 60, functions: 60, branches: 50, statements: 60 },
  "core/chat-server/**/*.ts": { lines: 50, functions: 50, branches: 40, statements: 50 },
},
```

---

## ENH-5: Validate port number in chat server entry point

**File:** `core/chat-server/index.ts:99`

```ts
const port = parseInt(process.env.NIXPI_CHAT_PORT ?? "8080");
```

`parseInt("garbage")` returns `NaN`. No validation.

**Fix:**
```ts
const port = parseInt(process.env.NIXPI_CHAT_PORT ?? "8080", 10);
if (!Number.isFinite(port) || port < 1 || port > 65535) {
  console.error(`Invalid port: ${process.env.NIXPI_CHAT_PORT}`);
  process.exit(1);
}
```

---

## ENH-6: Add `<noscript>` fallback to frontend HTML

**File:** `core/chat-server/frontend/index.html`

No fallback when JavaScript is disabled or fails to load.

**Fix:**
```html
<noscript>
  <p>NixPI Chat requires JavaScript to run.</p>
</noscript>
```

---

## ENH-7: Add session reset capability to the web UI

**File:** `core/chat-server/frontend/app.ts`

The session ID is persisted in `localStorage` indefinitely with no way to reset
from the UI.

**Fix:** Expose a "New Session" button or keyboard shortcut that calls
`DELETE /chat/:sessionId`, clears `localStorage`, and reloads.

---

## ENH-8: Guard against `parseInt` radix ambiguity

**File:** `core/chat-server/index.ts:108`

```ts
idleTimeoutMs: parseInt(process.env.NIXPI_CHAT_IDLE_TIMEOUT ?? "1800") * 1000,
maxSessions: parseInt(process.env.NIXPI_CHAT_MAX_SESSIONS ?? "4"),
```

Missing radix parameter (should be `parseInt(value, 10)`).

**Fix:** Add explicit radix `10` to all `parseInt` calls.
