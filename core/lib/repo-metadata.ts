import path from "node:path";
import { getPrimaryUser } from "./filesystem.js";

export interface CanonicalRepoMetadata {
	path: string;
	origin: string;
	branch: string;
}

export function getCanonicalRepoMetadataPath(primaryUser = getPrimaryUser()): string {
	return path.join("/home", primaryUser, ".nixpi", "canonical-repo.json");
}
