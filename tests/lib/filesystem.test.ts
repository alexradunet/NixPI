import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { getWorkspaceDir, safePath } from "../../core/lib/filesystem.js";

const ROOT = path.join(os.tmpdir(), "workspace-fs-test-root");

// ---------------------------------------------------------------------------
// safePath
// ---------------------------------------------------------------------------
describe("safePath", () => {
	it("resolves a valid subpath under the root", () => {
		const result = safePath(ROOT, "Skills", "my-skill");
		expect(result).toBe(path.join(ROOT, "Skills", "my-skill"));
	});

	it("allows a path equal to the root (no segments)", () => {
		const result = safePath(ROOT);
		expect(result).toBe(path.resolve(ROOT));
	});

	it("throws on path traversal with ../", () => {
		expect(() => safePath(ROOT, "../escape")).toThrow("Path traversal blocked");
	});

	it("throws on deep path traversal that escapes root", () => {
		expect(() => safePath(ROOT, "Skills", "../../etc/passwd")).toThrow("Path traversal blocked");
	});

	it("handles nested valid subpath correctly", () => {
		const result = safePath(ROOT, "Objects", "notes", "my-note.md");
		expect(result).toBe(path.join(ROOT, "Objects", "notes", "my-note.md"));
	});
});

// ---------------------------------------------------------------------------
// getWorkspaceDir
// ---------------------------------------------------------------------------
describe("getWorkspaceDir", () => {
	let origBloomDir: string | undefined;

	beforeEach(() => {
		origBloomDir = process.env.WORKSPACE_DIR;
	});

	afterEach(() => {
		if (origBloomDir !== undefined) {
			process.env.WORKSPACE_DIR = origBloomDir;
		} else {
			delete process.env.WORKSPACE_DIR;
		}
	});

	it("returns WORKSPACE_DIR when env var is set", () => {
		process.env.WORKSPACE_DIR = "/custom/workspace";
		expect(getWorkspaceDir()).toBe("/custom/workspace");
	});

	it("falls back to ~/Workspace when env var is not set", () => {
		delete process.env.WORKSPACE_DIR;
		const expected = path.join(os.homedir(), "Workspace");
		expect(getWorkspaceDir()).toBe(expected);
	});

	it("reflects changes to WORKSPACE_DIR dynamically", () => {
		process.env.WORKSPACE_DIR = "/first/path";
		expect(getWorkspaceDir()).toBe("/first/path");

		process.env.WORKSPACE_DIR = "/second/path";
		expect(getWorkspaceDir()).toBe("/second/path");
	});
});
