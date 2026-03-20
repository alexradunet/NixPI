import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
	ensureNixPi,
	getPackageDir,
	handleAgentCreate,
	handleNixPiStatus,
	handleMentionAgent,
	handleSkillCreate,
	handleSkillList,
	loadAgentInfos,
} from "../../core/pi/extensions/nixpi/actions.js";
import { createMockExtensionAPI } from "../helpers/mock-extension-api.js";
import { createMockExtensionContext } from "../helpers/mock-extension-context.js";
import { createTempNixPi, type TempNixPi } from "../helpers/temp-nixpi.js";

let nixPiDir: string;

beforeEach(() => {
	nixPiDir = fs.mkdtempSync(path.join(os.tmpdir(), "nixpi-test-"));
});

afterEach(() => {
	fs.rmSync(nixPiDir, { recursive: true, force: true });
});

// ---------------------------------------------------------------------------
// ensureNixPi
// ---------------------------------------------------------------------------
describe("ensureNixPi", () => {
	it("creates all required subdirectories", () => {
		ensureNixPi(nixPiDir);
		for (const dir of ["Persona", "Skills", "Evolutions", "audit"]) {
			expect(fs.existsSync(path.join(nixPiDir, dir))).toBe(true);
		}
	});

	it("is idempotent — calling twice does not throw", () => {
		ensureNixPi(nixPiDir);
		expect(() => ensureNixPi(nixPiDir)).not.toThrow();
	});
});

describe("nixpi extension", () => {
	it("does not register authoring tools in the default runtime surface", async () => {
		vi.resetModules();
		const api = createMockExtensionAPI();
		const mod = await import("../../core/pi/extensions/nixpi/index.js");
		mod.default(api as never);

		const names = api._registeredTools.map((tool) => tool.name);
		expect(names).toEqual(["nixpi_status"]);
		expect(api._eventHandlers.has("input")).toBe(false);
	});

	it("shows usage for /nixpi without arguments instead of opening an interaction prompt", async () => {
		vi.resetModules();
		const api = createMockExtensionAPI();
		const mod = await import("../../core/pi/extensions/nixpi/index.js");
		mod.default(api as never);

		const ctx = createMockExtensionContext({ hasUI: true });
		const command = api._registeredCommands.find((entry) => entry.name === "nixpi") as unknown as {
			handler: (args: string, ctx: ReturnType<typeof createMockExtensionContext>) => Promise<void>;
		};

		await command.handler("", ctx);

		expect(api._sentCustomMessages).toEqual([]);
		expect(ctx.ui.notify).toHaveBeenCalledWith("Usage: /nixpi init | status | update-blueprints", "info");
	});
});

// ---------------------------------------------------------------------------
// getPackageDir
// ---------------------------------------------------------------------------
describe("getPackageDir", () => {
	it("returns a non-empty string", () => {
		const dir = getPackageDir();
		expect(typeof dir).toBe("string");
		expect(dir.length).toBeGreaterThan(0);
	});

	it("returns a path that exists", () => {
		const dir = getPackageDir();
		expect(fs.existsSync(dir)).toBe(true);
	});
});

// ---------------------------------------------------------------------------
// handleNixPiStatus
// ---------------------------------------------------------------------------
describe("handleNixPiStatus", () => {
	it("returns content containing the NixPI dir path", () => {
		ensureNixPi(nixPiDir);
		const result = handleNixPiStatus(nixPiDir);
		expect(result.content).toHaveLength(1);
		expect(result.content[0].type).toBe("text");
		expect(result.content[0].text).toContain(nixPiDir);
	});

	it("returns a details object", () => {
		ensureNixPi(nixPiDir);
		const result = handleNixPiStatus(nixPiDir);
		expect(result.details).toBeDefined();
	});

	it("shows package version line", () => {
		ensureNixPi(nixPiDir);
		const result = handleNixPiStatus(nixPiDir);
		expect(result.content[0].text).toContain("Package version:");
	});
});

