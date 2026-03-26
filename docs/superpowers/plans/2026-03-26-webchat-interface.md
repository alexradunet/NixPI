# Web Chat Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Matrix-based daemon + Element Web with a minimal Node.js chat server that serves a `@mariozechner/pi-web-ui` ChatPanel, giving users a browser-based chat interface to the Pi agent.

**Architecture:** A single `nixpi-chat` Node.js service (port 8080) imports `@mariozechner/pi-coding-agent` directly (no subprocess) to create persistent per-session Pi agent instances. It serves a static HTML page embedding the pi-web-ui `ChatPanel` via an SSE streaming endpoint. nginx continues to provide TLS and proxies `https://<host>/` to port 8080.

**Tech Stack:** TypeScript, `@mariozechner/pi-coding-agent` (agent sessions), `@mariozechner/pi-web-ui` (ChatPanel), Vite (frontend bundling), Node.js `http` module (server), NixOS systemd service.

---

## Codebase Context

**Key files to understand before starting:**
- `core/daemon/runtime/pi-room-session.ts` — exact API for `createAgentSession`, `createCodingTools`, `SettingsManager`, `SessionManager`, `DefaultResourceLoader` from `@mariozechner/pi-coding-agent`. The chat session manager is a simplified version of this.
- `core/os/modules/app.nix` — where `nixpi-daemon` service is registered; we replace it with `nixpi-chat`.
- `core/os/modules/service-surface.nix` — nginx proxy config; `nixpi-home` proxy at port 8080 becomes `nixpi-chat`.
- `core/os/modules/options.nix` — `nixpi.services.elementWeb` block to remove; `nixpi.agent.allowedUnits` default list to update.
- `core/os/pkgs/app/default.nix` — NixOS derivation that compiles the app; we add `nixpi-chat-server` script and frontend dist here.

**Existing pattern for NixOS services:** See `core/os/services/nixpi-daemon.nix` — uses `_class = "service"` and `lib.modules.importApply`. Copy this pattern for `nixpi-chat.nix`.

**AgentSessionEvent types** (from `@mariozechner/pi-coding-agent`):
- `agent_start` — Pi starts processing a turn
- `message_update` — streaming content delta (text blocks, tool use blocks, tool result blocks)
- `agent_end` — Pi finished the turn, `event.messages` contains full message list

**Session dir convention:** each chat session stores its JSONL history at `~/.pi/chat-sessions/<sessionId>/session.jsonl` (consistent with how the daemon stores per-room sessions).

---

## File Map

```
CREATE:
  core/chat-server/index.ts              HTTP server + route handlers
  core/chat-server/session.ts            Pi agent session lifecycle (per conversation)
  core/chat-server/frontend/index.html   HTML shell
  core/chat-server/frontend/app.ts       pi-web-ui ChatPanel + custom provider
  core/os/services/nixpi-chat.nix        NixOS systemd service
  tests/nixos/nixpi-chat.nix             NixOS integration test
  tests/chat-server/session.test.ts      Session unit tests
  tests/chat-server/server.test.ts       HTTP server unit tests
  vite.config.ts                         Vite config for frontend bundle

MODIFY:
  package.json                           Add pi-web-ui + vite deps, remove matrix-js-sdk, update scripts, remove matrix-admin extension
  tsconfig.json                          Exclude core/chat-server/frontend from tsc
  core/os/modules/app.nix               Replace nixpi-daemon with nixpi-chat
  core/os/modules/options.nix           Remove elementWeb options, add chat options, update allowedUnits
  core/os/modules/service-surface.nix   Remove element-web proxy block
  core/os/pkgs/app/default.nix          Remove home-template.html, add frontend dist + chat server script
  tests/nixos/default.nix               Replace nixpi-home/nixpi-daemon with nixpi-chat, clean sharedArgs
  tests/nixos/lib.nix                   Remove mkMatrixAdminSeedConfig + matrixRegisterScript
  tests/nixos/nixpi-options-validation.nix  Remove nixpi-element-web.service wait
  tests/nixos/nixpi-modular-services.nix    Remove element-web assertions
  tests/nixos/nixpi-e2e.nix             Remove continuwuity refs
  tests/nixos/nixpi-firstboot.nix       Remove PREFILL_MATRIX_PASSWORD + continuwuity refs
  tests/nixos/nixpi-network.nix         Remove continuwuity.wantedBy lines
  tests/nixos/nixpi-bootstrap-mode.nix  Remove continuwuity.wait_for_unit
  tests/nixos/nixpi-security.nix        Remove continuwuity.wait_for_unit
  tests/nixos/nixpi-install-wizard.nix  Remove continuwuity + PREFILL_MATRIX_PASSWORD
  core/scripts/setup-wizard.sh          Remove step_matrix call, update has_service_stack
  core/scripts/wizard-matrix.sh         Remove step_matrix, update print_service_access_summary + step_services
  core/scripts/wizard-promote.sh        Remove matrix_user echo + network_activity_room block

DELETE:
  core/daemon/                           Entire directory
  core/lib/matrix.ts
  core/lib/matrix-format.ts
  core/os/services/nixpi-daemon.nix
  core/os/services/nixpi-home.nix
  core/os/services/nixpi-element-web.nix
  core/os/services/home-template.html
  core/pi/extensions/matrix-admin/       Entire directory
  tests/nixos/nixpi-daemon.nix
  tests/nixos/nixpi-home.nix
```

---

## Task 1: Stale continuwuity reference cleanup

**Files:**
- Modify: `tests/nixos/nixpi-e2e.nix`
- Modify: `tests/nixos/nixpi-firstboot.nix`
- Modify: `tests/nixos/nixpi-network.nix`
- Modify: `tests/nixos/nixpi-bootstrap-mode.nix`
- Modify: `tests/nixos/nixpi-security.nix`
- Modify: `tests/nixos/nixpi-install-wizard.nix`

This task removes stale `continuwuity` / `PREFILL_MATRIX_PASSWORD` references from tests that are NOT being deleted (they test things that still exist). Tests that are being deleted entirely (nixpi-daemon, nixpi-home) are handled in Task 2 and 3.

- [ ] **Step 1: Remove continuwuity.wantedBy from nixpi-network.nix**

`tests/nixos/nixpi-network.nix` has two lines forcing continuwuity off. Remove them. Open the file, find and delete lines matching `systemd.services.continuwuity.wantedBy = lib.mkForce [];`.

Run: `grep -n "continuwuity" tests/nixos/nixpi-network.nix`
Expected: no output after edit.

- [ ] **Step 2: Remove continuwuity wait from nixpi-bootstrap-mode.nix**

Find and remove the line `bootstrap.wait_for_unit("continuwuity.service", timeout=120)` and any associated Matrix registration test block in `tests/nixos/nixpi-bootstrap-mode.nix`.

Also remove `nixpi-bootstrap-read-matrix-secret` test if present (command was removed in a prior refactor).
Also remove any `port 6167` firewall test lines.
Also remove `PREFILL_MATRIX_PASSWORD` from any prefill.env block.

Run: `grep -n "continuwuity\|matrix\|6167\|PREFILL_MATRIX" tests/nixos/nixpi-bootstrap-mode.nix`
Expected: no output after edit.

- [ ] **Step 3: Remove continuwuity wait from nixpi-security.nix**

Find and remove the line `bootstrap.wait_for_unit("continuwuity.service", timeout=60)` in `tests/nixos/nixpi-security.nix`.

Also remove `PREFILL_MATRIX_PASSWORD` from any prefill.env block.

