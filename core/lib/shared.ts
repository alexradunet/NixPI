/** Shared utilities: text truncation, error formatting, and service-name guards. */
import fs from "node:fs";
import path from "node:path";
import type { ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateHead } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { Value } from "@sinclair/typebox/value";

/** Truncate text to 2000 lines / 50KB using Pi's truncateHead utility. */
export function truncate(text: string): string {
	return truncateHead(text, { maxLines: 2000, maxBytes: 50000 }).content;
}

/** Build a standardized Pi tool error response. */
export function errorResult(message: string) {
	return {
		content: [{ type: "text" as const, text: message }],
		details: {},
		isError: true,
	};
}

/** Prompt the user for confirmation via UI. Returns null if confirmed, error message if declined or no UI. */
export async function requireConfirmation(
	ctx: ExtensionContext,
	action: string,
	options?: { requireUi?: boolean },
): Promise<string | null> {
	const requireUi = options?.requireUi ?? true;
	if (!ctx.hasUI) {
		if (!requireUi) return null;
		const interaction = requestInteraction(ctx, {
			kind: "confirm",
			key: action,
			prompt: `Allow: ${action}?`,
		});
		if (!interaction) {
			return `Cannot perform "${action}" without interactive user confirmation.`;
		}
		if (interaction.state === "resolved") {
			return interaction.value === "approved" ? null : `User declined: ${action}`;
		}
		return interaction.prompt;
	}
	const confirmed = await ctx.ui.confirm("Confirm action", `Allow: ${action}?`);
	if (!confirmed) return `User declined: ${action}`;
	return null;
}

export async function requestSelection(
	ctx: ExtensionContext,
	key: string,
	title: string,
	options: string[],
	config?: { resumeMessage?: string },
): Promise<{ value: string | null; prompt?: string }> {
	if (ctx.hasUI) {
		const selected = await ctx.ui.select(title, options);
		return { value: selected ?? null };
	}

	const interaction = requestInteraction(ctx, {
		kind: "select",
		key,
		prompt: title,
		options,
		resumeMessage: config?.resumeMessage,
	});
	if (!interaction) {
		return { value: null, prompt: `Cannot complete "${title}" without interactive input.` };
	}
	if (interaction.state === "resolved") {
		return { value: interaction.value };
	}
	return { value: null, prompt: interaction.prompt };
}

export async function requestTextInput(
	ctx: ExtensionContext,
	key: string,
	title: string,
	config?: { placeholder?: string; resumeMessage?: string },
): Promise<{ value: string | null; prompt?: string }> {
	if (ctx.hasUI) {
		const entered = await ctx.ui.input(title, config?.placeholder);
		return { value: entered ?? null };
	}

	const interaction = requestInteraction(ctx, {
		kind: "input",
		key,
		prompt: config?.placeholder ? `${title}\nHint: ${config.placeholder}` : title,
		resumeMessage: config?.resumeMessage,
	});
	if (!interaction) {
		return { value: null, prompt: `Cannot complete "${title}" without interactive input.` };
	}
	if (interaction.state === "resolved") {
		return { value: interaction.value };
	}
	return { value: null, prompt: interaction.prompt };
}