// ---------------------------------------------------------------------------
// handleSkillCreate
// ---------------------------------------------------------------------------
describe("handleSkillCreate", () => {
	beforeEach(() => {
		ensureNixPi(nixPiDir);
	});

	it("creates a SKILL.md file at the expected path", () => {
		const result = handleSkillCreate(nixPiDir, {
			name: "my-skill",
			description: "A test skill",
			content: "# My Skill\n\nDo things.",
		});
		expect(result.content[0].text).toContain("created skill: my-skill");
		const skillFile = path.join(nixPiDir, "Skills", "my-skill", "SKILL.md");
		expect(fs.existsSync(skillFile)).toBe(true);
	});

	it("writes name and description into the frontmatter", () => {
		handleSkillCreate(nixPiDir, {
			name: "scoped-skill",
			description: "Scoped description",
			content: "Body text",
		});
		const raw = fs.readFileSync(path.join(nixPiDir, "Skills", "scoped-skill", "SKILL.md"), "utf-8");
		expect(raw).toContain("name: scoped-skill");
		expect(raw).toContain("description: Scoped description");
		expect(raw).toContain("Body text");
	});

	it("returns an error result when the skill already exists", () => {
		handleSkillCreate(nixPiDir, { name: "dup-skill", description: "first", content: "" });
		const result = handleSkillCreate(nixPiDir, { name: "dup-skill", description: "second", content: "" });
		expect(result.content[0].text).toContain("already exists");
	});

	it("blocks path traversal in skill name that escapes NixPI dir", () => {
		const result = handleSkillCreate(nixPiDir, { name: "../../escape", description: "bad", content: "" });
		expect(result.content[0].text).toContain("Path traversal blocked");
	});
});

