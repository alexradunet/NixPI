import { describe, expect, it } from "vitest";

import type { AgentDefinition } from "../../core/daemon/agent-registry.js";
import { ConversationState } from "../../core/daemon/conversation-state.js";
import type { RoomEnvelope } from "../../core/daemon/router.js";

function makeAgent(id: string, userId: string): AgentDefinition {
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
			mode: "mentioned",
			allowAgentMentions: true,
			maxPublicTurnsPerRoot: 2,
			cooldownMs: 1500,
		},
	};
}

describe("ConversationState", () => {
	it("tracks sequential handoff progress across agent replies", () => {
		const state = new ConversationState();
		const envelope: RoomEnvelope = {
			roomId: "!room:bloom",
			eventId: "$evt1",
			senderUserId: "@alex:bloom",
			body: "@planner:bloom draft it then @critic:bloom review it",
			senderKind: "human",
			mentions: ["@planner:bloom", "@critic:bloom"],
			timestamp: 1_000,
		};

		const chain = state.startSequentialChain(envelope, ["critic"]);
		state.enqueueWaitingChain("!room:bloom", "planner", chain.key);

		const progress = state.appendChainReply("!room:bloom", "planner", "Draft plan");
		expect(progress?.nextAgentId).toBe("critic");
		expect(progress?.chain.originalMessage).toContain("[matrix: @alex:bloom]");

		state.enqueueWaitingChain("!room:bloom", "critic", chain.key);
		const complete = state.appendChainReply("!room:bloom", "critic", "Main flaw");
		expect(complete?.nextAgentId).toBeUndefined();
	});

	it("builds handoff prompts from prior replies", () => {
		const state = new ConversationState();
		const envelope: RoomEnvelope = {
			roomId: "!room:bloom",
			eventId: "$evt1",
			senderUserId: "@alex:bloom",
			body: "start",
			senderKind: "human",
			mentions: [],
			timestamp: 1_000,
		};
		const planner = makeAgent("planner", "@planner:bloom");
		const critic = makeAgent("critic", "@critic:bloom");
		const chain = state.startSequentialChain(envelope, ["critic"]);
		state.enqueueWaitingChain("!room:bloom", "planner", chain.key);
		const progress = state.appendChainReply("!room:bloom", "planner", "Draft plan");
		const message = state.buildSequentialHandoffMessage(progress!.chain, critic, (agentId) =>
			agentId === "planner" ? planner : critic,
		);

		expect(message).toContain("Planner (@planner:bloom) replied:");
		expect(message).toContain("Now respond as Critic (@critic:bloom).");
	});
});
