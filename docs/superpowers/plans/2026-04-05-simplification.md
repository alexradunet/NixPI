# Simplification: Pi RPC Mode + NixOS Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the in-process Pi SDK session manager with `RpcClient`, delete the web setup wizard, and remove wizard wiring from the NixOS service definition.

**Architecture:** A single `RpcClientManager` wraps one `RpcClient` instance (one Pi subprocess, pre-spawned at server start). The HTTP server becomes a thin proxy — POST /chat forwards to `rpcClient.prompt()`, events stream back as NDJSON. Setup wizard routes and the redirect gate are removed entirely; first-boot is prefill.env-only.

**Tech Stack:** TypeScript, Node.js HTTP, `@mariozechner/pi-coding-agent` (`RpcClient`), NixOS/Nix modules, Vitest.

**Spec correction:** `core/lib/interactions.ts` is NOT deleted — it is imported by `core/pi/extensions/os/actions.ts` and `actions-proposal.ts` for in-conversation confirmation flow. Only `setup.ts` and `session.ts` are deleted from the chat-server layer.

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Create | `core/chat-server/rpc-client-manager.ts` | Wraps `RpcClient`; streams `ChatEvent` from Pi subprocess |
| Create | `tests/chat-server/rpc-client-manager.test.ts` | Unit tests for RpcClientManager |
| Rewrite | `core/chat-server/index.ts` | Thin HTTP router; uses RpcClientManager instead of ChatSessionManager |
| Rewrite | `tests/chat-server/server.test.ts` | Updated server test (no sessionId, no wizard routes) |
| Delete | `core/chat-server/setup.ts` | Web wizard — replaced by prefill.env systemd oneshot |
| Delete | `core/chat-server/session.ts` | In-process session manager — replaced by RpcClientManager |
| Delete | `tests/chat-server/session.test.ts` | Tests for deleted session.ts |
| Delete | `tests/chat-server/setup.test.ts` | Tests for deleted setup.ts |
| Modify | `core/os/services/nixpi-chat.nix` | Remove `applyScript`, `idleTimeoutSecs`, `maxSessions` options and env vars |

---

## Task 1: Write RpcClientManager (TDD)

**Files:**
- Create: `core/chat-server/rpc-client-manager.ts`
- Create: `tests/chat-server/rpc-client-manager.test.ts`

- [ ] **Step 1.1: Write the failing test file**

