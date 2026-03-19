import { describe, expect, it } from "vitest";
import { sanitizeRoomAlias } from "../../core/lib/room-alias.js";

describe("sanitizeRoomAlias", () => {
	it("strips # prefix and replaces : with _", () => {
		expect(sanitizeRoomAlias("#general:localhost")).toBe("general_localhost");
	});

	it("strips ! prefix for room IDs", () => {
		expect(sanitizeRoomAlias("!abc123:localhost")).toBe("abc123_localhost");
	});

	it("handles alias with subdomain", () => {
		expect(sanitizeRoomAlias("#dev:workspace")).toBe("dev_workspace");
	});

	it("passes through already-clean strings", () => {
		expect(sanitizeRoomAlias("general_workspace")).toBe("general_workspace");
	});
});