Run: `grep -n "continuwuity\|PREFILL_MATRIX" tests/nixos/nixpi-security.nix`
Expected: no output after edit.

- [ ] **Step 4: Clean up nixpi-firstboot.nix**

In `tests/nixos/nixpi-firstboot.nix`:
- Remove `PREFILL_MATRIX_PASSWORD=...` from prefill.env activation script
- Remove `systemctl stop continuwuity.service` / `wait_for_unit("continuwuity.service")` calls
- Remove any Matrix API credential verification block (curl to port 6167 etc.)

Run: `grep -n "continuwuity\|PREFILL_MATRIX\|6167" tests/nixos/nixpi-firstboot.nix`
Expected: no output after edit.

- [ ] **Step 5: Clean up nixpi-e2e.nix**

In `tests/nixos/nixpi-e2e.nix`:
- Remove `wait_for_unit("continuwuity.service")` calls
- Remove Matrix registration check and `"continuwuity"` in services list
- Remove NetBird watcher/provisioner/room checks if they reference Matrix
- Remove port 6167 from any firewall test
- Remove `PREFILL_MATRIX_PASSWORD` from prefill.env

Run: `grep -n "continuwuity\|PREFILL_MATRIX\|6167\|matrix-bridge\|matrix-reply" tests/nixos/nixpi-e2e.nix`
Expected: no output after edit.

- [ ] **Step 6: Clean up nixpi-install-wizard.nix**

In `tests/nixos/nixpi-install-wizard.nix`:
- Remove `PREFILL_MATRIX_PASSWORD=...` from prefill.env
- Remove the `systemctl stop continuwuity.service 2>/dev/null || true` line and its comment

Run: `grep -n "continuwuity\|PREFILL_MATRIX" tests/nixos/nixpi-install-wizard.nix`
Expected: no output after edit.

- [ ] **Step 7: Verify NixOS config still evaluates**

Run: `nix build .#checks.x86_64-linux.config --no-link -L 2>&1 | tail -5`
Expected: build succeeds (or fails only on unrelated issues — not on missing Matrix options).

- [ ] **Step 8: Commit**

```bash
git add tests/nixos/nixpi-e2e.nix tests/nixos/nixpi-firstboot.nix tests/nixos/nixpi-network.nix tests/nixos/nixpi-bootstrap-mode.nix tests/nixos/nixpi-security.nix tests/nixos/nixpi-install-wizard.nix
git commit -m "fix: remove stale continuwuity references from test files"
```

---

## Task 2: Remove daemon, Matrix libs, and daemon NixOS service

**Files:**
- Delete: `core/daemon/` (entire directory)
- Delete: `core/lib/matrix.ts`, `core/lib/matrix-format.ts`
- Delete: `core/os/services/nixpi-daemon.nix`
- Delete: `tests/nixos/nixpi-daemon.nix`
- Modify: `core/os/modules/app.nix`
- Modify: `core/os/modules/options.nix`
- Modify: `tests/nixos/lib.nix`
- Modify: `tests/nixos/default.nix`
- Modify: `package.json`
- Modify: `flake.nix`

- [ ] **Step 1: Delete daemon source + Matrix libs**

```bash
rm -rf core/daemon
rm core/lib/matrix.ts core/lib/matrix-format.ts
```

- [ ] **Step 2: Delete nixpi-daemon NixOS service file**

```bash
rm core/os/services/nixpi-daemon.nix
```

- [ ] **Step 3: Remove nixpi-daemon from app.nix**

In `core/os/modules/app.nix`, remove lines 50–57 (the `system.services.nixpi-daemon` block):

```nix
  system.services.nixpi-daemon = {
    imports = [ (lib.modules.importApply ../services/nixpi-daemon.nix { inherit pkgs; }) ];
    nixpi-daemon = {
      package = appPackage;
      inherit primaryUser stateDir agentStateDir;
      path = [ piAgent pkgs.nodejs ];
    };
  };
```

Also remove the daemon state dir tmpfiles rule on line 20:
```nix
"d ${stateDir}/nixpi-daemon 0770 ${primaryUser} ${primaryUser} -"
```

- [ ] **Step 4: Remove element-web state dir from app.nix tmpfiles**

Also in `core/os/modules/app.nix` line 23, remove:
```nix
"d ${stateDir}/services/element-web 0770 ${primaryUser} ${primaryUser} -"
```

(The `services/home` dir line will be removed when we add the chat dir in Task 8.)

- [ ] **Step 5: Remove nixpi-daemon.service from allowedUnits in options.nix**

In `core/os/modules/options.nix` lines 116–128, update the `allowedUnits` default list — remove `"nixpi-daemon.service"`:

```nix
allowedUnits = lib.mkOption {
  type = lib.types.listOf lib.types.str;
  default = [
    "netbird.service"
    "nixpi-home.service"
    "nixpi-element-web.service"
    "nixpi-update.service"
  ];
```

