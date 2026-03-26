# Daemon

> Local chat runtime and session lifecycle

## Responsibilities

The runtime described here now lives in `core/chat-server/`, even though this page keeps the historical "Daemon" label for navigation continuity.

The current runtime has three moving parts:

1. HTTP bootstrap and static asset serving in `index.ts`
2. Session creation, reuse, and eviction in `session.ts`
3. Browser-side chat behavior in `frontend/app.ts`

## Reading order

- Start with `core/chat-server/index.ts` for the HTTP surface and environment wiring.
- Read `core/chat-server/session.ts` for the session cache, Pi agent integration, and streaming event translation.
- Read `core/chat-server/frontend/app.ts` when debugging browser behavior or event rendering.
- Read `core/os/services/nixpi-chat.nix` if you need to understand how systemd starts the runtime.

## Cleanup rule

Keep the runtime local and session-scoped. Browser requests, on-disk session state, and the `pi-coding-agent` lifecycle should stay easy to trace from one entry point without hidden transport layers.

---

## Important File Details

### `core/chat-server/index.ts`

**Responsibility**: Entry point for the local chat backend.

**Key Behavior**:
- Creates a single `ChatSessionManager`
- Accepts `POST /chat` and streams newline-delimited JSON events
- Accepts `DELETE /chat/:sessionId` to reset a session
- Serves the built frontend files for `GET /`

**Environment Variables**:
- `NIXPI_CHAT_PORT` - backend port, default `8080`
- `NIXPI_SHARE_DIR` - packaged share dir, default `/usr/local/share/nixpi`
- `PI_DIR` - Pi runtime dir, default `~/.pi`
- `NIXPI_CHAT_IDLE_TIMEOUT` - idle eviction window in seconds
- `NIXPI_CHAT_MAX_SESSIONS` - maximum concurrent in-memory sessions

**Inbound Dependencies**:
- `nixpi-chat.service`
- Browser requests proxied through nginx

**Outbound Dependencies**:
- `session.ts` for runtime state
- `frontend/dist` for static assets

---

### `core/chat-server/session.ts`

**Responsibility**: Owns per-session Pi runtime state.

**Key Class**: `ChatSessionManager`

**Responsibilities**:
- Creates session directories under `~/.pi/chat-sessions/<sessionId>`
- Builds a `SettingsManager`, `DefaultResourceLoader`, and `SessionManager`
- Creates `pi-coding-agent` sessions on first use
- Reuses active sessions and evicts old or idle sessions
- Translates agent events into the chat UI event stream

**Session Model**:
- One browser `sessionId` maps to one local working directory
- Sessions are created lazily
- The oldest session is evicted when `maxSessions` is exceeded
- Idle sessions are disposed after `idleTimeoutMs`

**Inbound Dependencies**:
- `index.ts` for all chat requests

**Outbound Dependencies**:
- `@mariozechner/pi-coding-agent`
- `core/lib/` helpers loaded through Pi resources

---

### `core/chat-server/frontend/app.ts`

**Responsibility**: Browser-side chat client for the local runtime.

**Key Behavior**:
- Sends chat turns to `POST /chat`
- Consumes streamed NDJSON events
- Renders text, tool calls, and tool results progressively
- Reuses the browser-held session ID until reset

This file is part of the runtime contract even though it runs in the browser, because the backend event format is tailored to it.

---

### `core/os/services/nixpi-chat.nix`

**Responsibility**: Wraps the local chat runtime as a modular systemd service.

**Key Behavior**:
- Launches Node against `dist/core/chat-server/index.js`
- Sets the runtime environment expected by `core/chat-server/index.ts`
- Runs as `nixpi-chat.primaryUser`
- Uses the primary user's `.pi` directory as the runtime working area

---

## Related Tests

| Test File | Coverage |
|-----------|----------|
| `tests/chat-server/server.test.ts` | HTTP contract, NDJSON streaming, and session reset endpoint |
| `tests/chat-server/session.test.ts` | Session creation, reuse, eviction, and disposal |
| `tests/nixos/nixpi-chat.nix` | Service-level NixOS coverage for the built-in local chat surface |

---

## Related

- [Architecture: Runtime Flows](../architecture/runtime-flows) - End-to-end flows
- [Tests](./tests) - Test coverage details