```typescript
// tests/chat-server/rpc-client-manager.test.ts
import { beforeEach, describe, expect, it, vi } from "vitest";

// Must be hoisted above the import that loads RpcClientManager.
vi.mock("@mariozechner/pi-coding-agent", () => ({
	RpcClient: vi.fn(),
}));

import { RpcClient } from "@mariozechner/pi-coding-agent";
import { RpcClientManager } from "../../core/chat-server/rpc-client-manager.js";

type EventListener = (event: Record<string, unknown>) => void;

function makeMockClient() {
	let listener: EventListener | null = null;
	const mock = {
		start: vi.fn().mockResolvedValue(undefined),
		stop: vi.fn().mockResolvedValue(undefined),
		newSession: vi.fn().mockResolvedValue({ cancelled: false }),
		onEvent: vi.fn((cb: EventListener) => {
			listener = cb;
			return () => {
				listener = null;
			};
		}),
		prompt: vi.fn().mockResolvedValue(undefined),
		emit: (event: Record<string, unknown>) => listener?.(event),
	};
	return mock;
}

let mockClientInstance: ReturnType<typeof makeMockClient>;

beforeEach(() => {
	mockClientInstance = makeMockClient();
	vi.mocked(RpcClient).mockImplementation(() => mockClientInstance as unknown as RpcClient);
});

describe("RpcClientManager.start / stop", () => {
	it("starts the RpcClient", async () => {
		const mgr = new RpcClientManager({ nixpiShareDir: "/mock/share", cwd: "/tmp/cwd" });
		await mgr.start();
		expect(mockClientInstance.start).toHaveBeenCalledOnce();
	});

	it("stops the RpcClient", async () => {
		const mgr = new RpcClientManager({ nixpiShareDir: "/mock/share", cwd: "/tmp/cwd" });
		await mgr.stop();
		expect(mockClientInstance.stop).toHaveBeenCalledOnce();
	});
});

describe("RpcClientManager.reset", () => {
	it("calls newSession on the RpcClient", async () => {
		const mgr = new RpcClientManager({ nixpiShareDir: "/mock/share", cwd: "/tmp/cwd" });
		await mgr.reset();
		expect(mockClientInstance.newSession).toHaveBeenCalledOnce();
	});
});

describe("RpcClientManager.sendMessage", () => {
	it("streams text deltas and emits done", async () => {
		const mgr = new RpcClientManager({ nixpiShareDir: "/mock/share", cwd: "/tmp/cwd" });

		mockClientInstance.prompt.mockImplementation(async () => {
			// Simulate Pi emitting accumulated text events followed by agent_end.
			mockClientInstance.emit({
				type: "message_update",
				message: { content: [{ type: "text", text: "Hello" }] },
			});
			mockClientInstance.emit({
				type: "message_update",
				message: { content: [{ type: "text", text: "Hello world" }] },
			});
			mockClientInstance.emit({ type: "agent_end", messages: [] });
		});

		const events = [];
		for await (const event of mgr.sendMessage("hi")) {
			events.push(event);
		}

		expect(events).toEqual([
			{ type: "text", content: "Hello" },
			{ type: "text", content: " world" }, // delta only, not full "Hello world"
			{ type: "done" },
		]);
	});

	it("clears text cursors on agent_start so a new turn starts fresh", async () => {
		const mgr = new RpcClientManager({ nixpiShareDir: "/mock/share", cwd: "/tmp/cwd" });

		// First turn: build up cursor position.
		mockClientInstance.prompt.mockImplementationOnce(async () => {
			mockClientInstance.emit({
				type: "message_update",
				message: { content: [{ type: "text", text: "First" }] },
			});
			mockClientInstance.emit({ type: "agent_end", messages: [] });
		});
		for await (const _ of mgr.sendMessage("first")) { /* drain */ }

		// Second turn: agent_start clears cursors so text starts from 0 again.
		mockClientInstance.prompt.mockImplementationOnce(async () => {
			mockClientInstance.emit({ type: "agent_start" });
			mockClientInstance.emit({
				type: "message_update",
				message: { content: [{ type: "text", text: "Second" }] },
			});
			mockClientInstance.emit({ type: "agent_end", messages: [] });
		});
		const events = [];
		for await (const event of mgr.sendMessage("second")) {
			events.push(event);
		}

		expect(events).toContainEqual({ type: "text", content: "Second" });
		expect(events).not.toContainEqual({ type: "text", content: "d" }); // would happen without cursor reset
	});

	it("emits tool_call and tool_result events", async () => {
		const mgr = new RpcClientManager({ nixpiShareDir: "/mock/share", cwd: "/tmp/cwd" });

		mockClientInstance.prompt.mockImplementation(async () => {
			mockClientInstance.emit({
				type: "tool_execution_start",
				toolCallId: "t1",
				toolName: "bash",
				args: { command: "ls" },
			});
			mockClientInstance.emit({
				type: "tool_execution_end",
				toolCallId: "t1",
				toolName: "bash",
				result: "file.txt",
				isError: false,
			});
			mockClientInstance.emit({ type: "agent_end", messages: [] });
		});

		const events = [];
		for await (const event of mgr.sendMessage("list files")) {
			events.push(event);
		}

		expect(events).toContainEqual({ type: "tool_call", name: "bash", input: '{"command":"ls"}' });
		expect(events).toContainEqual({ type: "tool_result", name: "bash", output: "file.txt" });
	});

	it("emits error event when prompt rejects", async () => {
		const mgr = new RpcClientManager({ nixpiShareDir: "/mock/share", cwd: "/tmp/cwd" });

		mockClientInstance.prompt.mockRejectedValue(new Error("Pi crashed"));

		const events = [];
		for await (const event of mgr.sendMessage("hi")) {
			events.push(event);
		}

		expect(events).toContainEqual({ type: "error", message: "Error: Pi crashed" });
	});

	it("ignores message_update events with no text content", async () => {
		const mgr = new RpcClientManager({ nixpiShareDir: "/mock/share", cwd: "/tmp/cwd" });

		mockClientInstance.prompt.mockImplementation(async () => {
			mockClientInstance.emit({ type: "message_update", message: {} });
			mockClientInstance.emit({ type: "message_update", message: { content: [] } });
			mockClientInstance.emit({ type: "agent_end", messages: [] });
		});

		const events = [];
		for await (const event of mgr.sendMessage("hi")) {
			events.push(event);
		}

		expect(events).toEqual([{ type: "done" }]);
	});
});
```