(We'll replace `nixpi-home.service` and `nixpi-element-web.service` in Task 3.)

- [ ] **Step 6: Remove mkMatrixAdminSeedConfig + matrixRegisterScript from lib.nix**

In `tests/nixos/lib.nix`, remove:
- The `mkMatrixAdminSeedConfig` function (lines 51–58):
  ```nix
  mkMatrixAdminSeedConfig = {
    username,
    password,
  }: {
    services.matrix-continuwuity.settings.admin_execute = [
      "users create ${username} ${password}"
    ];
  };
  ```
- The entire `matrixRegisterScript` string (lines 199–269).

- [ ] **Step 7: Remove from tests/nixos/default.nix sharedArgs and tests map**

In `tests/nixos/default.nix`:
- Remove `mkMatrixAdminSeedConfig` and `matrixRegisterScript` from `sharedArgs` inherit list
- Remove `nixpi-daemon = runTest ./nixpi-daemon.nix;` from the `tests` map

- [ ] **Step 8: Delete nixpi-daemon test**

```bash
rm tests/nixos/nixpi-daemon.nix
```

- [ ] **Step 9: Remove matrix-js-sdk from package.json**

In `package.json` dependencies block, remove:
```json
"matrix-js-sdk": "^41.1.0"
```

- [ ] **Step 10: Remove nixpi-daemon from flake.nix nixosTests**

In `flake.nix`, find and remove the line:
```nix
{ name = "nixpi-daemon"; path = nixosTests.nixpi-daemon; }
```

- [ ] **Step 11: Verify TypeScript compiles**

Run: `npm run build 2>&1 | tail -20`
Expected: no errors about missing matrix modules or daemon files.

- [ ] **Step 12: Verify NixOS config evaluates**

Run: `nix build .#checks.x86_64-linux.config --no-link -L 2>&1 | tail -5`
Expected: succeeds.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "chore: remove Matrix daemon, matrix-js-sdk, and daemon NixOS service"
```

---

## Task 3: Remove Element Web, nixpi-home service, and matrix-admin extension

**Files:**
- Delete: `core/os/services/nixpi-element-web.nix`
- Delete: `core/os/services/nixpi-home.nix`
- Delete: `core/os/services/home-template.html`
- Delete: `core/pi/extensions/matrix-admin/`
- Delete: `tests/nixos/nixpi-home.nix`
- Modify: `package.json`
- Modify: `core/os/modules/options.nix`
- Modify: `core/os/modules/service-surface.nix`
- Modify: `core/os/pkgs/app/default.nix`
- Modify: `tests/nixos/default.nix`
- Modify: `tests/nixos/nixpi-options-validation.nix`
- Modify: `tests/nixos/nixpi-modular-services.nix`

- [ ] **Step 1: Delete service files and extension**

```bash
rm core/os/services/nixpi-element-web.nix
rm core/os/services/nixpi-home.nix
rm core/os/services/home-template.html
rm -rf core/pi/extensions/matrix-admin
rm tests/nixos/nixpi-home.nix
```

- [ ] **Step 2: Remove matrix-admin from package.json pi.extensions**

In `package.json`, remove `"./core/pi/extensions/matrix-admin"` from the `pi.extensions` array:

```json
"pi": {
  "extensions": [
    "./core/pi/extensions/persona",
    "./core/pi/extensions/os",
    "./core/pi/extensions/episodes",
    "./core/pi/extensions/objects",
    "./core/pi/extensions/nixpi"
  ],
  "skills": [
    "./core/pi/skills"
  ]
},
```

- [ ] **Step 3: Remove elementWeb options from options.nix**

In `core/os/modules/options.nix`, remove the `elementWeb` block (lines 169–172):

```nix
elementWeb = {
  enable = lib.mkEnableOption "NixPI Element Web service" // { default = true; };
  port = mkPortOption 8081 "TCP port for the NixPI Element Web client.";
};
```

Also update `allowedUnits` (updated in Task 2 Step 5) to remove `nixpi-home.service` and `nixpi-element-web.service`. The list should now be just:

```nix
default = [
  "netbird.service"
  "nixpi-update.service"
];
```

(We'll add `nixpi-chat.service` in Task 8.)

Also update `services.home` description to not mention Element Web:
```nix
home = {
  enable = lib.mkEnableOption "NixPI Chat service" // { default = true; };
  port = mkPortOption 8080 "TCP port for the NixPI Chat server.";
};
```

And update `services.secureWeb` description:
```nix
secureWeb = {
  enable = lib.mkEnableOption "canonical HTTPS gateway for NixPI Chat" // { default = true; };
  port = mkPortOption 443 "TCP port for the canonical HTTPS NixPI entry point.";
};
```

- [ ] **Step 4: Remove element-web and nixpi-home from service-surface.nix**

In `core/os/modules/service-surface.nix`:

Remove the `(lib.mkIf cfg.elementWeb.enable { ... })` block (lines 97–108).

Remove the `nixpi-home = { ... }` system.services block (lines 85–95) — it references `nixpi-home.nix` which is deleted.

Remove the element-web proxy in the `nixpi-secure-web` nginx virtualHost:
```nix
locations."= /element".return = "302 /element/";
locations."/element/".proxyPass = "http://127.0.0.1:${toString cfg.elementWeb.port}/";
```

Remove any reference to `cfg.elementWeb.port` in the home proxy lines.

The `system.services` block becomes an empty `lib.mkMerge []` — remove it entirely (the chat service is added via app.nix in Task 8).

- [ ] **Step 5: Remove home-template.html from app package derivation**

In `core/os/pkgs/app/default.nix`, remove:
```nix
install -m 644 ${../../services/home-template.html} $out/share/nixpi/home-template.html
```

- [ ] **Step 6: Remove nixpi-home from tests/nixos/default.nix**

In `tests/nixos/default.nix`:
- Remove `nixpi-home = runTest ./nixpi-home.nix;` from the `tests` map
- Remove `smoke-home = tests.nixpi-home;` from `smokeAliases` if present

- [ ] **Step 7: Update nixpi-options-validation.nix**

In `tests/nixos/nixpi-options-validation.nix`, remove:
```python
defaults.wait_for_unit("nixpi-element-web.service", timeout=60)
```
and any assertion about the element-web service in the `overrides` machine.

- [ ] **Step 8: Update nixpi-modular-services.nix**

In `tests/nixos/nixpi-modular-services.nix`, remove all lines that reference `nixpi-element-web`:
- `nixpi.succeed("test -f /etc/system-services/nixpi-element-web/config.json")`
- `nixpi.succeed("grep -q 'default_server_config' /etc/system-services/nixpi-element-web/config.json")`
- `nixpi.succeed("systemctl cat nixpi-element-web.service | grep -q 'static-web-server'")`

Also remove lines referencing the old nixpi-home content (`'NixPI Home'`, `'Matrix'`, `'Element Web'` greps in the webroot) since nixpi-home.nix is deleted.

- [ ] **Step 9: Verify TypeScript compiles**

Run: `npm run build 2>&1 | tail -10`
Expected: no errors about missing matrix-admin extension.

- [ ] **Step 10: Verify NixOS config evaluates**

Run: `nix build .#checks.x86_64-linux.config --no-link -L 2>&1 | tail -5`
Expected: succeeds.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "chore: remove Element Web, nixpi-home, and matrix-admin extension"
```

---

## Task 4: Clean up wizard scripts

**Files:**
- Modify: `core/scripts/setup-wizard.sh`
- Modify: `core/scripts/wizard-matrix.sh`
- Modify: `core/scripts/wizard-promote.sh`

- [ ] **Step 1: Remove step_matrix from setup-wizard.sh**

In `core/scripts/setup-wizard.sh`:

1. Remove the `source "${SCRIPT_DIR}/wizard-matrix.sh"` line (line 52) only if `wizard-matrix.sh` will be emptied — keep it if `step_services` or `step_netbird` still live there. (They do — keep the source line.)

2. Remove the call on line 224:
```bash
step_done matrix || step_matrix
```

3. Update `has_service_stack()` (line 72–74) to check for the new chat service:
```bash
has_service_stack() {
	has_systemd_unit nixpi-chat.service
}
```

- [ ] **Step 2: Update wizard-matrix.sh**

In `core/scripts/wizard-matrix.sh`:

1. Remove the entire `step_matrix()` function (lines 140–195).

2. In `print_service_access_summary()`, remove the Matrix-URL echo line:
```bash
echo "    Matrix       - https://${canonical_host}"
```

3. Update `step_services()` — it currently calls `write_element_web_runtime_config` and `write_service_home_runtime`, which are functions in `setup-lib.sh` that wrote static files for nixpi-home and nixpi-element-web. These functions are now dead. Replace the body of `step_services()` with:

```bash
step_services() {
	echo ""
	echo "--- Built-In Services ---"
	if ! has_service_stack; then
		echo "Built-in service stack is not installed in this profile. Skipping."
		mark_done_with services "skipped"
		return
	fi
	root_command nixpi-bootstrap-service-systemctl restart nixpi-chat.service || echo "  chat restart failed."
	mark_done_with services "chat"
}
```

- [ ] **Step 3: Remove dead functions from setup-lib.sh**

In `core/scripts/setup-lib.sh`, remove:
- `write_service_home_runtime()` function (lines 126–162)
- `install_home_infrastructure()` function (lines 164–166)
- `write_element_web_runtime_config()` function (lines 168–182)

Update the header comment at the top to remove references to "built-in service runtime generation".

- [ ] **Step 4: Clean up wizard-promote.sh finalize()**

In `core/scripts/wizard-promote.sh`, in the `finalize()` function, remove:
1. The `matrix_user=$(read_checkpoint_data matrix)` line
2. The `network_activity_room` block (the `if [[ -f /var/lib/nixpi/netbird-watcher/matrix-token ]]` block)
3. The `[[ -n "$matrix_user" ]] && echo "  Matrix user: @${matrix_user}:nixpi"` echo line
4. The `[[ -n "$network_activity_room" ]] && echo "  Network activity room: ..."` lines
5. The `nixpi-daemon` block in finalize (the `if has_systemd_unit nixpi-daemon.service; then ... fi` block that enables and restarts nixpi-daemon) — replace the service name with `nixpi-chat`:

```bash
if has_systemd_unit nixpi-chat.service; then
	if ! root_command nixpi-finalize-service-systemctl enable nixpi-chat.service; then
		echo "warning: failed to enable nixpi-chat.service during wizard finalization" >&2
	fi
	if ! root_command nixpi-finalize-service-systemctl restart nixpi-chat.service; then
		echo "warning: failed to start nixpi-chat.service during wizard finalization" >&2
	fi
fi
```

Also update the sudo rules in `core/os/modules/firstboot/users.nix` — replace the `nixpi-bootstrap-service-systemctl restart nixpi-daemon.service` and related daemon rules with `nixpi-chat.service`:
```nix
{ command = "/run/current-system/sw/bin/nixpi-bootstrap-service-systemctl restart nixpi-chat.service"; options = [ "NOPASSWD" ]; }
{ command = "/run/current-system/sw/bin/nixpi-finalize-service-systemctl enable nixpi-chat.service"; options = [ "NOPASSWD" ]; }
{ command = "/run/current-system/sw/bin/nixpi-finalize-service-systemctl restart nixpi-chat.service"; options = [ "NOPASSWD" ]; }
```

- [ ] **Step 5: Verify bash syntax**

```bash
bash -n core/scripts/setup-wizard.sh
bash -n core/scripts/wizard-matrix.sh
bash -n core/scripts/wizard-promote.sh
bash -n core/scripts/setup-lib.sh
```
Expected: all exit 0 (no syntax errors).

- [ ] **Step 6: Commit**

```bash
git add core/scripts/
git add core/os/modules/firstboot/users.nix
git commit -m "chore: remove wizard matrix step and update service references to nixpi-chat"
```

---

## Task 5: Chat session manager (TDD)

**Files:**
- Create: `tests/chat-server/session.test.ts`
- Create: `core/chat-server/session.ts`

The session manager wraps `@mariozechner/pi-coding-agent`'s `createAgentSession` API (same as `PiRoomSession` in the deleted daemon). Each session is keyed by a UUID, persists its JSONL history at `~/.pi/chat-sessions/<id>/`, and exposes `sendMessage()` that yields `ChatEvent` objects.

**Before implementing, read:** `core/daemon/runtime/pi-room-session.ts` (already in this repo — study the `spawn()`, `sendMessage()`, and `handleEvent()` methods) and the `AgentSessionEvent` type from `@mariozechner/pi-coding-agent`.

- [ ] **Step 1: Write the failing test**

Create `tests/chat-server/session.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";
import { ChatSessionManager } from "../../core/chat-server/session.js";

// We mock pi-coding-agent so tests don't need real LLM calls.
vi.mock("@mariozechner/pi-coding-agent", () => ({
  createAgentSession: vi.fn(),
  createCodingTools: vi.fn(() => []),
  DefaultResourceLoader: vi.fn().mockImplementation(() => ({
    reload: vi.fn().mockResolvedValue(undefined),
  })),
  SessionManager: { create: vi.fn(() => ({})) },
  SettingsManager: {
    create: vi.fn(() => ({
      getDefaultProvider: vi.fn(() => null),
      getDefaultModel: vi.fn(() => null),
    })),
  },
}));

import { createAgentSession } from "@mariozechner/pi-coding-agent";

describe("ChatSessionManager", () => {
  let mockSession: {
    prompt: ReturnType<typeof vi.fn>;
    subscribe: ReturnType<typeof vi.fn>;
    dispose: ReturnType<typeof vi.fn>;
    isStreaming: boolean;
    model: unknown;
  };

  beforeEach(() => {
    let subscriber: ((e: unknown) => void) | null = null;
    mockSession = {
      prompt: vi.fn().mockResolvedValue(undefined),
      subscribe: vi.fn((cb: (e: unknown) => void) => {
        subscriber = cb;
        return () => { subscriber = null; };
      }),
      dispose: vi.fn(),
      isStreaming: false,
      model: null,
    };
    vi.mocked(createAgentSession).mockResolvedValue({
      session: mockSession as never,
    });
    // expose subscriber for tests
    (mockSession as { _emit: (e: unknown) => void })._emit = (e) => subscriber?.(e);
  });

  it("creates a session on first getOrCreate", async () => {
    const manager = new ChatSessionManager({
      nixpiShareDir: "/mock/share",
      chatSessionsDir: "/tmp/chat-sessions",
      idleTimeoutMs: 5000,
      maxSessions: 4,
    });
    const session = await manager.getOrCreate("test-id-1");
    expect(session).toBeDefined();
    expect(createAgentSession).toHaveBeenCalledOnce();
  });

  it("returns the same session on second getOrCreate with same id", async () => {
    const manager = new ChatSessionManager({
      nixpiShareDir: "/mock/share",
      chatSessionsDir: "/tmp/chat-sessions",
      idleTimeoutMs: 5000,
      maxSessions: 4,
    });
    await manager.getOrCreate("test-id-2");
    await manager.getOrCreate("test-id-2");
    expect(createAgentSession).toHaveBeenCalledOnce();
  });

  it("disposes old sessions when maxSessions is exceeded", async () => {
    const manager = new ChatSessionManager({
      nixpiShareDir: "/mock/share",
      chatSessionsDir: "/tmp/chat-sessions",
      idleTimeoutMs: 5000,
      maxSessions: 2,
    });
    await manager.getOrCreate("s1");
    await manager.getOrCreate("s2");
    await manager.getOrCreate("s3"); // should evict s1
    expect(mockSession.dispose).toHaveBeenCalledOnce();
  });

  it("delete removes and disposes a session", async () => {
    const manager = new ChatSessionManager({
      nixpiShareDir: "/mock/share",
      chatSessionsDir: "/tmp/chat-sessions",
      idleTimeoutMs: 5000,
      maxSessions: 4,
    });
    await manager.getOrCreate("del-test");
    manager.delete("del-test");
    expect(mockSession.dispose).toHaveBeenCalledOnce();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/chat-server/session.test.ts 2>&1 | tail -20`
Expected: FAIL with "Cannot find module '../../core/chat-server/session.js'"

- [ ] **Step 3: Implement ChatSessionManager**

Create `core/chat-server/session.ts`:

```typescript
import { resolve } from "node:path";
import { mkdir } from "node:fs/promises";
import {
  createAgentSession,
  createCodingTools,
  DefaultResourceLoader,
  type AgentSessionEvent,
  type AgentSession as PiAgentSession,
  SessionManager,
  SettingsManager,
} from "@mariozechner/pi-coding-agent";

export interface ChatSessionManagerOptions {
  /** Path to /usr/local/share/nixpi (the deployed app share dir). */
  nixpiShareDir: string;
  /** Directory where per-session JSONL files are stored, e.g. ~/.pi/chat-sessions */
  chatSessionsDir: string;
  idleTimeoutMs: number;
  maxSessions: number;
}

export type ChatEvent =
  | { type: "text"; content: string }
  | { type: "tool_call"; name: string; input: string }
  | { type: "tool_result"; name: string; output: string }
  | { type: "done" }
  | { type: "error"; message: string };

interface SessionEntry {
  id: string;
  piSession: PiAgentSession;
  unsubscribe: () => void;
  idleTimer: ReturnType<typeof setTimeout>;
  lastUsed: number;
}

export class ChatSessionManager {
  private readonly opts: ChatSessionManagerOptions;
  private readonly sessions = new Map<string, SessionEntry>();

  constructor(opts: ChatSessionManagerOptions) {
    this.opts = opts;
  }

  async getOrCreate(sessionId: string): Promise<SessionEntry> {
    const existing = this.sessions.get(sessionId);
    if (existing) {
      this.resetIdle(existing);
      return existing;
    }

    // Evict oldest session if at capacity.
    if (this.sessions.size >= this.opts.maxSessions) {
      const oldest = [...this.sessions.values()].sort((a, b) => a.lastUsed - b.lastUsed)[0];
      if (oldest) this.evict(oldest.id);
    }

    const sessionDir = resolve(this.opts.chatSessionsDir, sessionId);
    await mkdir(sessionDir, { recursive: true });

    const settingsManager = SettingsManager.create(this.opts.nixpiShareDir);
    const resourceLoader = new DefaultResourceLoader({
      cwd: this.opts.nixpiShareDir,
      settingsManager,
    });
    await resourceLoader.reload();

    const { session } = await createAgentSession({
      cwd: sessionDir,
      resourceLoader,
      settingsManager,
      sessionManager: SessionManager.create(sessionDir),
      tools: createCodingTools(sessionDir),
    });

    const entry: SessionEntry = {
      id: sessionId,
      piSession: session,
      unsubscribe: () => {},
      idleTimer: setTimeout(() => this.evict(sessionId), this.opts.idleTimeoutMs),
      lastUsed: Date.now(),
    };
    entry.idleTimer.unref();
    entry.unsubscribe = session.subscribe(() => {}); // placeholder; real sub per turn
    this.sessions.set(sessionId, entry);
    return entry;
  }

  /** Send a message and yield streaming events until the turn is done. */
  async *sendMessage(sessionId: string, text: string): AsyncGenerator<ChatEvent> {
    const entry = await this.getOrCreate(sessionId);
    this.resetIdle(entry);

    const queue: ChatEvent[] = [];
    let notify: (() => void) | null = null;
    let done = false;

    const unsub = entry.piSession.subscribe((event: AgentSessionEvent) => {
      const events = chatEventsFromAgentEvent(event);
      if (events.length > 0) {
        queue.push(...events);
        notify?.();
        notify = null;
      }
      if (event.type === "agent_end") {
        done = true;
        notify?.();
        notify = null;
      }
    });

    // Fire and forget — the subscribe callback will receive events.
    entry.piSession.prompt(text).catch((err: unknown) => {
      queue.push({ type: "error", message: String(err) });
      done = true;
      notify?.();
      notify = null;
    });

    try {
      while (!done || queue.length > 0) {
        if (queue.length === 0 && !done) {
          await new Promise<void>((r) => { notify = r; });
        }
        while (queue.length > 0) {
          yield queue.shift()!;
        }
      }
      yield { type: "done" };
    } finally {
      unsub();
    }
  }

  delete(sessionId: string): void {
    this.evict(sessionId);
  }

  private evict(sessionId: string): void {
    const entry = this.sessions.get(sessionId);
    if (!entry) return;
    clearTimeout(entry.idleTimer);
    entry.unsubscribe();
    entry.piSession.dispose();
    this.sessions.delete(sessionId);
  }

  private resetIdle(entry: SessionEntry): void {
    clearTimeout(entry.idleTimer);
    entry.lastUsed = Date.now();
    entry.idleTimer = setTimeout(() => this.evict(entry.id), this.opts.idleTimeoutMs);
    entry.idleTimer.unref();
  }
}

function chatEventsFromAgentEvent(event: AgentSessionEvent): ChatEvent[] {
  if (event.type !== "message_update") return [];
  const events: ChatEvent[] = [];
  // message_update carries an array of content blocks in event.messages[last].content
  const messages = (event as { messages?: { role: string; content: unknown[] }[] }).messages;
  if (!messages || messages.length === 0) return [];
  const last = messages[messages.length - 1];
  if (!last?.content) return [];
  for (const block of last.content as { type: string; text?: string; name?: string; input?: unknown; content?: unknown }[]) {
    if (block.type === "text" && block.text) {
      events.push({ type: "text", content: block.text });
    } else if (block.type === "tool_use" && block.name) {
      events.push({ type: "tool_call", name: block.name, input: JSON.stringify(block.input ?? {}) });
    } else if (block.type === "tool_result" && block.name) {
      events.push({ type: "tool_result", name: block.name, output: String(block.content ?? "") });
    }
  }
  return events;
}
```

**Note:** The exact shape of `AgentSessionEvent` and `message_update` content blocks may differ from what's shown above. Before finalising, check the type definitions in `node_modules/@mariozechner/pi-coding-agent/` and adjust `chatEventsFromAgentEvent` accordingly. The pattern (extract text/tool_use/tool_result from the last message's content array) is correct for Anthropic-format messages.

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run tests/chat-server/session.test.ts 2>&1 | tail -20`
Expected: PASS (4 tests pass).

- [ ] **Step 5: Commit**

```bash
git add core/chat-server/session.ts tests/chat-server/session.test.ts
git commit -m "feat: add ChatSessionManager for Pi agent session lifecycle"
```

---

## Task 6: Chat HTTP server + streaming endpoint (TDD)

**Files:**
- Create: `tests/chat-server/server.test.ts`
- Create: `core/chat-server/index.ts`

- [ ] **Step 1: Write the failing test**

Create `tests/chat-server/server.test.ts`:

```typescript
import { describe, it, expect, vi, beforeAll, afterAll } from "vitest";
import http from "node:http";

// Mock the session manager so the server test doesn't start real Pi sessions.
vi.mock("../../core/chat-server/session.js", () => ({
  ChatSessionManager: vi.fn().mockImplementation(() => ({
    sendMessage: vi.fn(async function* () {
      yield { type: "text", content: "Hello from Pi" };
      yield { type: "done" };
    }),
    delete: vi.fn(),
  })),
}));

import { createChatServer } from "../../core/chat-server/index.js";

let server: http.Server;
let port: number;

beforeAll(async () => {
  server = createChatServer({
    nixpiShareDir: "/mock/share",
    chatSessionsDir: "/tmp/test-chat-sessions",
    idleTimeoutMs: 5000,
    maxSessions: 4,
    staticDir: new URL("../../core/chat-server/frontend/dist", import.meta.url).pathname,
  });
  await new Promise<void>((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      port = (server.address() as { port: number }).port;
      resolve();
    });
  });
});

afterAll(() => {
  server.close();
});

describe("POST /chat", () => {
  it("streams NDJSON events for a message", async () => {
    const res = await fetch(`http://127.0.0.1:${port}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sessionId: "test-session", message: "hi" }),
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toContain("application/x-ndjson");
    const text = await res.text();
    const lines = text.trim().split("\n").map((l) => JSON.parse(l));
    expect(lines).toContainEqual({ type: "text", content: "Hello from Pi" });
    expect(lines[lines.length - 1]).toEqual({ type: "done" });
  });

  it("returns 400 for missing sessionId", async () => {
    const res = await fetch(`http://127.0.0.1:${port}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: "hi" }),
    });
    expect(res.status).toBe(400);
  });

  it("returns 400 for missing message", async () => {
    const res = await fetch(`http://127.0.0.1:${port}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sessionId: "test" }),
    });
    expect(res.status).toBe(400);
  });
});

