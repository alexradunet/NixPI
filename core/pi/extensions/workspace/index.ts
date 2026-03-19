/**
 * workspace — Workspace directory bootstrap, status, and blueprint seeding.
 *
 * @tools workspace_status
 * @commands /workspace (init | status | update-blueprints)
 * @hooks session_start, resources_discover
 * @see {@link ../../AGENTS.md#workspace} Extension reference
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { defineTool, type RegisteredExtensionTool, registerTools } from "../../../lib/extension-tools.js";
import { getWorkspaceDir } from "../../../lib/filesystem.js";
import { discoverSkillPaths, ensureWorkspace, getPackageDir, handleWorkspaceStatus } from "./actions.js";
import { handleUpdateBlueprints, readBlueprintVersions, seedBlueprints } from "./actions-blueprints.js";

type WorkspaceCommandContext = Parameters<Parameters<ExtensionAPI["registerCommand"]>[1]["handler"]>[1];

export default function (pi: ExtensionAPI) {
	const workspaceDir = getWorkspaceDir();
	const packageDir = getPackageDir();
	const tools: RegisteredExtensionTool[] = [
		defineTool({
			name: "workspace_status",
			label: "Workspace Status",
			description: "Show Workspace directory location and blueprint state",
			parameters: Type.Object({}),
			async execute() {
				return handleWorkspaceStatus(workspaceDir);
			},
		}),
	];
	registerTools(pi, tools);

	pi.on("session_start", (_event, ctx) => {
		ensureWorkspace(workspaceDir);
		seedBlueprints(workspaceDir, packageDir);

		const versions = readBlueprintVersions(workspaceDir);
		const updates = Object.keys(versions.updatesAvailable);
		if (ctx.hasUI) {
			if (updates.length > 0) {
				ctx.ui.setWidget("workspace-updates", [
					`${updates.length} blueprint update(s) available — /workspace update-blueprints`,
				]);
			}
			ctx.ui.setStatus("workspace", `Workspace: ${workspaceDir}`);
		}
	});

	pi.registerCommand("workspace", {
		description: "Workspace directory management: /workspace init | status | update-blueprints",
		handler: async (args: string, ctx) => handleWorkspaceCommand(pi, workspaceDir, packageDir, args, ctx),
	});

	pi.on("resources_discover", () => {
		const paths = discoverSkillPaths(workspaceDir);
		if (paths) return { skillPaths: paths };
	});
}

async function handleWorkspaceCommand(
	pi: ExtensionAPI,
	workspaceDir: string,
	packageDir: string,
	args: string,
	ctx: WorkspaceCommandContext,
): Promise<void> {
	const subcommand = args.trim().split(/\s+/)[0] ?? "";
	if (!subcommand) {
		ctx.ui.notify("Usage: /workspace init | status | update-blueprints", "info");
		return;
	}

	switch (subcommand) {
		case "init":
			ensureWorkspace(workspaceDir);
			seedBlueprints(workspaceDir, packageDir);
			ctx.ui.notify("Workspace initialized", "info");
			return;
		case "status":
			pi.sendUserMessage("Show workspace status using the workspace_status tool.", { deliverAs: "followUp" });
			return;
		case "update-blueprints": {
			const count = handleUpdateBlueprints(workspaceDir, packageDir);
			ctx.ui.notify(count === 0 ? "All blueprints are up to date" : `Updated ${count} blueprint(s)`, "info");
			return;
		}
		default:
			ctx.ui.notify("Usage: /workspace init | status | update-blueprints", "info");
	}
}
