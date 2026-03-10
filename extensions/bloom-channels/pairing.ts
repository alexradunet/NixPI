/**
 * Pairing state management for bloom-channels.
 * Shared with the service_pair tool.
 */

const pairingState = new Map<string, string>();

export function getPairingData(channel: string): string | null {
	return pairingState.get(channel) ?? null;
}

export function setPairingData(channel: string, data: string): void {
	pairingState.set(channel, data);
}

export function clearPairingData(channel: string): void {
	pairingState.delete(channel);
}
