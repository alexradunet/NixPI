/** Safe filesystem operations: path traversal protection, temp dirs, and home resolution. */
import os from "node:os";
import path from "node:path";
import { safePathWithin } from "./fs-utils.js";

/**
 * Resolve path segments under a root directory, blocking path traversal.
 * Throws if the resolved path escapes the root.
 */
export function safePath(root: string, ...segments: string[]): string {
	return safePathWithin(root, ...segments);
}

/** Resolve the configured app data directory. Checks `WORKSPACE_DIR`, then falls back to `~/Workspace`. */
export function getWorkspaceDir(): string {
	return process.env.WORKSPACE_DIR ?? path.join(os.homedir(), "Workspace");
}

/** Path to the user's Quadlet unit directory for rootless containers. */
export function getQuadletDir(): string {
	return path.join(os.homedir(), ".config", "containers", "systemd");
}

/** Path to the OS update status file written by the update-check timer. */
export function getUpdateStatusPath(): string {
	return path.join(os.homedir(), ".workspace", "update-status.json");
}

/** Path to the local repo clone used for local-only proposal workflows. */
export function getWorkspaceRepoDir(): string {
	return process.env.WORKSPACE_REPO_DIR ?? path.join(os.homedir(), ".workspace", "pi-workspace");
}
