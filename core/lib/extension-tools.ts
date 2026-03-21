import { Type } from "@sinclair/typebox";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export type RegisteredExtensionTool = Parameters<ExtensionAPI["registerTool"]>[0];
export const EmptyToolParams = Type.Object({});

export function defineTool(tool: RegisteredExtensionTool): RegisteredExtensionTool {
	return tool;
}

export function textToolResult(text: string, details: Record<string, unknown> = {}) {
	return {
		content: [{ type: "text" as const, text }],
		details,
	};
}

export function registerTools(pi: ExtensionAPI, tools: readonly RegisteredExtensionTool[]): void {
	for (const tool of tools) {
		pi.registerTool(tool);
	}
}