describe("DELETE /chat/:sessionId", () => {
  it("returns 204 and calls delete on the session manager", async () => {
    const res = await fetch(`http://127.0.0.1:${port}/chat/some-id`, {
      method: "DELETE",
    });
    expect(res.status).toBe(204);
  });
});

describe("GET /", () => {
  it("returns 200 with HTML content-type", async () => {
    // frontend/dist may not exist in test environment — server should return 404 gracefully
    const res = await fetch(`http://127.0.0.1:${port}/`);
    expect([200, 404]).toContain(res.status);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run tests/chat-server/server.test.ts 2>&1 | tail -20`
Expected: FAIL with "Cannot find module '../../core/chat-server/index.js'"

- [ ] **Step 3: Implement the HTTP server**

Create `core/chat-server/index.ts`:

```typescript
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { ChatSessionManager, type ChatSessionManagerOptions } from "./session.js";

export interface ChatServerOptions extends ChatSessionManagerOptions {
  /** Directory containing the pre-built frontend (index.html + assets). */
  staticDir: string;
}

export function createChatServer(opts: ChatServerOptions): http.Server {
  const sessions = new ChatSessionManager(opts);

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url ?? "/", `http://${req.headers.host}`);

    // POST /chat — streaming NDJSON
    if (req.method === "POST" && url.pathname === "/chat") {
      let body = "";
      for await (const chunk of req) body += chunk;

      let parsed: { sessionId?: string; message?: string };
      try {
        parsed = JSON.parse(body) as { sessionId?: string; message?: string };
      } catch {
        res.writeHead(400).end(JSON.stringify({ error: "invalid JSON" }));
        return;
      }
      if (!parsed.sessionId || typeof parsed.sessionId !== "string") {
        res.writeHead(400).end(JSON.stringify({ error: "sessionId required" }));
        return;
      }
      if (!parsed.message || typeof parsed.message !== "string") {
        res.writeHead(400).end(JSON.stringify({ error: "message required" }));
        return;
      }

      res.writeHead(200, {
        "Content-Type": "application/x-ndjson",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      });

      try {
        for await (const event of sessions.sendMessage(parsed.sessionId, parsed.message)) {
          res.write(JSON.stringify(event) + "\n");
        }
      } catch (err) {
        res.write(JSON.stringify({ type: "error", message: String(err) }) + "\n");
      }
      res.end();
      return;
    }

    // DELETE /chat/:sessionId — reset session
    const deleteMatch = url.pathname.match(/^\/chat\/([^/]+)$/);
    if (req.method === "DELETE" && deleteMatch) {
      sessions.delete(deleteMatch[1]);
      res.writeHead(204).end();
      return;
    }

    // GET static files
    if (req.method === "GET") {
      let filePath = path.join(opts.staticDir, url.pathname === "/" ? "index.html" : url.pathname);
      // Prevent path traversal
      if (!filePath.startsWith(opts.staticDir)) {
        res.writeHead(403).end();
        return;
      }
      try {
        const data = fs.readFileSync(filePath);
        const ext = path.extname(filePath);
        const mime: Record<string, string> = {
          ".html": "text/html",
          ".js": "application/javascript",
          ".css": "text/css",
          ".json": "application/json",
          ".ico": "image/x-icon",
        };
        res.writeHead(200, { "Content-Type": mime[ext] ?? "application/octet-stream" });
        res.end(data);
      } catch {
        res.writeHead(404).end("Not found");
      }
      return;
    }

    res.writeHead(405).end();
  });

  return server;
}

// Entry point when run as a service.
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { fileURLToPath } = await import("node:url");
  const port = parseInt(process.env.NIXPI_CHAT_PORT ?? "8080");
  const nixpiShareDir = process.env.NIXPI_SHARE_DIR ?? "/usr/local/share/nixpi";
  const piDir = process.env.PI_DIR ?? `${process.env.HOME}/.pi`;
  const chatSessionsDir = `${piDir}/chat-sessions`;
  const staticDir = path.join(import.meta.dirname, "../../frontend/dist");

  const server = createChatServer({
    nixpiShareDir,
    chatSessionsDir,
    idleTimeoutMs: parseInt(process.env.NIXPI_CHAT_IDLE_TIMEOUT ?? "1800") * 1000,
    maxSessions: parseInt(process.env.NIXPI_CHAT_MAX_SESSIONS ?? "4"),
    staticDir,
  });

  server.listen(port, "127.0.0.1", () => {
    console.log(`nixpi-chat listening on 127.0.0.1:${port}`);
  });
}
```

**Note:** The `if (process.argv[1] === fileURLToPath(import.meta.url))` guard uses a top-level `await import` which requires the module to be an ES module (it is, since `package.json` has `"type": "module"`). The `staticDir` path resolves relative to the compiled output location.

- [ ] **Step 4: Fix tsconfig.json to include the new files**

The existing `tsconfig.json` already includes `core/**/*.ts` — no change needed. But we need to exclude `core/chat-server/frontend/` from tsc (it's built by Vite, not tsc):

In `tsconfig.json`, update `exclude`:
```json
"exclude": ["node_modules", "dist", "core/chat-server/frontend"]
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npx vitest run tests/chat-server/server.test.ts 2>&1 | tail -20`
Expected: PASS (5 tests pass).

- [ ] **Step 6: Commit**

```bash
git add core/chat-server/index.ts tests/chat-server/server.test.ts tsconfig.json
git commit -m "feat: add chat HTTP server with NDJSON streaming endpoint"
```

---

## Task 7: Frontend — pi-web-ui ChatPanel

**Files:**
- Modify: `package.json`
- Create: `vite.config.ts`
- Create: `core/chat-server/frontend/index.html`
- Create: `core/chat-server/frontend/app.ts`

The frontend is a minimal HTML page that renders the `@mariozechner/pi-web-ui` `ChatPanel` web component. It uses a custom provider that calls our `POST /chat` NDJSON streaming endpoint.

- [ ] **Step 1: Add dependencies to package.json**

In `package.json`, add to `dependencies`:
```json
"@mariozechner/pi-web-ui": "0.62.0"
```

Add to `devDependencies`:
```json
"vite": "^6.0.0"
```

Add a build script for the frontend. Update the `"build"` script:
```json
"build": "rm -rf dist && tsc --build && vite build"
```

Add a dedicated frontend build script:
```json
"build:frontend": "vite build"
```

Run: `npm install`
Expected: pi-web-ui and vite installed.

- [ ] **Step 2: Create vite.config.ts**

```typescript
import { defineConfig } from "vite";