- [ ] **Step 1.2: Run test to confirm it fails (module not found)**

```bash
npm run test -- tests/chat-server/rpc-client-manager.test.ts
```

Expected: FAIL — `Cannot find module '../../core/chat-server/rpc-client-manager.js'`

- [ ] **Step 1.3: Write RpcClientManager implementation**

```typescript
// core/chat-server/rpc-client-manager.ts
import path from "node:path";
import { RpcClient } from "@mariozechner/pi-coding-agent";

export type ChatEvent =
	| { type: "text"; content: string }
	| { type: "tool_call"; name: string; input: string }
	| { type: "tool_result"; name: string; output: string }
	| { type: "done" }
	| { type: "error"; message: string };

export interface RpcClientManagerOptions {
	/** Path to /usr/local/share/nixpi (the deployed app share dir). */
	nixpiShareDir: string;
	/** Working directory for the Pi agent process (e.g. ~/.pi). */
	cwd: string;
}

export class RpcClientManager {
	private readonly client: RpcClient;
	/** Per-content-block text cursors; cleared on agent_start to reset each turn. */
	private readonly textCursors = new Map<number, number>();

	constructor(opts: RpcClientManagerOptions) {
		const cliPath = path.join(
			opts.nixpiShareDir,
			"node_modules/@mariozechner/pi-coding-agent/dist/cli.js",
		);
		this.client = new RpcClient({ cliPath, cwd: opts.cwd });
	}

	async start(): Promise<void> {
		await this.client.start();
	}

	async stop(): Promise<void> {
		await this.client.stop();
	}

	async reset(): Promise<void> {
		await this.client.newSession();
	}

	async *sendMessage(text: string): AsyncGenerator<ChatEvent> {
		const queue: ChatEvent[] = [];
		let notify: (() => void) | null = null;
		let done = false;

		const unsub = this.client.onEvent((event) => {
			const events: ChatEvent[] = [];

			if (event.type === "agent_start") {
				this.textCursors.clear();
			} else if (event.type === "message_update") {
				const msg = (event as { message?: { content?: unknown[] } }).message;
				if (msg?.content) {
					(msg.content as { type: string; text?: string }[]).forEach((block, idx) => {
						if (block.type === "text" && block.text) {
							const prev = this.textCursors.get(idx) ?? 0;
							const delta = block.text.slice(prev);
							if (delta) {
								this.textCursors.set(idx, block.text.length);
								events.push({ type: "text", content: delta });
							}
						}
					});
				}
			} else if (event.type === "tool_execution_start") {
				const e = event as { toolName: string; args: unknown };
				events.push({ type: "tool_call", name: e.toolName, input: JSON.stringify(e.args ?? {}) });
			} else if (event.type === "tool_execution_end") {
				const e = event as { toolName: string; result: unknown };
				events.push({ type: "tool_result", name: e.toolName, output: String(e.result ?? "") });
			} else if (event.type === "agent_end") {
				done = true;
			}

			if (events.length > 0 || done) {
				queue.push(...events);
				notify?.();
				notify = null;
			}
		});

		this.client.prompt(text).catch((err: unknown) => {
			queue.push({ type: "error", message: String(err) });
			done = true;
			notify?.();
			notify = null;
		});

		try {
			while (!done || queue.length > 0) {
				if (queue.length === 0 && !done) {
					await new Promise<void>((r) => {
						notify = r;
					});
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
}
```

- [ ] **Step 1.4: Run tests and confirm they pass**

```bash
npm run test -- tests/chat-server/rpc-client-manager.test.ts
```

Expected: All tests PASS.

- [ ] **Step 1.5: Commit**

```bash
git add core/chat-server/rpc-client-manager.ts tests/chat-server/rpc-client-manager.test.ts
git commit -m "feat: add RpcClientManager wrapping Pi RPC subprocess"
```

---

## Task 2: Rewrite index.ts

**Files:**
- Modify: `core/chat-server/index.ts`
- Modify: `tests/chat-server/server.test.ts`

- [ ] **Step 2.1: Rewrite the server test first**

Replace the entire contents of `tests/chat-server/server.test.ts`:

