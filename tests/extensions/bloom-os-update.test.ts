import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createMockExtensionContext } from "../helpers/mock-extension-context.js";

const runMock = vi.fn();

vi.mock("../../core/lib/exec.js", () => ({
	run: (...args: unknown[]) => runMock(...args),
}));

describe("bloom-os nixos_update handler", () => {
	let repoDir: string;
	const originalRepoDir = process.env.BLOOM_REPO_DIR;

	beforeEach(() => {
		vi.resetModules();
		runMock.mockReset();
		repoDir = fs.mkdtempSync(path.join(os.tmpdir(), "bloom-switch-"));
		process.env.BLOOM_REPO_DIR = repoDir;
	});

	afterEach(() => {
		if (originalRepoDir === undefined) {
			delete process.env.BLOOM_REPO_DIR;
		} else {
			process.env.BLOOM_REPO_DIR = originalRepoDir;
		}
		fs.rmSync(repoDir, { recursive: true, force: true });
	});

	it("applies the remote flake by default", async () => {
		runMock.mockResolvedValueOnce({ stdout: "ok\n", stderr: "", exitCode: 0 });

		const { handleNixosUpdate } = await import("../../core/pi-extensions/bloom-os/actions.js");
		const ctx = createMockExtensionContext({ hasUI: true });
		const result = await handleNixosUpdate("apply", "remote", undefined, ctx as never);

		expect(ctx.ui.confirm).toHaveBeenCalled();
		expect(runMock).toHaveBeenCalledWith(
			"sudo",
			["nixos-rebuild", "switch", "--flake", "github:alexradunet/piBloom#bloom-x86_64"],
			undefined,
		);
		expect(result.isError).toBe(false);
		expect(result.content[0].text).toContain("from remote source");
	});

	it("applies the reviewed local clone when source=local", async () => {
		runMock.mockResolvedValueOnce({ stdout: "ok\n", stderr: "", exitCode: 0 });

		const { handleNixosUpdate } = await import("../../core/pi-extensions/bloom-os/actions.js");
		const ctx = createMockExtensionContext({ hasUI: true });
		const result = await handleNixosUpdate("apply", "local", undefined, ctx as never);

		expect(runMock).toHaveBeenCalledWith(
			"sudo",
			["nixos-rebuild", "switch", "--flake", `${repoDir}#bloom-x86_64`],
			undefined,
		);
		expect(result.isError).toBe(false);
		expect(result.content[0].text).toContain("from local source");
	});

	it("fails early if the local repo is missing", async () => {
		fs.rmSync(repoDir, { recursive: true, force: true });

		const { handleNixosUpdate } = await import("../../core/pi-extensions/bloom-os/actions.js");
		const ctx = createMockExtensionContext({ hasUI: true });
		const result = await handleNixosUpdate("apply", "local", undefined, ctx as never);

		expect(runMock).not.toHaveBeenCalled();
		expect(result.isError).toBe(true);
		expect(result.content[0].text).toContain("Local Bloom repo not found");
	});
});
