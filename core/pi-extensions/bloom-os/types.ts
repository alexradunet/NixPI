// Extension-specific types for bloom-os

/** Update status persisted to /home/pi/.bloom/update-status.json by the bloom-update.service. */
export interface UpdateStatus {
	available: boolean;
	checked: string;
	generation?: string;   // NixOS generation number
	notified?: boolean;
}