// ---------------------------------------------------------------------------
// handleAgentCreate
// ---------------------------------------------------------------------------
describe("handleAgentCreate", () => {
	beforeEach(() => {
		ensureNixPi(nixPiDir);
	});

	it("creates agent credentials and a starter AGENTS.md", async () => {
		const restartDaemon = vi.fn().mockResolvedValue({ ok: true });
		const result = await handleAgentCreate(
			nixPiDir,
			{
				id: "planner",
				name: "Planner",
				description: "Breaks problems into steps.",
				role_prompt: "Focus on decomposition and sequencing.",
				model: "anthropic/claude-sonnet-4-5",
				thinking: "medium",
				respond_mode: "mentioned",
			},
			{
				homeDir: nixPiDir,
				loadPrimaryMatrixConfig: () => ({
					homeserver: "http://localhost:6167",
					registrationToken: "reg-token",
				}),
				restartDaemon,
				provision: async () => ({
					ok: true,
					credentials: {
						homeserver: "http://localhost:6167",
						userId: "@planner:nixpi",
						accessToken: "planner-token",
						password: "secret-pass",
						username: "planner",
					},
				}),
			},
		);

		expect(result.content[0].text).toContain("created agent: planner");
		expect(fs.existsSync(path.join(nixPiDir, ".pi", "matrix-agents", "planner.json"))).toBe(true);
		expect(fs.existsSync(path.join(nixPiDir, "Agents", "planner", "AGENTS.md"))).toBe(true);
		const raw = fs.readFileSync(path.join(nixPiDir, "Agents", "planner", "AGENTS.md"), "utf-8");
		expect(raw).toContain("id: planner");
		expect(raw).toContain("name: Planner");
		expect(raw).toContain("username: planner");
		expect(raw).not.toContain("Optional proactive jobs example");
		expect(raw).not.toContain("HEARTBEAT_OK");
		expect(result.content[0].text).toContain("nixpi-daemon restarted");
		expect(result.details).toEqual(expect.objectContaining({ daemonRestarted: true }));
		expect(restartDaemon).toHaveBeenCalledTimes(1);
	});

	it("defaults username to the agent id", async () => {
		const provision = vi.fn().mockResolvedValue({
			ok: true,
			credentials: {
				homeserver: "http://localhost:6167",
				userId: "@critic:nixpi",
				accessToken: "critic-token",
				password: "secret-pass",
				username: "critic",
			},
		});

		await handleAgentCreate(
			nixPiDir,
			{
				id: "critic",
				name: "Critic",
				description: "Challenges plans.",
				role_prompt: "Look for flaws and missing assumptions.",
			},
			{
				homeDir: nixPiDir,
				loadPrimaryMatrixConfig: () => ({
					homeserver: "http://localhost:6167",
					registrationToken: "reg-token",
				}),
				provision,
			},
		);

		expect(provision).toHaveBeenCalledWith(
			expect.objectContaining({ username: "critic", homeserver: "http://localhost:6167" }),
		);
	});

	it("returns success with a warning when nixpi-daemon restart fails", async () => {
		const result = await handleAgentCreate(
			nixPiDir,
			{
				id: "cashus",
				name: "Cashus",
				description: "Financial guidance.",
				role_prompt: "Provide financial guidance.",
			},
			{
				homeDir: nixPiDir,
				loadPrimaryMatrixConfig: () => ({
					homeserver: "http://localhost:6167",
					registrationToken: "reg-token",
				}),
				restartDaemon: async () => ({ ok: false, error: "restart failed" }),
				provision: async () => ({
					ok: true,
					credentials: {
						homeserver: "http://localhost:6167",
						userId: "@cashus:nixpi",
						accessToken: "cashus-token",
						password: "secret-pass",
						username: "cashus",
					},
				}),
			},
		);

		expect(result.content[0].text).toContain("created agent: cashus");
		expect(result.content[0].text).toContain("Warning: agent was created");
		expect(result.details).toEqual(
			expect.objectContaining({ daemonRestarted: false, daemonRestartError: "restart failed" }),
		);
	});

	it("returns an error if the agent already exists", async () => {
		await handleAgentCreate(
			nixPiDir,
			{
				id: "planner",
				name: "Planner",
				description: "Breaks problems into steps.",
				role_prompt: "Focus on decomposition and sequencing.",
			},
			{
				homeDir: nixPiDir,
				loadPrimaryMatrixConfig: () => ({
					homeserver: "http://localhost:6167",
					registrationToken: "reg-token",
				}),
				provision: async () => ({
					ok: true,
					credentials: {
						homeserver: "http://localhost:6167",
						userId: "@planner:nixpi",
						accessToken: "planner-token",
						password: "secret-pass",
						username: "planner",
					},
				}),
			},
		);

		const result = await handleAgentCreate(
			nixPiDir,
			{
				id: "planner",
				name: "Planner",
				description: "Breaks problems into steps.",
				role_prompt: "Focus on decomposition and sequencing.",
			},
			{
				homeDir: nixPiDir,
				loadPrimaryMatrixConfig: () => ({
					homeserver: "http://localhost:6167",
					registrationToken: "reg-token",
				}),
				provision: async () => ({
					ok: true,
					credentials: {
						homeserver: "http://localhost:6167",
						userId: "@planner:nixpi",
						accessToken: "planner-token",
						password: "secret-pass",
						username: "planner",
					},
				}),
			},
		);

		expect(result.content[0].text).toContain("agent already exists");
	});

	it("rejects invalid agent ids", async () => {
		const result = await handleAgentCreate(
			nixPiDir,
			{
				id: "../../evil",
				name: "Evil",
				description: "Nope.",
				role_prompt: "Nope.",
			},
			{
				homeDir: nixPiDir,
				loadPrimaryMatrixConfig: () => ({
					homeserver: "http://localhost:6167",
					registrationToken: "reg-token",
				}),
				provision: async () => ({ ok: false, error: "should not be called" }),
			},
		);

		expect(result.content[0].text).toContain("invalid agent id");
	});
});

// ---------------------------------------------------------------------------
// handleSkillList
// ---------------------------------------------------------------------------
describe("handleSkillList", () => {
	it("returns message when Skills directory does not exist", () => {
		// nixPiDir exists but Skills subdir has not been created
		const result = handleSkillList(nixPiDir);
		expect(result.content[0].text).toContain("No skills directory found");
	});

	it("returns message when Skills directory is empty", () => {
		fs.mkdirSync(path.join(nixPiDir, "Skills"), { recursive: true });
		const result = handleSkillList(nixPiDir);
		expect(result.content[0].text).toContain("No skills found");
	});

	it("lists skills with their descriptions", () => {
		ensureNixPi(nixPiDir);
		handleSkillCreate(nixPiDir, { name: "alpha", description: "Alpha skill", content: "" });
		handleSkillCreate(nixPiDir, { name: "beta", description: "Beta skill", content: "" });

		const result = handleSkillList(nixPiDir);
		expect(result.content[0].text).toContain("alpha");
		expect(result.content[0].text).toContain("Alpha skill");
		expect(result.content[0].text).toContain("beta");
		expect(result.content[0].text).toContain("Beta skill");
	});

	it("ignores entries without a SKILL.md file", () => {
		ensureNixPi(nixPiDir);
		// Create a directory without a SKILL.md
		fs.mkdirSync(path.join(nixPiDir, "Skills", "orphan"), { recursive: true });
		const result = handleSkillList(nixPiDir);
		expect(result.content[0].text).toContain("No skills found");
	});
});