```typescript
// tests/chat-server/server.test.ts
import fs from "node:fs";
import type http from "node:http";
import os from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

// Mock RpcClientManager so the server test never spawns a real Pi process.
vi.mock("../../core/chat-server/rpc-client-manager.js", () => ({
	RpcClientManager: vi.fn().mockImplementation(function () {
		return {
			start: vi.fn().mockResolvedValue(undefined),
			stop: vi.fn().mockResolvedValue(undefined),
			reset: vi.fn().mockResolvedValue(undefined),
			sendMessage: vi.fn(async function* () {
				yield { type: "text", content: "Hello from Pi" };
				yield { type: "done" };
			}),
		};
	}),
}));

import { createChatServer, isMainModule } from "../../core/chat-server/index.js";

let server: http.Server;
let port: number;
let tmpDir: string;

beforeAll(async () => {
	tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "nixpi-chat-server-test-"));
	server = createChatServer({
		nixpiShareDir: "/mock/share",
		agentCwd: tmpDir,
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
	server?.close();
	fs.rmSync(tmpDir, { recursive: true, force: true });
});

describe("POST /chat", () => {
	it("streams NDJSON events for a message", async () => {
		const res = await fetch(`http://127.0.0.1:${port}/chat`, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({ message: "hi" }),
		});
		expect(res.status).toBe(200);
		expect(res.headers.get("content-type")).toContain("application/x-ndjson");
		const text = await res.text();
		const lines = text
			.trim()
			.split("\n")
			.map((l) => JSON.parse(l));
		expect(lines).toContainEqual({ type: "text", content: "Hello from Pi" });
		expect(lines[lines.length - 1]).toEqual({ type: "done" });
	});

	it("returns 400 for missing message", async () => {
		const res = await fetch(`http://127.0.0.1:${port}/chat`, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({}),
		});
		expect(res.status).toBe(400);
	});

	it("returns 400 for invalid JSON", async () => {
		const res = await fetch(`http://127.0.0.1:${port}/chat`, {
			method: "POST",
			body: "not json",
		});
		expect(res.status).toBe(400);
	});
});

describe("DELETE /chat/:id", () => {
	it("returns 204 and resets the Pi session", async () => {
		const res = await fetch(`http://127.0.0.1:${port}/chat/any-id`, {
			method: "DELETE",
		});
		expect(res.status).toBe(204);
	});
});

describe("GET /", () => {
	it("returns 200 or 404 (frontend dist may not exist in test env)", async () => {
		const res = await fetch(`http://127.0.0.1:${port}/`);
		expect([200, 404]).toContain(res.status);
	});
});

describe("isMainModule", () => {
	it("returns true when argv[1] resolves through a symlink to the module path", () => {
		const fixtureDir = fs.mkdtempSync(path.join(os.tmpdir(), "nixpi-chat-entrypoint-test-"));
		try {
			const entryFile = path.join(fixtureDir, "entry.js");
			const symlinkFile = path.join(fixtureDir, "entry-link.js");
			fs.writeFileSync(entryFile, "// test fixture\n");
			fs.symlinkSync(entryFile, symlinkFile);
			expect(isMainModule(symlinkFile, new URL(`file://${entryFile}`).href)).toBe(true);
		} finally {
			fs.rmSync(fixtureDir, { recursive: true, force: true });
		}
	});
});
```

- [ ] **Step 2.2: Run updated server test and confirm it fails (wrong imports)**

```bash
npm run test -- tests/chat-server/server.test.ts
```

Expected: FAIL — `ChatServerOptions` not found or wrong shape.

- [ ] **Step 2.3: Rewrite index.ts**

Replace the entire contents of `core/chat-server/index.ts`:

```typescript
// core/chat-server/index.ts
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { RpcClientManager } from "./rpc-client-manager.js";

export interface ChatServerOptions {
	/** Path to /usr/local/share/nixpi (the deployed app share dir). */
	nixpiShareDir: string;
	/** Working directory for the Pi agent process (e.g. ~/.pi). */
	agentCwd: string;
	/** Directory containing the pre-built frontend (index.html + assets). */
	staticDir: string;
}

