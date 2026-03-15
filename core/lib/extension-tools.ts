import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export type RegisteredExtensionTool = Parameters<ExtensionAPI["registerTool"]>[0];

export function defineTool(tool: RegisteredExtensionTool): RegisteredExtensionTool {
	return tool;
}

export function registerTools(pi: ExtensionAPI, tools: readonly RegisteredExtensionTool[]): void {
	for (const tool of tools) {
		pi.registerTool(tool);
	}
}