// ---------------------------------------------------------------------------
// loadAgentInfos
// ---------------------------------------------------------------------------
describe("loadAgentInfos", () => {
	it("returns empty array when Agents directory does not exist", () => {
		const agents = loadAgentInfos(nixPiDir);
		expect(agents).toEqual([]);
	});

	it("parses agent definitions from AGENTS.md files", () => {
		ensureNixPi(nixPiDir);
		const agentDir = path.join(nixPiDir, "Agents", "cookie");
		fs.mkdirSync(agentDir, { recursive: true });
		fs.writeFileSync(
			path.join(agentDir, "AGENTS.md"),
			`---
id: cookie
name: Cookie
matrix:
  username: cookie
description: Memory manager
---

# Cookie

I manage memories.
`,
		);

		const agents = loadAgentInfos(nixPiDir);
		expect(agents).toHaveLength(1);
		expect(agents[0]).toMatchObject({
			id: "cookie",
			name: "Cookie",
			userId: expect.stringContaining("@cookie:"),
			description: "Memory manager",
		});
	});

	it("skips malformed agent files", () => {
		ensureNixPi(nixPiDir);
		const agentDir = path.join(nixPiDir, "Agents", "bad");
		fs.mkdirSync(agentDir, { recursive: true });
		fs.writeFileSync(path.join(agentDir, "AGENTS.md"), "not valid frontmatter");

		const agents = loadAgentInfos(nixPiDir);
		expect(agents).toEqual([]);
	});
});

// ---------------------------------------------------------------------------
// handleMentionAgent
// ---------------------------------------------------------------------------
describe("handleMentionAgent", () => {
	beforeEach(() => {
		ensureNixPi(nixPiDir);
	});

	it("formats a message with the agent's Matrix User ID", () => {
		// Setup: create an agent
		const agentDir = path.join(nixPiDir, "Agents", "cookie");
		fs.mkdirSync(agentDir, { recursive: true });
		fs.writeFileSync(
			path.join(agentDir, "AGENTS.md"),
			`---
id: cookie
name: Cookie
matrix:
  username: cookie
description: Memory manager
---
`,
		);

		const result = handleMentionAgent(nixPiDir, {
			agent_id: "cookie",
			message: "Please remember that I prefer dark mode",
		});

		expect(result.content[0].text).toBe("@cookie:nixpi Please remember that I prefer dark mode");
		expect(result.details).toMatchObject({
			agentId: "cookie",
			agentName: "Cookie",
			userId: "@cookie:nixpi",
		});
	});

	it("returns error for unknown agent with available agents list", () => {
		// Setup: create one agent
		const agentDir = path.join(nixPiDir, "Agents", "planner");
		fs.mkdirSync(agentDir, { recursive: true });
		fs.writeFileSync(
			path.join(agentDir, "AGENTS.md"),
			`---
id: planner
name: Planner
matrix:
  username: planner
description: Planning assistant
---
`,
		);

		const result = handleMentionAgent(nixPiDir, {
			agent_id: "unknown",
			message: "Hello",
		});

		expect(result.content[0].text).toContain("Unknown agent: unknown");
		expect(result.content[0].text).toContain("planner");
		expect(result.content[0].text).toContain("Planner");
	});

	it("returns error when no agents exist", () => {
		const result = handleMentionAgent(nixPiDir, {
			agent_id: "anyone",
			message: "Hello",
		});

		expect(result.content[0].text).toContain("Unknown agent: anyone");
		expect(result.content[0].text).toContain("(none)");
	});
});

// ---------------------------------------------------------------------------
// workspace_status tool execute (via registered extension)
// ---------------------------------------------------------------------------

type NixPiStatusResult = { content: Array<{ type: string; text: string }>; details: unknown };
type NixPiStatusExecute = () => Promise<NixPiStatusResult>;