/** Return current time as ISO 8601 string without milliseconds (e.g., `2026-03-06T12:00:00Z`). */
export function nowIso(): string {
	return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

type LogLevel = "debug" | "info" | "warn" | "error";

/** Create a structured JSON logger for a named component. Outputs to stdout/stderr with timestamp, level, component, and message. */
export function createLogger(component: string) {
	function log(level: LogLevel, msg: string, extra?: Record<string, unknown>): void {
		const entry: Record<string, unknown> = {
			ts: new Date().toISOString(),
			level,
			component,
			msg,
			...extra,
		};
		const line = JSON.stringify(entry);
		if (level === "error") {
			console.error(line);
		} else if (level === "warn") {
			console.warn(line);
		} else {
			console.log(line);
		}
	}

	return {
		debug: (msg: string, extra?: Record<string, unknown>) => log("debug", msg, extra),
		info: (msg: string, extra?: Record<string, unknown>) => log("info", msg, extra),
		warn: (msg: string, extra?: Record<string, unknown>) => log("warn", msg, extra),
		error: (msg: string, extra?: Record<string, unknown>) => log("error", msg, extra),
	};
}

/** Validate that a service/unit name matches `<prefix>-[a-z0-9-]+`. Returns error message or null. */
export function guardServiceName(name: string, prefix = "nixpi"): string | null {
	const escapedPrefix = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	const pattern = new RegExp(`^${escapedPrefix}-[a-z0-9][a-z0-9-]*$`);
	if (!pattern.test(name)) {
		return `Security error: name must match ${prefix}-[a-z0-9-]+, got "${name}"`;
	}
	return null;
}

export type InteractionKind = "confirm" | "select" | "input";
export type InteractionStatus = "pending" | "resolved" | "consumed";

export interface InteractionRecord {
	token: string;
	kind: InteractionKind;
	key: string;
	prompt: string;
	status: InteractionStatus;
	resolution?: string;
	options?: string[];
	resumeMessage?: string;
	createdAt: string;
	updatedAt: string;
}

interface InteractionStore {
	records: InteractionRecord[];
}

export interface ResolvedInteractionReply {
	record: InteractionRecord;
	value: string;
	ambiguous?: boolean;
}

const InteractionRecordSchema = Type.Object({
	token: Type.String(),
	kind: Type.Union([Type.Literal("confirm"), Type.Literal("select"), Type.Literal("input")]),
	key: Type.String(),
	prompt: Type.String(),
	status: Type.Union([Type.Literal("pending"), Type.Literal("resolved"), Type.Literal("consumed")]),
	resolution: Type.Optional(Type.String()),
	options: Type.Optional(Type.Array(Type.String())),
	resumeMessage: Type.Optional(Type.String()),
	createdAt: Type.String(),
	updatedAt: Type.String(),
});

const InteractionStoreSchema = Type.Object({
	records: Type.Array(InteractionRecordSchema),
});

const STORE_SUFFIX = ".nixpi-interactions.json";
const MAX_RECORDS = 32;

function interactionNowIso(): string {
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

function loadStore(storePath: string): InteractionStore {
	try {
		return Value.Parse(InteractionStoreSchema, JSON.parse(fs.readFileSync(storePath, "utf-8")));
	} catch {
		return { records: [] };
	}
}

function saveStore(storePath: string, store: InteractionStore): void {
	fs.mkdirSync(path.dirname(storePath), { recursive: true });
	const trimmed = store.records.slice(-MAX_RECORDS);
	fs.writeFileSync(storePath, JSON.stringify({ records: trimmed }, null, 2));
}

function getPendingRecords(store: InteractionStore): InteractionRecord[] {
	return store.records.filter((entry) => entry.status === "pending");
}

function buildConfirmPrompt(record: InteractionRecord): string {
	return `Confirmation required for "${record.key}". Reply here with "confirm ${record.token}" to approve or "deny ${record.token}" to cancel.`;
}

function buildSelectPrompt(record: InteractionRecord): string {
	const options = record.options ?? [];
	const lines = [
		`${record.prompt}`,
		"",
		...options.map((option, index) => `${index + 1}. ${option}`),
		"",
		`Reply with the number or exact option text, for example "1 ${record.token}" or "${options[0] ?? ""} ${record.token}".`,
	];
	return lines.join("\n");
}

function buildInputPrompt(record: InteractionRecord): string {
	return `${record.prompt}\n\nReply with your answer followed by ${record.token} if needed to disambiguate.`;
}

function buildPrompt(record: InteractionRecord): string {
	switch (record.kind) {
		case "confirm":
			return buildConfirmPrompt(record);
		case "select":
			return buildSelectPrompt(record);
		case "input":
			return buildInputPrompt(record);
	}
}

function findLatestMatchingPending(
	store: InteractionStore,
	kind: InteractionKind,
	key: string,
): InteractionRecord | undefined {
	return [...store.records]
		.reverse()
		.find((entry) => entry.kind === kind && entry.key === key && entry.status === "pending");
}

function markResolved(store: InteractionStore, token: string, value: string): InteractionRecord | null {
	const record = store.records.find((entry) => entry.token === token);
	if (!record) return null;
	record.status = "resolved";
	record.resolution = value;
	record.updatedAt = interactionNowIso();
	return record;
}

function markConsumed(record: InteractionRecord): void {
	record.status = "consumed";
	record.updatedAt = interactionNowIso();
}

function normalizeReplyText(text: string, token?: string): string {
	const trimmed = text.trim();
	if (!token) return trimmed;
	return trimmed
		.replace(new RegExp(`\\s+${token}$`, "i"), "")
		.replace(new RegExp(`^${token}\\s+`, "i"), "")
		.trim();
}

function parseConfirmValue(text: string): "approved" | "denied" | null {
	const normalized = text.trim().toLowerCase();
	if (["confirm", "approve", "yes"].includes(normalized)) return "approved";
	if (["deny", "decline", "no"].includes(normalized)) return "denied";
	return null;
}

function parseSelectValue(text: string, options: string[]): string | null {
	const trimmed = text.trim();
	if (!trimmed) return null;
	if (/^\d+$/.test(trimmed)) {
		const index = Number(trimmed) - 1;
		return options[index] ?? null;
	}

	const lower = trimmed.toLowerCase();
	const exact = options.find((option) => option.toLowerCase() === lower);
	return exact ?? null;
}

function parseInputValue(text: string): string | null {
	const trimmed = text.trim();
	return trimmed.length > 0 ? trimmed : null;
}

function extractTargetToken(text: string, pending: InteractionRecord[]): string | undefined {
	const words = text.trim().split(/\s+/).filter(Boolean);
	if (words.length === 0) return undefined;
	const pendingTokens = new Set(pending.map((entry) => entry.token.toLowerCase()));
	const first = words[0]?.toLowerCase();
	const last = words[words.length - 1]?.toLowerCase();
	if (first && pendingTokens.has(first)) return first;
	if (last && pendingTokens.has(last)) return last;
	return undefined;
}

function parseValue(record: InteractionRecord, text: string): string | null {
	switch (record.kind) {
		case "confirm":
			return parseConfirmValue(text);
		case "select":
			return parseSelectValue(text, record.options ?? []);
		case "input":
			return parseInputValue(text);
	}
}

export function requestInteraction(
	ctx: ExtensionContext,
	request: {
		kind: InteractionKind;
		key: string;
		prompt: string;
		options?: string[];
		resumeMessage?: string;
	},
): { state: "resolved"; value: string } | { state: "pending"; record: InteractionRecord; prompt: string } | null {
	const storePath = getStorePath(ctx);
	if (!storePath) return null;

	const store = loadStore(storePath);
	const resolved = [...store.records]
		.reverse()
		.find((entry) => entry.kind === request.kind && entry.key === request.key && entry.status === "resolved");
	if (resolved?.resolution) {
		const value = resolved.resolution;
		markConsumed(resolved);
		saveStore(storePath, store);
		return { state: "resolved", value };
	}

	const existing = findLatestMatchingPending(store, request.kind, request.key);
	if (existing) {
		return { state: "pending", record: existing, prompt: buildPrompt(existing) };
	}

	const ts = interactionNowIso();
	const record: InteractionRecord = {
		token: generateToken(),
		kind: request.kind,
		key: request.key,
		prompt: request.prompt,
		status: "pending",
		...(request.options ? { options: request.options } : {}),
		...(request.resumeMessage ? { resumeMessage: request.resumeMessage } : {}),
		createdAt: ts,
		updatedAt: ts,
	};
	store.records.push(record);
	saveStore(storePath, store);
	return { state: "pending", record, prompt: buildPrompt(record) };
}

export function resolveInteractionReply(ctx: ExtensionContext, text: string): ResolvedInteractionReply | null {
	const storePath = getStorePath(ctx);
	if (!storePath) return null;

	const store = loadStore(storePath);
	const pending = getPendingRecords(store);
	if (pending.length === 0) return null;

	const explicitToken = extractTargetToken(text, pending);
	let record: InteractionRecord | undefined;
	let ambiguous = false;
	if (explicitToken) {
		record = pending.find((entry) => entry.token === explicitToken);
	} else if (pending.length === 1) {
		record = pending[0];
	} else {
		record = pending[pending.length - 1];
		ambiguous = true;
	}
	if (!record) return null;

	const normalizedReply = normalizeReplyText(text, record.token);
	const value = parseValue(record, normalizedReply);
	if (!value) return null;

	const resolved = markResolved(store, record.token, value);
	if (!resolved) return null;
	saveStore(storePath, store);
	return { record: resolved, value, ...(ambiguous ? { ambiguous: true } : {}) };
}

export function formatResumeMessage(record: InteractionRecord, value: string): string {
	const template = record.resumeMessage;
	if (template) {
		return template.replaceAll("{{value}}", value).replaceAll("{{token}}", record.token);
	}

	if (record.kind === "confirm") {
		return `The user ${value === "approved" ? "approved" : "denied"} confirmation ${record.token} for "${record.key}". Resume the blocked task if appropriate.`;
	}
	if (record.kind === "select") {
		return `The user selected "${value}" for "${record.key}". Continue the requested workflow using that choice.`;
	}
	return `The user replied "${value}" for "${record.key}". Continue the requested workflow using that input.`;
}

export function getPendingInteractions(ctx: ExtensionContext): InteractionRecord[] {
	const storePath = getStorePath(ctx);
	if (!storePath) return [];
	return getPendingRecords(loadStore(storePath));
}