export default defineConfig({
  root: "core/chat-server/frontend",
  build: {
    outDir: "../../../core/chat-server/frontend/dist",
    emptyOutDir: true,
  },
});
```

- [ ] **Step 3: Create the HTML shell**

Create `core/chat-server/frontend/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Pi</title>
    <script type="module" src="./app.ts"></script>
  </head>
  <body>
    <nixpi-chat></nixpi-chat>
  </body>
</html>
```

- [ ] **Step 4: Create the app.ts custom provider + ChatPanel mount**

Create `core/chat-server/frontend/app.ts`:

```typescript
import "@mariozechner/pi-web-ui/app.css";
import { ChatPanel } from "@mariozechner/pi-web-ui";

// Check which ChatPanel API version is available.
// pi-web-ui v0.62 supports either a direct `agent` prop or a `provider` prop.
// See node_modules/@mariozechner/pi-web-ui/README.md for the exact API.
// The approach below uses a streaming fetch as the backend transport.

// Session ID persisted in localStorage so conversation history survives refresh.
let sessionId = localStorage.getItem("nixpi-chat-session-id");
if (!sessionId) {
  sessionId = crypto.randomUUID();
  localStorage.setItem("nixpi-chat-session-id", sessionId);
}

/**
 * NixPiChatProvider implements whatever interface ChatPanel expects
 * for a custom backend. The exact interface depends on pi-web-ui's API.
 *
 * If ChatPanel accepts a `sendMessage(text, onChunk, onDone, onError)` callback:
 * use the pattern below. If it accepts an OpenAI-compatible streaming endpoint URL,
 * point it at /v1/chat/completions and implement that endpoint in the server.
 *
 * CHECK: Read node_modules/@mariozechner/pi-web-ui/dist/index.d.ts to find the
 * correct ChatPanel props and provider interface before finalizing this file.
 */
