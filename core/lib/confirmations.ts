import fs from "node:fs";
import path from "node:path";
import type { ExtensionContext } from "@mariozechner/pi-coding-agent";

export type ConfirmationStatus = "pending" | "approved" | "denied" | "consumed";

export interface ConfirmationRecord {
	token: string;
	action: string;
	status: ConfirmationStatus;
	createdAt: string;
	updatedAt: string;
}

interface ConfirmationStore {
	records: ConfirmationRecord[];
}

const STORE_SUFFIX = ".bloom-confirmations.json";
const MAX_RECORDS = 32;

function nowIso(): string {
	return new Date().toISOString();
}

function generateToken(): string {
	return Math.random().toString(36).slice(2, 8);
}

function getStorePath(ctx: ExtensionContext): string | null {
	const sessionManager = ctx.sessionManager;
	if (!sessionManager) return null;

	const sessionFile = sessionManager.getSessionFile();
	if (sessionFile) return `${sessionFile}${STORE_SUFFIX}`;

	const sessionDir = sessionManager.getSessionDir();
	const sessionId = sessionManager.getSessionId();
	if (!sessionDir || !sessionId) return null;
	return path.join(sessionDir, `${sessionId}${STORE_SUFFIX}`);
}

function loadStore(storePath: string): ConfirmationStore {
	try {
		const raw = JSON.parse(fs.readFileSync(storePath, "utf-8")) as ConfirmationStore;
		if (!Array.isArray(raw.records)) return { records: [] };
		return { records: raw.records.filter((record) => record && typeof record.action === "string") };
	} catch {
		return { records: [] };
	}
}

function saveStore(storePath: string, store: ConfirmationStore): void {
	fs.mkdirSync(path.dirname(storePath), { recursive: true });
	const trimmed = store.records.slice(-MAX_RECORDS);
	fs.writeFileSync(storePath, JSON.stringify({ records: trimmed }, null, 2));
}

function updateRecord(
	store: ConfirmationStore,
	token: string,
	status: ConfirmationStatus,
): ConfirmationRecord | null {
	const record = store.records.find((entry) => entry.token === token);
	if (!record) return null;
	record.status = status;
	record.updatedAt = nowIso();
	return record;
}

function consumeMatchingAction(store: ConfirmationStore, action: string, status: "approved" | "denied"): boolean {
	const record = [...store.records].reverse().find((entry) => entry.action === action && entry.status === status);
	if (!record) return false;
	record.status = "consumed";
	record.updatedAt = nowIso();
	return true;
}

export function getPendingConfirmations(ctx: ExtensionContext): ConfirmationRecord[] {
	const storePath = getStorePath(ctx);
	if (!storePath) return [];
	return loadStore(storePath).records.filter((entry) => entry.status === "pending");
}

export function ensurePendingConfirmation(ctx: ExtensionContext, action: string): ConfirmationRecord | null {
	const storePath = getStorePath(ctx);
	if (!storePath) return null;

	const store = loadStore(storePath);
	const existing = [...store.records]
		.reverse()
		.find((entry) => entry.action === action && entry.status === "pending");
	if (existing) return existing;

	const ts = nowIso();
	const record: ConfirmationRecord = {
		token: generateToken(),
		action,
		status: "pending",
		createdAt: ts,
		updatedAt: ts,
	};
	store.records.push(record);
	saveStore(storePath, store);
	return record;
}

export function consumeConfirmationDecision(ctx: ExtensionContext, action: string): "approved" | "denied" | null {
	const storePath = getStorePath(ctx);
	if (!storePath) return null;

	const store = loadStore(storePath);
	if (consumeMatchingAction(store, action, "approved")) {
		saveStore(storePath, store);
		return "approved";
	}
	if (consumeMatchingAction(store, action, "denied")) {
		saveStore(storePath, store);
		return "denied";
	}
	return null;
}

export function resolveConfirmationReply(
	ctx: ExtensionContext,
	text: string,
): { status: "approved" | "denied"; record: ConfirmationRecord; ambiguous?: boolean } | null {
	const match = text.trim().match(/^(confirm|approve|yes|deny|decline|no)(?:\s+([a-z0-9]{4,16}))?$/i);
	if (!match) return null;

	const intent = match[1]?.toLowerCase();
	const token = match[2]?.toLowerCase();
	const nextStatus = intent === "deny" || intent === "decline" || intent === "no" ? "denied" : "approved";
	const storePath = getStorePath(ctx);
	if (!storePath) return null;

	const store = loadStore(storePath);
	const pending = store.records.filter((entry) => entry.status === "pending");
	if (pending.length === 0) return null;

	let record: ConfirmationRecord | undefined;
	let ambiguous = false;
	if (token) {
		record = pending.find((entry) => entry.token === token);
	} else if (pending.length === 1) {
		record = pending[0];
	} else {
		record = pending[pending.length - 1];
		ambiguous = true;
	}
	if (!record) return null;

	updateRecord(store, record.token, nextStatus);
	saveStore(storePath, store);
	return { status: nextStatus, record, ...(ambiguous ? { ambiguous: true } : {}) };
}