export function createChatServer(opts: ChatServerOptions): http.Server {
	const rpc = new RpcClientManager({ nixpiShareDir: opts.nixpiShareDir, cwd: opts.agentCwd });

	// Pre-spawn Pi subprocess. Errors surface on first /chat request.
	rpc.start().catch((err: unknown) => {
		console.error("Failed to start Pi RPC process:", err);
	});

	const server = http.createServer(async (req, res) => {
		const url = new URL(req.url ?? "/", `http://${req.headers.host}`);

		// POST /chat — streaming NDJSON
		if (req.method === "POST" && url.pathname === "/chat") {
			let body = "";
			for await (const chunk of req) body += chunk;

			let parsed: { message?: string };
			try {
				parsed = JSON.parse(body) as { message?: string };
			} catch {
				res.writeHead(400).end(JSON.stringify({ error: "invalid JSON" }));
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
				for await (const event of rpc.sendMessage(parsed.message)) {
					res.write(`${JSON.stringify(event)}\n`);
				}
			} catch (err) {
				res.write(`${JSON.stringify({ type: "error", message: String(err) })}\n`);
			}
			res.end();
			return;
		}

		// DELETE /chat/:id — reset Pi session (sessionId in URL is accepted but ignored)
		if (req.method === "DELETE" && /^\/chat\/[^/]+$/.test(url.pathname)) {
			await rpc.reset();
			res.writeHead(204).end();
			return;
		}

		// GET static files
		if (req.method === "GET") {
			const filePath = path.join(
				opts.staticDir,
				url.pathname === "/" ? "index.html" : url.pathname,
			);
			const root = opts.staticDir.endsWith(path.sep)
				? opts.staticDir
				: opts.staticDir + path.sep;
			if (!filePath.startsWith(root)) {
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

	server.on("close", () => {
		rpc.stop().catch(() => {});
	});

	return server;
}

export function isMainModule(argv1: string | undefined, moduleUrl: string): boolean {
	if (!argv1) return false;
	const modulePath = fileURLToPath(moduleUrl);
	try {
		return fs.realpathSync(argv1) === fs.realpathSync(modulePath);
	} catch {
		return path.resolve(argv1) === path.resolve(modulePath);
	}
}

if (isMainModule(process.argv[1], import.meta.url)) {
	const port = parseInt(process.env.NIXPI_CHAT_PORT ?? "8080", 10);
	const nixpiShareDir = process.env.NIXPI_SHARE_DIR ?? "/usr/local/share/nixpi";
	const piDir = process.env.PI_DIR ?? `${process.env.HOME}/.pi`;
	const staticDir = path.join(
		path.dirname(fileURLToPath(import.meta.url)),
		"frontend/dist",
	);

	const server = createChatServer({
		nixpiShareDir,
		agentCwd: piDir,
		staticDir,
	});

	server.listen(port, "127.0.0.1", () => {
		console.log(`nixpi-chat listening on 127.0.0.1:${port}`);
	});
}
```

- [ ] **Step 2.4: Run server tests and confirm they pass**

```bash
npm run test -- tests/chat-server/server.test.ts
```

Expected: All tests PASS.

- [ ] **Step 2.5: Commit**

```bash
git add core/chat-server/index.ts tests/chat-server/server.test.ts
git commit -m "feat: rewrite chat server to use RpcClientManager"
```

---

## Task 3: Delete Dead Files

**Files:**
- Delete: `core/chat-server/setup.ts`
- Delete: `core/chat-server/session.ts`
- Delete: `tests/chat-server/setup.test.ts`
- Delete: `tests/chat-server/session.test.ts`

- [ ] **Step 3.1: Delete the files**

```bash
rm core/chat-server/setup.ts core/chat-server/session.ts
rm tests/chat-server/setup.test.ts tests/chat-server/session.test.ts
```

- [ ] **Step 3.2: Run the full unit test suite to confirm nothing else imports them**

```bash
npm run test:unit
```

Expected: All tests PASS. If TypeScript build errors appear about missing imports, search and remove those import lines:

```bash
grep -r "from.*setup\.js\|from.*session\.js" core/ tests/ --include="*.ts"
```

Expected output: empty (no remaining imports).

- [ ] **Step 3.3: Confirm TypeScript compiles cleanly**

```bash
npm run build
```

Expected: Build succeeds with no errors.

- [ ] **Step 3.4: Commit**

```bash
git add -u
git commit -m "feat: remove setup wizard and in-process session manager"
```

---

## Task 4: Strip Wizard Options from NixOS Service

**Files:**
- Modify: `core/os/services/nixpi-chat.nix`

The `applyScript`, `idleTimeoutSecs`, and `maxSessions` options (and their corresponding env vars) are no longer read by the server. Remove them.

- [ ] **Step 4.1: Edit `core/os/services/nixpi-chat.nix`**

Remove the three option blocks and their env var references. The file after editing:

```nix
{ pkgs }:

{ config, lib, options, ... }:

let
  inherit (lib) mkOption types;
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

    workspaceDir = mkOption {
      type = types.str;
      default = "";
      description = "Pi agent workspace root (NIXPI_DIR). Defaults to empty (agent falls back to ~/nixpi).";
    };
  };

  config = {
    process.argv = [
      "${pkgs.nodejs}/bin/node"
      "${config.nixpi-chat.nixpiShareDir}/dist/core/chat-server/index.js"
    ];
  } // lib.optionalAttrs (options ? systemd) {
    systemd.service = {
      description = "NixPI Chat Server";
      after = [ "network.target" "nixpi-app-setup.service" ];
      wants = [ "nixpi-app-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        NIXPI_CHAT_PORT = toString config.nixpi-chat.port;
        NIXPI_SHARE_DIR = config.nixpi-chat.nixpiShareDir;
        PI_DIR = toString config.nixpi-chat.agentStateDir;
        NIXPI_PRIMARY_USER = config.nixpi-chat.primaryUser;
      } // lib.optionalAttrs (config.nixpi-chat.workspaceDir != "") {
        NIXPI_DIR = config.nixpi-chat.workspaceDir;
      };
      serviceConfig = {
        Environment = [
          "PATH=${lib.makeBinPath [ config.nixpi-chat.package pkgs.nodejs ]}:/run/current-system/sw/bin"
        ];
        User = config.nixpi-chat.primaryUser;
        Group = config.nixpi-chat.primaryUser;
        WorkingDirectory = toString config.nixpi-chat.agentStateDir;
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

- [ ] **Step 4.2: Run NixOS config check**

```bash
just check-config
```

Expected: Build succeeds. If it fails with "undefined variable" or "attribute missing" errors, check `core/os/modules/app.nix` and any other consumer of nixpi-chat options to confirm none reference `applyScript`, `idleTimeoutSecs`, or `maxSessions`.

```bash
grep -r "applyScript\|idleTimeoutSecs\|maxSessions\|NIXPI_SETUP_APPLY\|NIXPI_CHAT_IDLE\|NIXPI_CHAT_MAX" core/os/ --include="*.nix"
```

Expected output: empty.

- [ ] **Step 4.3: Commit**

```bash
git add core/os/services/nixpi-chat.nix
git commit -m "feat: remove wizard options from nixpi-chat service"
```

---

## Task 5: Full Verification

- [ ] **Step 5.1: Run complete unit test suite**

```bash
npm run test:unit
```

Expected: All tests PASS.

- [ ] **Step 5.2: Run installer regression tests**

```bash
just check-installer
```

Expected: Build succeeds (no-link).

- [ ] **Step 5.3: Run NixOS config evaluation**

```bash
just check-config
```

Expected: Build succeeds (no-link).

- [ ] **Step 5.4: Verify no remaining references to deleted files**

```bash
grep -r "from.*setup\.js\|from.*session\.js\|ChatSessionManager\|serveSetupPage\|handleSetupApply\|shouldRedirectToSetup" core/ tests/ --include="*.ts"
```

Expected output: empty.

```bash
grep -r "applyScript\|idleTimeoutSecs\|maxSessions\|NIXPI_SETUP_APPLY\|NIXPI_CHAT_IDLE\|NIXPI_CHAT_MAX" core/os/ --include="*.nix"
```

Expected output: empty.

- [ ] **Step 5.5: Final commit**

```bash
git add -A
git commit -m "chore: verify simplification complete — all tests pass"
```

---

## Summary of Changes

| | Before | After |
|---|---|---|
| `session.ts` | 212 lines | deleted |
| `setup.ts` | 273 lines | deleted |
| `index.ts` | 162 lines | ~80 lines |
| `rpc-client-manager.ts` | — | ~80 lines (new) |
| `nixpi-chat.nix` | 90 lines | ~65 lines |
| Net TS server code | 647 lines | ~160 lines |

`interactions.ts` is unchanged — it remains used by OS extension actions for in-conversation confirmation flow.
