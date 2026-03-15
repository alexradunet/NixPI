export function pruneExpiredEntries<K, V>(
	map: Map<K, V>,
	now: number,
	getTouchedAt: (value: V) => number,
	ttlMs: number,
): void {
	for (const [key, value] of map) {
		if (now - getTouchedAt(value) > ttlMs) {
			map.delete(key);
		}
	}
}

export function enforceMapLimit<K, V>(map: Map<K, V>, maxEntries: number): void {
	while (map.size > maxEntries) {
		const oldest = map.keys().next().value;
		if (oldest === undefined) break;
		map.delete(oldest);
	}
}
