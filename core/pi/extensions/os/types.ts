// Extension-specific types for os

/** Update status persisted to the primary NixPI user's ~/.nixpi/update-status.json. */
export interface UpdateStatus {
	available: boolean;
	checked: string;
	generation?: string; // NixOS generation number
	notified?: boolean;
}
