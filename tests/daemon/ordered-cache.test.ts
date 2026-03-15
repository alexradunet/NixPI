import { describe, expect, it } from "vitest";

import { enforceMapLimit, pruneExpiredEntries } from "../../core/daemon/ordered-cache.js";

describe("ordered-cache", () => {
	it("prunes expired entries using the provided timestamp selector", () => {
		const map = new Map([
			["a", 1_000],
			["b", 1_500],
			["c", 2_000],
		]);

		pruneExpiredEntries(map, 2_100, (value) => value, 1_000);

		expect([...map.entries()]).toEqual([
			["b", 1_500],
			["c", 2_000],
		]);
	});

	it("evicts oldest entries first when enforcing a max size", () => {
		const map = new Map([
			["a", 1],
			["b", 2],
			["c", 3],
		]);

		enforceMapLimit(map, 2);

		expect([...map.entries()]).toEqual([
			["b", 2],
			["c", 3],
		]);
	});
});
