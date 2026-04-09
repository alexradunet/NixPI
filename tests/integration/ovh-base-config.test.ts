import path from "node:path";
import { describe, expect, it } from "vitest";
import { run } from "../../core/lib/exec.js";

const repoRoot = path.resolve(import.meta.dirname, "../..");

describe("ovh-base host configuration", () => {
	it("evaluates the plain ovh-base install profile", async () => {
		const result = await run(
			"nix",
			[
				"eval",
				"--impure",
				"--json",
				"--expr",
				`let flake = builtins.getFlake (toString ${JSON.stringify(repoRoot)}); config = flake.nixosConfigurations.ovh-base.config; in {
				  hostName = config.networking.hostName;
				  stateVersion = config.system.stateVersion;
				  opensshEnable = config.services.openssh.enable;
				  passwordAuthentication = config.services.openssh.settings.PasswordAuthentication;
				  qemuGuestEnable = config.services.qemuGuest.enable;
				  grubEnable = config.boot.loader.grub.enable;
				  grubEfiSupport = config.boot.loader.grub.efiSupport;
				  grubEfiInstallAsRemovable = config.boot.loader.grub.efiInstallAsRemovable;
				  systemdBootEnable = config.boot.loader.systemd-boot.enable;
				  canTouchEfiVariables = config.boot.loader.efi.canTouchEfiVariables;
				}`,
			],
			undefined,
			repoRoot,
		);

		expect(result.exitCode).toBe(0);
		expect(JSON.parse(result.stdout)).toEqual({
			hostName: "ovh-base",
			stateVersion: "25.05",
			opensshEnable: true,
			passwordAuthentication: false,
			qemuGuestEnable: true,
			grubEnable: true,
			grubEfiSupport: true,
			grubEfiInstallAsRemovable: true,
			systemdBootEnable: false,
			canTouchEfiVariables: false,
		});
	});
});
