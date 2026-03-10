/** Extension-specific types for bloom-display. */

/** Sway tree node shape (subset of swaymsg -t get_tree output). */
export interface SwayNode {
	id: number;
	name: string | null;
	type: string;
	focused: boolean;
	nodes?: SwayNode[];
	floating_nodes?: SwayNode[];
}
