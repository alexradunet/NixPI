import { describe, expect, it } from "vitest";

import type { AgentDefinition } from "../../core/daemon/agent-registry.js";
import { enforceMapLimit, pruneExpiredEntries } from "../../core/daemon/ordered-cache.js";
import type { RoomStateLike } from "../../core/daemon/router.js";
import { classifySender, extractMentions, routeRoomEnvelope } from "../../core/daemon/router.js";

// Minimal in-process implementation of RoomStateLike for router unit tests.
function createRoomState(): RoomStateLike {
	const processedEvents = new Map<string, number>();
	const rootReplies = new Map<
		string,
		{ perAgentReplies: Map<string, number>; totalReplies: number; lastTouchedAt: number }
	>();
	const lastReplyAtByRoomAgent = new Map<string, number>();

	const PROCESSED_EVENT_TTL = 5 * 60 * 1000;
	const ROOT_REPLY_TTL = 60 * 60 * 1000;
	const ROOM_AGENT_TTL = 60 * 60 * 1000;

	function prune(now: number): void {
		pruneExpiredEntries(processedEvents, now, (ts) => ts, PROCESSED_EVENT_TTL);
		pruneExpiredEntries(lastReplyAtByRoomAgent, now, (ts) => ts, ROOM_AGENT_TTL);
		pruneExpiredEntries(rootReplies, now, (s) => s.lastTouchedAt, ROOT_REPLY_TTL);
	}

	return {
		hasProcessedEvent(eventId, now) {
			prune(now);
			return processedEvents.has(eventId);
		},
		markEventProcessed(eventId, now) {
			prune(now);
			processedEvents.set(eventId, now);
			enforceMapLimit(processedEvents, 10_000);
		},
		isAgentCoolingDown(roomId, agentId, now, cooldownMs) {
			prune(now);
			const last = lastReplyAtByRoomAgent.get(`${roomId}::${agentId}`);
			if (last === undefined) return false;
			return now - last < cooldownMs;
		},
		canReplyForRoot(roomId, rootEventId, agentId, maxPublicTurns, totalBudget, now) {
			if (typeof now === "number") prune(now);
			const state = rootReplies.get(`${roomId}::${rootEventId}`);
			if (!state) return true;
			if (state.totalReplies >= totalBudget) return false;
			return (state.perAgentReplies.get(agentId) ?? 0) < maxPublicTurns;
		},
		markReplySent(roomId, rootEventId, agentId, now) {
			prune(now);
			lastReplyAtByRoomAgent.set(`${roomId}::${agentId}`, now);
			enforceMapLimit(lastReplyAtByRoomAgent, 2_000);
			const key = `${roomId}::${rootEventId}`;
			let state = rootReplies.get(key);
			if (!state) {
				state = { totalReplies: 0, perAgentReplies: new Map(), lastTouchedAt: now };
				rootReplies.set(key, state);
			}
			state.totalReplies++;
			state.lastTouchedAt = now;
			state.perAgentReplies.set(agentId, (state.perAgentReplies.get(agentId) ?? 0) + 1);
			enforceMapLimit(rootReplies, 2_000);
		},
	};
}

function makeAgent(id: string, userId: string, mode: AgentDefinition["respond"]["mode"]): AgentDefinition {
	return {
		id,
		name: id[0]?.toUpperCase() + id.slice(1),
		instructionsPath: `/tmp/${id}/AGENTS.md`,
		instructionsBody: `# ${id}`,
		matrix: {
			username: userId.slice(1, userId.indexOf(":")),
			userId,
			autojoin: true,
		},
		respond: {
			mode,
		},
	};
}

const host = makeAgent("host", "@pi:nixpi", "host");
const planner = makeAgent("planner", "@planner:nixpi", "mentioned");
const critic = makeAgent("critic", "@critic:nixpi", "mentioned");
const silent = makeAgent("silent", "@silent:nixpi", "silent");
const agents = [host, planner, critic, silent];

describe("extractMentions", () => {
	it("finds explicit Matrix user id mentions", () => {
		expect(extractMentions("hey @planner:nixpi and @critic:nixpi", agents)).toEqual([
			"@planner:nixpi",
			"@critic:nixpi",
		]);
	});

	it("preserves mention order from the message body instead of agent registry order", () => {
		const registryOrderedAgents = [critic, host, planner, silent];
		expect(extractMentions("@planner:nixpi first, then @critic:nixpi", registryOrderedAgents)).toEqual([
			"@planner:nixpi",
			"@critic:nixpi",
		]);
	});

	it("does not return duplicate mentions", () => {
		expect(extractMentions("@planner:nixpi @planner:nixpi", agents)).toEqual(["@planner:nixpi"]);
	});
});

