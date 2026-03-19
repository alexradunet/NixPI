import { mkdtempSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";

export interface TempGarden {
	gardenDir: string;
	cleanup: () => void;
}

export function createTempGarden(): TempGarden {
	const gardenDir = mkdtempSync(path.join(os.tmpdir(), "garden-test-garden-"));
	const origResolved = process.env._GARDEN_DIR_RESOLVED;
	const origGarden = process.env.GARDEN_DIR;

	process.env._GARDEN_DIR_RESOLVED = gardenDir;
	process.env.GARDEN_DIR = gardenDir;

	return {
		gardenDir,
		cleanup() {
			if (origResolved !== undefined) {
				process.env._GARDEN_DIR_RESOLVED = origResolved;
			} else {
				process.env._GARDEN_DIR_RESOLVED = undefined;
			}
			if (origGarden !== undefined) {
				process.env.GARDEN_DIR = origGarden;
			} else {
				process.env.GARDEN_DIR = undefined;
			}
			rmSync(gardenDir, { recursive: true, force: true });
		},
	};
}