describe("nixpi_status tool execute", () => {
	let temp: TempNixPi;
	let api: ReturnType<typeof createMockExtensionAPI>;

	beforeEach(async () => {
		temp = createTempNixPi();
		vi.resetModules();
		api = createMockExtensionAPI();
		const mod = await import("../../core/pi/extensions/nixpi/index.js");
		mod.default(api as never);
	});

	afterEach(() => {
		temp.cleanup();
	});

	function getNixPiStatusExecute(): NixPiStatusExecute {
		const tool = api._registeredTools.find((t) => t.name === "nixpi_status");
		if (!tool) throw new Error("nixpi_status tool not found");
		return tool.execute as NixPiStatusExecute;
	}

	it("returns a result with content array containing a text item", async () => {
		expect(api._registeredTools.find((t) => t.name === "nixpi_status")).toBeDefined();
		const result = await getNixPiStatusExecute()();
		expect(result).toHaveProperty("content");
		expect(Array.isArray(result.content)).toBe(true);
		expect(result.content[0]).toHaveProperty("type", "text");
	});

	it("includes the NixPI dir path in the status text", async () => {
		const result = await getNixPiStatusExecute()();
		expect(result.content[0].text).toContain(temp.nixPiDir);
	});

	it("includes package version line in the status text", async () => {
		const result = await getNixPiStatusExecute()();
		expect(result.content[0].text).toContain("Package version:");
	});

	it("includes seeded blueprints count in the status text", async () => {
		const result = await getNixPiStatusExecute()();
		expect(result.content[0].text).toContain("Seeded blueprints:");
	});
});

// ---------------------------------------------------------------------------
// /nixpi command handler subcommands
// ---------------------------------------------------------------------------
describe("/nixpi command handler", () => {
	let temp: TempNixPi;
	let api: ReturnType<typeof createMockExtensionAPI>;

	beforeEach(async () => {
		temp = createTempNixPi();
		vi.resetModules();
		api = createMockExtensionAPI();
		const mod = await import("../../core/pi/extensions/nixpi/index.js");
		mod.default(api as never);
	});

	afterEach(() => {
		temp.cleanup();
	});

	function getCommandHandler() {
		const entry = api._registeredCommands.find((c) => c.name === "nixpi");
		if (!entry) throw new Error("nixpi command not registered");
		return entry.handler as (args: string, ctx: ReturnType<typeof createMockExtensionContext>) => Promise<void>;
	}

	it("registers the /nixpi command", () => {
		const entry = api._registeredCommands.find((c) => c.name === "nixpi");
		expect(entry).toBeDefined();
	});

	it("status subcommand sends a user message via pi.sendUserMessage", async () => {
		const handler = getCommandHandler();
		const ctx = createMockExtensionContext({ hasUI: true });
		await handler("status", ctx);
		expect(api._sentMessages).toHaveLength(1);
		expect(api._sentMessages[0].message).toContain("nixpi_status");
	});

	it("init subcommand notifies with NixPI initialized", async () => {
		const handler = getCommandHandler();
		const ctx = createMockExtensionContext({ hasUI: true });
		await handler("init", ctx);
		expect(ctx.ui.notify).toHaveBeenCalledWith("NixPI initialized", "info");
	});

	it("init subcommand creates NixPI subdirectories", async () => {
		const handler = getCommandHandler();
		const ctx = createMockExtensionContext({ hasUI: true });
		await handler("init", ctx);
		for (const dir of ["Persona", "Skills", "Evolutions", "Objects", "Episodes", "Agents", "audit"]) {
			expect(fs.existsSync(path.join(temp.nixPiDir, dir))).toBe(true);
		}
	});

	it("update-blueprints subcommand notifies when blueprints are up to date", async () => {
		const handler = getCommandHandler();
		const ctx = createMockExtensionContext({ hasUI: true });
		await handler("update-blueprints", ctx);
		expect(ctx.ui.notify).toHaveBeenCalledWith(
			expect.stringMatching(/All blueprints are up to date|Updated \d+ blueprint/),
			"info",
		);
	});

	it("unknown subcommand shows usage hint", async () => {
		const handler = getCommandHandler();
		const ctx = createMockExtensionContext({ hasUI: true });
		await handler("unknown-cmd", ctx);
		expect(ctx.ui.notify).toHaveBeenCalledWith("Usage: /nixpi init | status | update-blueprints", "info");
	});
});