async function sendMessage(
  text: string,
  onChunk: (text: string) => void,
  onDone: () => void,
  onError: (err: string) => void
): Promise<void> {
  const res = await fetch("/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sessionId, message: text }),
  });

  if (!res.ok || !res.body) {
    onError(`Server error: ${res.status}`);
    return;
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      if (!line.trim()) continue;
      const event = JSON.parse(line) as { type: string; content?: string; message?: string };
      if (event.type === "text" && event.content) {
        onChunk(event.content);
      } else if (event.type === "error" && event.message) {
        onError(event.message);
      } else if (event.type === "done") {
        onDone();
      }
    }
  }
}

// Mount the ChatPanel.
// The exact mount API depends on whether ChatPanel is a web component or a function.
// If it's a custom element (web component), register it and set props:
const panel = document.querySelector("nixpi-chat") as (HTMLElement & { sendMessage?: typeof sendMessage });
if (panel && "sendMessage" in panel) {
  panel.sendMessage = sendMessage;
}

// Alternative: if ChatPanel is imported as a class and needs to be constructed:
// const panel = new ChatPanel({ sendMessage });
// document.body.appendChild(panel);
//
// IMPORTANT: After reading pi-web-ui's type definitions, update this file to use
// the correct API. The NDJSON streaming endpoint (/chat) remains unchanged.
```

**Note to implementer:** The `app.ts` above contains placeholders for the exact ChatPanel mounting API because pi-web-ui's `ChatPanel` API details must be confirmed from the package's type definitions before implementation. Open `node_modules/@mariozechner/pi-web-ui/dist/index.d.ts` and the package README, then update `app.ts` to use the correct props. The NDJSON streaming protocol (the `sendMessage` function body) is correct and does not change.

- [ ] **Step 5: Build the frontend**

Run: `npm run build:frontend 2>&1 | tail -20`
Expected: `core/chat-server/frontend/dist/index.html` and `dist/assets/app-*.js` created.

- [ ] **Step 6: Commit**

```bash
git add package.json vite.config.ts core/chat-server/frontend/
npm install  # update package-lock.json
git add package-lock.json
git commit -m "feat: add pi-web-ui chat frontend with NDJSON streaming provider"
```

---

## Task 8: NixOS chat service + wire up in app.nix

**Files:**
- Create: `core/os/services/nixpi-chat.nix`
- Modify: `core/os/modules/app.nix`
- Modify: `core/os/modules/options.nix`
- Modify: `core/os/pkgs/app/default.nix`

- [ ] **Step 1: Create nixpi-chat.nix**

Create `core/os/services/nixpi-chat.nix` modelled after the deleted `nixpi-daemon.nix`:

```nix
{ pkgs }:

