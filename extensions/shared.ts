import { createRequire } from "node:module";
import os from "node:os";
import path from "node:path";
import { truncateHead } from "@mariozechner/pi-coding-agent";
import type { FrontMatterResult } from "front-matter";

const require = createRequire(import.meta.url);
const fm: <T>(str: string) => FrontMatterResult<T> = require("front-matter");

export function getGardenDir(): string {
	return process.env._BLOOM_GARDEN_RESOLVED ?? process.env.BLOOM_GARDEN_DIR ?? path.join(os.homedir(), "Garden");
}

export function truncate(text: string): string {
	return truncateHead(text, { maxLines: 2000, maxBytes: 50000 }).content;
}

export function errorResult(message: string) {
	return {
		content: [{ type: "text" as const, text: message }],
		details: {},
		isError: true,
	};
}

export function nowIso(): string {
	return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

export function stringifyFrontmatter(data: Record<string, unknown>, content: string): string {
	const lines: string[] = ["---"];
	for (const [key, val] of Object.entries(data)) {
		if (Array.isArray(val)) {
			lines.push(`${key}: ${val.join(", ")}`);
		} else {
			lines.push(`${key}: ${val}`);
		}
	}
	lines.push("---");
	return `${lines.join("\n")}\n${content}`;
}

export function parseFrontmatter<T>(str: string): FrontMatterResult<T> {
	return fm<T>(str);
}

export const PARA_DIRS = ["Inbox", "Projects", "Areas", "Resources", "Archive"];
