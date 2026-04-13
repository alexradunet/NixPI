import { existsSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { readUtf8, repoRoot } from "./standards-guard.shared.js";

const pocketbrainHostPath = path.join(repoRoot, "hosts/pocketbrain/nixpi-host.nix");
const pocketbrainHostFlakePath = path.join(repoRoot, "hosts/pocketbrain/flake.nix");
const pocketbrainPrivateExamplePath = path.join(repoRoot, "hosts/pocketbrain/nixpi-host.private.example.nix");
const gitignorePath = path.join(repoRoot, ".gitignore");

describe("private host boundary", () => {
	it("keeps pocketbrain public host config free of private operator data", () => {
		const hostConfig = readUtf8(pocketbrainHostPath);
		const hostFlake = readUtf8(pocketbrainHostFlakePath);
		const gitignore = readUtf8(gitignorePath);

		expect(existsSync(pocketbrainPrivateExamplePath)).toBe(true);
		expect(hostConfig).toContain("nixpi-host.private.nix");
		expect(gitignore).toContain("hosts/pocketbrain/nixpi-host.private.nix");

		expect(hostConfig).not.toContain("hashedPassword");
		expect(hostConfig).not.toContain("openssh.authorizedKeys.keys");
		expect(hostConfig).not.toContain("security.ssh.allowedSourceCIDRs");
		expect(hostConfig).not.toContain("allowedNumbers");
		expect(hostConfig).not.toContain("adminNumbers");
		expect(hostConfig).not.toContain('account = "+');
		expect(hostConfig).not.toContain("wireguard.interfaces.wg0");
		expect(hostFlake).not.toContain("builtins.currentSystem");
	});
});