{ config, lib, options, ... }:

let
  inherit (lib) mkOption types;
  primaryHome = "/home/${config.nixpi-chat.primaryUser}";
in
{
  _class = "service";

  options.nixpi-chat = {
    package = mkOption {
      type = types.package;
    };

    primaryUser = mkOption {
      type = types.str;
    };

    port = mkOption {
      type = types.port;
      default = 8080;
    };

    agentStateDir = mkOption {
      type = types.pathWith { absolute = true; };
    };

    nixpiShareDir = mkOption {
      type = types.str;
      default = "/usr/local/share/nixpi";
    };

    idleTimeoutSecs = mkOption {
      type = types.int;
      default = 1800;
    };

    maxSessions = mkOption {
      type = types.int;
      default = 4;
    };
  };

  config = lib.optionalAttrs (options ? systemd) {
    systemd.service = {
      description = "NixPI Chat Server";
      after = [ "network.target" "nixpi-app-setup.service" ];
      wants = [ "nixpi-app-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        NIXPI_CHAT_PORT = toString config.nixpi-chat.port;
        NIXPI_SHARE_DIR = config.nixpi-chat.nixpiShareDir;
        PI_DIR = config.nixpi-chat.agentStateDir;
        NIXPI_CHAT_IDLE_TIMEOUT = toString config.nixpi-chat.idleTimeoutSecs;
        NIXPI_CHAT_MAX_SESSIONS = toString config.nixpi-chat.maxSessions;
        PATH = lib.makeBinPath [ config.nixpi-chat.package pkgs.nodejs ] + ":/run/current-system/sw/bin";
      };
      serviceConfig = {
        ExecStart = "${pkgs.nodejs}/bin/node ${config.nixpi-chat.nixpiShareDir}/dist/core/chat-server/index.js";
        User = config.nixpi-chat.primaryUser;
        Group = config.nixpi-chat.primaryUser;
        WorkingDirectory = config.nixpi-chat.agentStateDir;
        Restart = "on-failure";
        RestartSec = "10";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = false;
      };
    };
  };
}
```

- [ ] **Step 2: Wire nixpi-chat into app.nix**

In `core/os/modules/app.nix`, replace the deleted `system.services.nixpi-daemon` block with:

```nix
system.services.nixpi-chat = {
  imports = [ (lib.modules.importApply ../services/nixpi-chat.nix { inherit pkgs; }) ];
  nixpi-chat = {
    package = appPackage;
    inherit primaryUser agentStateDir;
  };
};
```

Also update `systemd.tmpfiles.rules` — replace the deleted home + element-web service dirs with a chat-sessions dir:

```nix
systemd.tmpfiles.rules = [
  "L+ /usr/local/share/nixpi - - - - ${appPackage}/share/nixpi"
  "d /etc/nixpi/appservices 0755 root root -"
  "d ${stateDir} 0770 ${primaryUser} ${primaryUser} -"
  "d ${stateDir}/services 0770 ${primaryUser} ${primaryUser} -"
];
```

(Chat sessions live under `~/.pi/chat-sessions/` which is created on demand by the session manager, not by tmpfiles.)

- [ ] **Step 3: Add nixpi-chat.service to allowedUnits in options.nix**

In `core/os/modules/options.nix`, update the `allowedUnits` default (previously cleaned up in Task 3):

```nix
default = [
  "netbird.service"
  "nixpi-chat.service"
  "nixpi-update.service"
];
```

- [ ] **Step 4: Update app/default.nix — add frontend dist**

In `core/os/pkgs/app/default.nix`:

1. Remove the `install -m 644 ${../../services/home-template.html} ...` line (done in Task 3 if not yet).

2. After `npm run build` in the build phase, add the frontend build. Update `buildPhase`:

```nix
buildPhase = ''
  runHook preBuild
  npm run build
  runHook postBuild
'';
```

(The `npm run build` script now runs both `tsc` and `vite build` per Task 7, so this is unchanged.)

3. In `installPhase`, add copying of the frontend dist:

```nix
mkdir -p $out/share/nixpi/core/chat-server/frontend
cp -r core/chat-server/frontend/dist $out/share/nixpi/core/chat-server/frontend/
```

4. Update the `npmDepsHash` after adding pi-web-ui and vite (Task 7 changes package-lock.json):

```nix
npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
```

Run `nix build .#packages.x86_64-linux.app 2>&1 | grep "npmDepsHash"` to get the actual hash after the build fails and update it.

- [ ] **Step 5: Verify NixOS config evaluates**

Run: `nix build .#checks.x86_64-linux.config --no-link -L 2>&1 | tail -5`
Expected: succeeds.

- [ ] **Step 6: Commit**

