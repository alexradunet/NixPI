import type { AgentDefinition } from "./agent-registry.js";

export interface RoomStateLike {
	hasProcessedEvent(eventId: string, now: number): boolean;
	markEventProcessed(eventId: string, now: number): void;
	isAgentCoolingDown(roomId: string, agentId: string, now: number, cooldownMs: number): boolean;
	canReplyForRoot(
		roomId: string,
		rootEventId: string,
		agentId: string,
		maxPublicTurnsPerRoot: number,
		totalReplyBudget: number,
		now?: number,
	): boolean;
	markReplySent(roomId: string, rootEventId: string, agentId: string, now: number): void;
}

export interface RoomEnvelope {
	roomId: string;
	eventId: string;
	senderUserId: string;
	body: string;
	senderKind: "human" | "agent" | "self" | "unknown";
	senderAgentId?: string;
	mentions: string[];
	timestamp: number;
}

export interface RouteDecision {
	targets: [string] | [];
	reason:
		| "host-default"
		| "explicit-mention"
		| "agent-mention"
		| "ignored-self"
		| "ignored-duplicate"
		| "ignored-policy"
		| "ignored-budget"
		| "ignored-cooldown";
}

export interface RouteOptions {
	rootEventId?: string;
	totalReplyBudget?: number;
}

const DEFAULT_ALLOW_AGENT_MENTIONS = true;
const DEFAULT_MAX_PUBLIC_TURNS_PER_ROOT = 2;
const DEFAULT_COOLDOWN_MS = 1500;

interface InitialTargetDecision {
	targets: [AgentDefinition] | [];
	reason: RouteDecision["reason"];
}

export function extractMentions(body: string, agents: readonly AgentDefinition[]): string[] {
	return agents
		.map((agent) => ({ userId: agent.matrix.userId, index: body.indexOf(agent.matrix.userId) }))
		.filter((hit) => hit.index >= 0)
		.sort((left, right) => left.index - right.index)
		.map((hit) => hit.userId);
}

export function classifySender(
	senderUserId: string,
	selfUserId: string,
	agents: readonly AgentDefinition[],
): { senderKind: RoomEnvelope["senderKind"]; senderAgentId?: string } {
	if (senderUserId === selfUserId) return { senderKind: "self" };
	const agent = agents.find((candidate) => candidate.matrix.userId === senderUserId);
	if (agent) return { senderKind: "agent", senderAgentId: agent.id };
	if (/^@[a-zA-Z0-9._=\-/]+:[a-zA-Z0-9.-]+$/.test(senderUserId)) return { senderKind: "human" };
	return { senderKind: "unknown" };
}

export function routeRoomEnvelope(
	envelope: RoomEnvelope,
	agents: readonly AgentDefinition[],
	state: RoomStateLike,
	options: RouteOptions = {},
): RouteDecision {
	const ignoredReason = getIgnoredReason(envelope, state);
	if (ignoredReason) return { targets: [], reason: ignoredReason };

	const rootEventId = options.rootEventId ?? envelope.eventId;
	const totalReplyBudget = options.totalReplyBudget ?? 4;
	const initialDecision = getInitialTargetDecision(envelope, agents);
	if (initialDecision.targets.length === 0) return { targets: [], reason: "ignored-policy" };

	const [targetAgent] = initialDecision.targets;
	if (!targetAgent) {
		return { targets: [], reason: "ignored-policy" };
	}

	const canReply = state.canReplyForRoot(
		envelope.roomId,
		rootEventId,
		targetAgent.id,
		DEFAULT_MAX_PUBLIC_TURNS_PER_ROOT,
		totalReplyBudget,
		envelope.timestamp,
	);
	if (!canReply) {
		return { targets: [], reason: "ignored-budget" };
	}

	if (state.isAgentCoolingDown(envelope.roomId, targetAgent.id, envelope.timestamp, DEFAULT_COOLDOWN_MS)) {
		return { targets: [], reason: "ignored-cooldown" };
	}

	state.markReplySent(envelope.roomId, rootEventId, targetAgent.id, envelope.timestamp);

	return {
		targets: [targetAgent.id],
		reason: initialDecision.reason,
	};
}

function getIgnoredReason(
	envelope: RoomEnvelope,
	state: RoomStateLike,
): Extract<RouteDecision["reason"], "ignored-self" | "ignored-duplicate"> | undefined {
	if (envelope.senderKind === "self") return "ignored-self";
	if (state.hasProcessedEvent(envelope.eventId, envelope.timestamp)) return "ignored-duplicate";
	state.markEventProcessed(envelope.eventId, envelope.timestamp);
	return undefined;
}

function getInitialTargetDecision(envelope: RoomEnvelope, agents: readonly AgentDefinition[]): InitialTargetDecision {
	const mentionedAgents = getMentionedAgents(envelope.mentions, agents);
	if (envelope.senderKind === "human") {
		return getHumanTargetDecision(envelope.mentions.length > 0, mentionedAgents, agents);
	}
	if (envelope.senderKind === "agent") {
		return getAgentTargetDecision(envelope.senderAgentId, mentionedAgents);
	}
	return { targets: [], reason: "ignored-policy" };
}

function getMentionedAgents(mentions: readonly string[], agents: readonly AgentDefinition[]): AgentDefinition[] {
	return mentions.flatMap((userId) => {
		const agent = agents.find((candidate) => candidate.matrix.userId === userId);
		if (!agent || agent.respond.mode === "silent") return [];
		return [agent];
	});
}

function getHumanTargetDecision(
	hadExplicitMention: boolean,
	mentionedAgents: readonly AgentDefinition[],
	agents: readonly AgentDefinition[],
): InitialTargetDecision {
	if (hadExplicitMention && mentionedAgents.length > 0) {
		const [firstMentionedAgent] = mentionedAgents;
		return firstMentionedAgent
			? { targets: [firstMentionedAgent], reason: "explicit-mention" }
			: { targets: [], reason: "ignored-policy" };
	}

	const hostAgent = agents.find((agent) => agent.respond.mode === "host");
	if (hadExplicitMention || !hostAgent) return { targets: [], reason: "ignored-policy" };
	return { targets: [hostAgent], reason: "host-default" };
}

function getAgentTargetDecision(
	senderAgentId: string | undefined,
	mentionedAgents: readonly AgentDefinition[],
): InitialTargetDecision {
	const target = mentionedAgents.find((agent) => agent.id !== senderAgentId && DEFAULT_ALLOW_AGENT_MENTIONS);
	if (!target) return { targets: [], reason: "ignored-policy" };
	return { targets: [target], reason: "agent-mention" };
}
