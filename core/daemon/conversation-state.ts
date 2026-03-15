import type { AgentDefinition } from "./agent-registry.js";
import type { RoomEnvelope } from "./router.js";
import type { TriggeredJob } from "./scheduler.js";

interface SequentialChainReply {
	agentId: string;
	text: string;
}

interface SequentialChain {
	key: string;
	roomId: string;
	rootEventId: string;
	originalMessage: string;
	remainingAgentIds: string[];
	replies: SequentialChainReply[];
}

interface PendingProactiveJob {
	jobId: string;
	kind: TriggeredJob["kind"];
	quietIfNoop: boolean;
	noOpToken?: string;
}

export class ConversationState {
	private readonly sequentialChains = new Map<string, SequentialChain>();
	private readonly waitingChainsByRoomAgent = new Map<string, string[]>();
	private readonly pendingProactiveJobs = new Map<string, PendingProactiveJob[]>();

	startSequentialChain(envelope: RoomEnvelope, remainingAgentIds: string[]): SequentialChain {
		const chainKey = this.chainKey(envelope.roomId, envelope.eventId);
		const chain: SequentialChain = {
			key: chainKey,
			roomId: envelope.roomId,
			rootEventId: envelope.eventId,
			originalMessage: `[matrix: ${envelope.senderUserId}] ${envelope.body}`,
			remainingAgentIds: [...remainingAgentIds],
			replies: [],
		};
		this.sequentialChains.set(chainKey, chain);
		return chain;
	}

	cancelSequentialChain(chainKey: string): void {
		this.sequentialChains.delete(chainKey);
	}

	enqueueWaitingChain(roomId: string, agentId: string, chainKey: string): void {
		const key = this.roomAgentKey(roomId, agentId);
		const queue = this.waitingChainsByRoomAgent.get(key) ?? [];
		queue.push(chainKey);
		this.waitingChainsByRoomAgent.set(key, queue);
	}

	dequeueWaitingChain(roomId: string, agentId: string): string | undefined {
		const key = this.roomAgentKey(roomId, agentId);
		const queue = this.waitingChainsByRoomAgent.get(key);
		if (!queue || queue.length === 0) return undefined;
		const chainKey = queue.shift();
		if (queue.length === 0) {
			this.waitingChainsByRoomAgent.delete(key);
		} else {
			this.waitingChainsByRoomAgent.set(key, queue);
		}
		return chainKey;
	}

	appendChainReply(roomId: string, agentId: string, text: string): { chain: SequentialChain; nextAgentId?: string } | null {
		const chainKey = this.dequeueWaitingChain(roomId, agentId);
		if (!chainKey) return null;

		const chain = this.sequentialChains.get(chainKey);
		if (!chain) return null;

		chain.replies.push({ agentId, text });
		const nextAgentId = chain.remainingAgentIds.shift();
		if (!nextAgentId) {
			this.sequentialChains.delete(chainKey);
			return { chain };
		}

		return { chain, nextAgentId };
	}

	buildSequentialHandoffMessage(chain: SequentialChain, nextAgent: AgentDefinition, requireAgent: (agentId: string) => AgentDefinition): string {
		const priorReplies = chain.replies
			.map(({ agentId, text }) => {
				const priorAgent = requireAgent(agentId);
				return [`${priorAgent.name} (${priorAgent.matrix.userId}) replied:`, text].join("\n");
			})
			.join("\n\n");

		return [
			"[system] This is a sequential multi-agent handoff.",
			"The original room message was:",
			chain.originalMessage,
			"",
			"Previous agent replies in order:",
			priorReplies,
			"",
			`Now respond as ${nextAgent.name} (${nextAgent.matrix.userId}).`,
			"Continue from the prior reply instead of starting independently.",
			"If the human asked for critique or follow-up, address the previous agent's output directly.",
		].join("\n");
	}

	enqueueProactiveJob(roomId: string, agentId: string, job: PendingProactiveJob): void {
		const key = this.roomAgentKey(roomId, agentId);
		const queue = this.pendingProactiveJobs.get(key) ?? [];
		queue.push(job);
		this.pendingProactiveJobs.set(key, queue);
	}

	dequeueProactiveJob(roomId: string, agentId: string): PendingProactiveJob | undefined {
		const key = this.roomAgentKey(roomId, agentId);
		const queue = this.pendingProactiveJobs.get(key);
		if (!queue || queue.length === 0) return undefined;
		const job = queue.shift();
		if (queue.length === 0) {
			this.pendingProactiveJobs.delete(key);
		} else {
			this.pendingProactiveJobs.set(key, queue);
		}
		return job;
	}

	clear(): void {
		this.sequentialChains.clear();
		this.waitingChainsByRoomAgent.clear();
		this.pendingProactiveJobs.clear();
	}

	private chainKey(roomId: string, rootEventId: string): string {
		return `${roomId}::${rootEventId}`;
	}

	private roomAgentKey(roomId: string, agentId: string): string {
		return `${roomId}::${agentId}`;
	}
}
