import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const repoRoot = path.resolve(import.meta.dirname, "../..");
const moduleSetsPath = path.join(repoRoot, "core/os/modules/module-sets.nix");
const optionsPath = path.join(repoRoot, "core/os/modules/options.nix");
const networkPath = path.join(repoRoot, "core/os/modules/network.nix");
const agentOptionsPath = path.join(repoRoot, "core/os/modules/options/agent.nix");

const ttydModulePath = path.join(repoRoot, "core/os/modules/ttyd.nix");
const serviceSurfaceModulePath = path.join(repoRoot, "core/os/modules/service-surface.nix");

describe("no browser service surface", () => {
	it("removes ttyd and nginx host wiring from the active NixPI module graph", () => {
		expect(existsSync(ttydModulePath)).toBe(false);
		expect(existsSync(serviceSurfaceModulePath)).toBe(false);

		const moduleSets = readFileSync(moduleSetsPath, "utf8");
		expect(moduleSets).not.toContain("./ttyd.nix");
		expect(moduleSets).not.toContain("./service-surface.nix");
	});

	it("drops browser-surface service options and broker allowlist defaults", () => {
		const optionsModule = readFileSync(optionsPath, "utf8");
		expect(optionsModule).not.toContain("services = {");
		expect(optionsModule).not.toContain("secureWeb");
		expect(optionsModule).not.toContain("home = {");
		expect(optionsModule).not.toContain("bindAddress");

		const networkModule = readFileSync(networkPath, "utf8");
		expect(networkModule).not.toContain("cfg = config.nixpi.services");
		expect(networkModule).not.toContain("allowedTCPPorts = exposedPorts");

		const agentOptionsModule = readFileSync(agentOptionsPath, "utf8");
		expect(agentOptionsModule).not.toContain("nixpi-ttyd.service");
	});
});