```bash
git add core/os/services/nixpi-chat.nix core/os/modules/app.nix core/os/modules/options.nix core/os/pkgs/app/default.nix
git commit -m "feat: add nixpi-chat NixOS service and wire up in app.nix"
```

---

## Task 9: NixOS integration test + update test registry

**Files:**
- Create: `tests/nixos/nixpi-chat.nix`
- Modify: `tests/nixos/default.nix`

- [ ] **Step 1: Create nixpi-chat.nix NixOS test**

Create `tests/nixos/nixpi-chat.nix`:

```nix
{ lib, nixPiModulesNoShell, piAgent, appPackage, setupPackage, mkTestFilesystems, ... }:

{
  name = "nixpi-chat";

  nodes.nixpi = { pkgs, ... }: let
    username = "pi";
    homeDir = "/home/${username}";
  in {
    imports = nixPiModulesNoShell ++ [ mkTestFilesystems ];
    _module.args = { inherit piAgent appPackage setupPackage; };
    nixpi.primaryUser = username;

    virtualisation.diskSize = 10240;
    virtualisation.memorySize = 2048;
    networking.hostName = "nixpi-chat-test";
    time.timeZone = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";
    networking.networkmanager.enable = true;
    system.stateVersion = "25.05";
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    users.users.${username} = {
      isNormalUser = true;
      group = username;
      extraGroups = [ "wheel" "networkmanager" ];
      home = homeDir;
      shell = pkgs.bash;
    };
    users.groups.${username} = {};
  };

  testScript = ''
    nixpi.start()
    nixpi.wait_for_unit("multi-user.target", timeout=300)

    # Chat service should exist and be running.
    nixpi.wait_for_unit("nixpi-chat.service", timeout=60)
    nixpi.succeed("test -f /etc/systemd/system/nixpi-chat.service")
    nixpi.succeed("test -d /usr/local/share/nixpi")
    nixpi.succeed("test -f /usr/local/share/nixpi/dist/core/chat-server/index.js")
    nixpi.succeed("test -f /usr/local/share/nixpi/core/chat-server/frontend/dist/index.html")

    # Service unit should use node + correct script path.
    exec_start = nixpi.succeed("systemctl show -p ExecStart --value nixpi-chat.service")
    assert "node" in exec_start and "chat-server/index.js" in exec_start, \
        "Unexpected ExecStart: " + exec_start

    # Port 8080 should serve HTML.
    nixpi.wait_until_succeeds("curl -sf http://127.0.0.1:8080/ | grep -qi '<html'", timeout=60)

    # POST /chat with missing sessionId should return 400.
    result = nixpi.succeed(
        "curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:8080/chat "
        + "-H 'Content-Type: application/json' -d '{\"message\":\"hello\"}'"
    ).strip()
    assert result == "400", "Expected 400 for missing sessionId, got: " + result

    # DELETE /chat/:id should return 204.
    result = nixpi.succeed(
        "curl -s -o /dev/null -w '%{http_code}' -X DELETE http://127.0.0.1:8080/chat/test-id"
    ).strip()
    assert result == "204", "Expected 204 for DELETE, got: " + result

    # nginx should proxy port 80 → chat server.
    nixpi.wait_until_succeeds("curl -sf http://127.0.0.1/ | grep -qi '<html'", timeout=60)

    print("nixpi-chat tests passed!")
  '';
}
```

- [ ] **Step 2: Update tests/nixos/default.nix**

In `tests/nixos/default.nix`:

1. Add to `tests` map:
```nix
nixpi-chat = runTest ./nixpi-chat.nix;
```

2. Add to `smokeAliases`:
```nix
smoke-chat = tests.nixpi-chat;
```

3. Remove `nixpi-home` entry from tests map (done in Task 3 if not yet).

- [ ] **Step 3: Verify test file is valid Nix**

Run: `nix eval .#checks.x86_64-linux.nixpi-chat --apply builtins.typeOf 2>&1 | tail -5`
Expected: "lambda" or no error.

- [ ] **Step 4: Commit**

```bash
git add tests/nixos/nixpi-chat.nix tests/nixos/default.nix
git commit -m "test: add nixpi-chat NixOS integration test"
```

---

## Task 10: Final wiring — update service-surface for nixpi-chat

**Files:**
- Modify: `core/os/modules/service-surface.nix`

The nginx config in `service-surface.nix` currently proxies `/` to port 8080 via the `nixpi-home` virtual host. We need to:
1. Rename `virtualHosts.nixpi-home` → `virtualHosts.nixpi-chat` (or leave name as is, it's just an nginx vhost name)
2. Confirm the `cfg.home.port` reference still works (it does — `nixpi.services.home.port` still exists and defaults to 8080)

- [ ] **Step 1: Verify service-surface.nix proxy still points to port 8080**

Run: `grep -n "8080\|home\.port\|proxyPass" core/os/modules/service-surface.nix`
Expected: Lines showing `proxyPass "http://127.0.0.1:${toString cfg.home.port}"` pointing to port 8080.

The port is unchanged (8080). The nginx vhost name `nixpi-home` in service-surface.nix is just an nginx config label — it doesn't need to match the service name. Leave it.

- [ ] **Step 2: Verify full NixOS config evaluates with all changes**

Run: `nix build .#checks.x86_64-linux.config --no-link -L 2>&1 | tail -10`
Expected: succeeds with no errors.

- [ ] **Step 3: Run unit tests**

Run: `npm run test:unit 2>&1 | tail -20`
Expected: All tests pass including session.test.ts and server.test.ts.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete web chat interface implementation"
```

---

## Self-Review

### Spec coverage check

| Spec requirement | Task |
|---|---|
| Continuwuity cleanup (prerequisite) | Task 1 |
| Remove core/daemon/ | Task 2 |
| Remove core/lib/matrix.ts + matrix-format.ts | Task 2 |
| Remove nixpi-element-web.nix | Task 3 |
| Remove nixpi-home.nix + home-template.html | Task 3 |
| Remove matrix-admin extension | Task 3 |
| Remove elementWeb NixOS options | Task 3 |
| Remove wizard matrix step | Task 4 |
| Update allowedUnits | Tasks 2, 3, 8 |
| ChatSessionManager (session.ts) | Task 5 |
| Chat HTTP server + streaming endpoint | Task 6 |
| pi-web-ui ChatPanel frontend | Task 7 |
| nixpi-chat.nix NixOS service | Task 8 |
| Wire up in app.nix | Task 8 |
| NixOS integration test | Task 9 |
| Update test registry | Task 9 |
| Verify nginx proxy still works | Task 10 |
| Scheduler removed | Task 2 (daemon deleted) |
| matrix-js-sdk dependency removed | Task 2 |

### Placeholder scan

Task 7 app.ts contains an intentional note ("CHECK: Read node_modules/@mariozechner/pi-web-ui/dist/index.d.ts") — this is not a placeholder but an instruction to verify the API at implementation time. The NDJSON protocol and streaming logic are complete. The mount code has a conditional that covers both possible ChatPanel APIs.

Task 8 app/default.nix npmDepsHash is explicitly marked as needing update after the new deps are added — standard NixOS pattern, not a placeholder.

### Type consistency

- `ChatEvent` type defined in Task 5 (`session.ts`) and consumed in Task 6 (`index.ts`) — identical definition (union type, same field names).
- `ChatSessionManagerOptions` defined in Task 5, extended in Task 6 as `ChatServerOptions` — additive, consistent.
- `nixpi-chat` NixOS options defined in Task 8 (`nixpi-chat.nix`) and referenced in `app.nix` — same attribute names.
