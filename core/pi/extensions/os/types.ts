// Extension-specific types for os

/** Update status persisted to the primary Workspace user's ~/.workspace/update-status.json. */
export interface UpdateStatus {
	available: boolean;
	checked: string;
	generation?: string; // NixOS generation number
	notified?: boolean;
}