describe("classifySender", () => {
	it("classifies self messages", () => {
		expect(classifySender("@pi:nixpi", "@pi:nixpi", agents)).toEqual({ senderKind: "self" });
	});

	it("classifies known agents", () => {
		expect(classifySender("@planner:nixpi", "@pi:nixpi", agents)).toEqual({
			senderKind: "agent",
			senderAgentId: "planner",
		});
	});

	it("classifies non-agent users as human", () => {
		expect(classifySender("@alex:nixpi", "@pi:nixpi", agents)).toEqual({ senderKind: "human" });
	});
});

describe("routeRoomEnvelope", () => {
	it("routes human messages without mentions to the host agent", () => {
		const state = createRoomState();
		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt1",
				senderUserId: "@alex:nixpi",
				body: "hello there",
				senderKind: "human",
				mentions: [],
				timestamp: 1_000,
			},
			agents,
			state,
		);

		expect(result).toEqual({ targets: ["host"], reason: "host-default" });
	});

	it("routes explicit human mentions only to the mentioned agents", () => {
		const state = createRoomState();
		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt2",
				senderUserId: "@alex:nixpi",
				body: "@planner:nixpi help me",
				senderKind: "human",
				mentions: ["@planner:nixpi"],
				timestamp: 1_000,
			},
			agents,
			state,
		);

		expect(result).toEqual({ targets: ["planner"], reason: "explicit-mention" });
	});

	it("routes multiple explicit mentions to the first eligible agent in mention order", () => {
		const state = createRoomState();
		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt3",
				senderUserId: "@alex:nixpi",
				body: "@planner:nixpi and @critic:nixpi weigh in",
				senderKind: "human",
				mentions: ["@planner:nixpi", "@critic:nixpi"],
				timestamp: 1_000,
			},
			agents,
			state,
		);

		expect(result).toEqual({ targets: ["planner"], reason: "explicit-mention" });
	});

	it("never auto-targets silent agents", () => {
		const state = createRoomState();
		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt4",
				senderUserId: "@alex:nixpi",
				body: "@silent:nixpi speak",
				senderKind: "human",
				mentions: ["@silent:nixpi"],
				timestamp: 1_000,
			},
			agents,
			state,
		);

		expect(result).toEqual({ targets: [], reason: "ignored-policy" });
	});

	it("requires explicit mention for agent-to-agent routing", () => {
		const state = createRoomState();
		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt5",
				senderUserId: "@planner:nixpi",
				body: "I have thoughts",
				senderKind: "agent",
				senderAgentId: "planner",
				mentions: [],
				timestamp: 1_000,
			},
			agents,
			state,
		);

		expect(result).toEqual({ targets: [], reason: "ignored-policy" });
	});

	it("allows agent-to-agent routing when a peer agent is explicitly mentioned", () => {
		const state = createRoomState();
		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt6",
				senderUserId: "@planner:nixpi",
				body: "@critic:nixpi please review",
				senderKind: "agent",
				senderAgentId: "planner",
				mentions: ["@critic:nixpi"],
				timestamp: 1_000,
			},
			agents,
			state,
		);

		expect(result).toEqual({ targets: ["critic"], reason: "agent-mention" });
	});

	it("rejects duplicate event ids", () => {
		const state = createRoomState();
		const envelope = {
			roomId: "!room:nixpi",
			eventId: "$evt7",
			senderUserId: "@alex:nixpi",
			body: "hello",
			senderKind: "human" as const,
			mentions: [],
			timestamp: 1_000,
		};

		expect(routeRoomEnvelope(envelope, agents, state)).toEqual({
			targets: ["host"],
			reason: "host-default",
		});
		expect(routeRoomEnvelope(envelope, agents, state)).toEqual({
			targets: [],
			reason: "ignored-duplicate",
		});
	});

	it("blocks rapid repeat replies during cooldown", () => {
		const state = createRoomState();
		expect(
			routeRoomEnvelope(
				{
					roomId: "!room:nixpi",
					eventId: "$evt8",
					senderUserId: "@alex:nixpi",
					body: "hello",
					senderKind: "human",
					mentions: [],
					timestamp: 10_000,
				},
				agents,
				state,
			),
		).toEqual({ targets: ["host"], reason: "host-default" });

		expect(
			routeRoomEnvelope(
				{
					roomId: "!room:nixpi",
					eventId: "$evt9",
					senderUserId: "@alex:nixpi",
					body: "hello again",
					senderKind: "human",
					mentions: [],
					timestamp: 10_500,
				},
				agents,
				state,
			),
		).toEqual({ targets: [], reason: "ignored-cooldown" });
	});

	it("blocks replies when the per-root budget is exhausted", () => {
		const state = createRoomState();
		const baseEnvelope = {
			roomId: "!room:nixpi",
			senderUserId: "@alex:nixpi",
			body: "@planner:nixpi help",
			senderKind: "human" as const,
			mentions: ["@planner:nixpi"],
		};

		expect(
			routeRoomEnvelope({ ...baseEnvelope, eventId: "$evt10", timestamp: 20_000 }, agents, state, {
				rootEventId: "$root1",
			}),
		).toEqual({ targets: ["planner"], reason: "explicit-mention" });
		expect(
			routeRoomEnvelope({ ...baseEnvelope, eventId: "$evt11", timestamp: 22_000 }, agents, state, {
				rootEventId: "$root1",
			}),
		).toEqual({ targets: ["planner"], reason: "explicit-mention" });
		expect(
			routeRoomEnvelope({ ...baseEnvelope, eventId: "$evt12", timestamp: 24_000 }, agents, state, {
				rootEventId: "$root1",
			}),
		).toEqual({ targets: [], reason: "ignored-budget" });
	});

	it("ignores self messages", () => {
		const state = createRoomState();
		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt-self",
				senderUserId: "@pi:nixpi",
				body: "I am the bot",
				senderKind: "self",
				mentions: [],
				timestamp: 1_000,
			},
			agents,
			state,
		);

		expect(result).toEqual({ targets: [], reason: "ignored-self" });
	});

	it("blocks agent-to-self mentions", () => {
		const state = createRoomState();
		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt13",
				senderUserId: "@planner:nixpi",
				body: "@planner:nixpi talk to myself",
				senderKind: "agent",
				senderAgentId: "planner",
				mentions: ["@planner:nixpi"],
				timestamp: 1_000,
			},
			agents,
			state,
		);

		// Should not route to self
		expect(result.targets).not.toContain("planner");
	});

	it("blocks unknown sender kinds", () => {
		const state = createRoomState();
		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt14",
				senderUserId: "@unknown:nixpi",
				body: "hello",
				senderKind: "unknown" as const,
				mentions: [],
				timestamp: 1_000,
			},
			agents,
			state,
		);

		expect(result).toEqual({ targets: [], reason: "ignored-policy" });
	});

	it("allows routing after cooldown expires", () => {
		const state = createRoomState();
		const baseEnvelope = {
			roomId: "!room:nixpi",
			senderUserId: "@alex:nixpi",
			body: "hello",
			senderKind: "human" as const,
			mentions: [] as string[],
		};

		// First message routes
		expect(routeRoomEnvelope({ ...baseEnvelope, eventId: "$evt15", timestamp: 30_000 }, agents, state)).toEqual({
			targets: ["host"],
			reason: "host-default",
		});

		// Within cooldown, blocked
		expect(routeRoomEnvelope({ ...baseEnvelope, eventId: "$evt16", timestamp: 30_500 }, agents, state)).toEqual({
			targets: [],
			reason: "ignored-cooldown",
		});

		// After cooldown (1500ms), routes again
		expect(routeRoomEnvelope({ ...baseEnvelope, eventId: "$evt17", timestamp: 31_600 }, agents, state)).toEqual({
			targets: ["host"],
			reason: "host-default",
		});
	});

	it("respects custom total reply budget", () => {
		const state = createRoomState();
		const baseEnvelope = {
			roomId: "!room:nixpi",
			senderUserId: "@alex:nixpi",
			body: "hello",
			senderKind: "human" as const,
			mentions: [] as string[],
		};

		// With budget of 1 and same root event
		expect(
			routeRoomEnvelope({ ...baseEnvelope, eventId: "$evt18", timestamp: 40_000 }, agents, state, {
				rootEventId: "$root-budget",
				totalReplyBudget: 1,
			}),
		).toEqual({ targets: ["host"], reason: "host-default" });

		// Second message blocked by budget (same root)
		expect(
			routeRoomEnvelope({ ...baseEnvelope, eventId: "$evt19", timestamp: 42_000 }, agents, state, {
				rootEventId: "$root-budget",
				totalReplyBudget: 1,
			}),
		).toEqual({ targets: [], reason: "ignored-budget" });
	});

	it("ignores messages with no host agent when there are no mentions", () => {
		const noHostAgents = [planner, critic, silent];
		const state = createRoomState();

		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt21",
				senderUserId: "@alex:nixpi",
				body: "hello",
				senderKind: "human",
				mentions: [],
				timestamp: 1_000,
			},
			noHostAgents,
			state,
		);

		expect(result).toEqual({ targets: [], reason: "ignored-policy" });
	});

	it("handles empty agents list", () => {
		const state = createRoomState();

		const result = routeRoomEnvelope(
			{
				roomId: "!room:nixpi",
				eventId: "$evt22",
				senderUserId: "@alex:nixpi",
				body: "hello",
				senderKind: "human",
				mentions: [],
				timestamp: 1_000,
			},
			[],
			state,
		);

		expect(result).toEqual({ targets: [], reason: "ignored-policy" });
	});
});
