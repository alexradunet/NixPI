import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import type { AgentDefinition } from "./agent-registry.js";
import type { ScheduledJob, SchedulerJobState } from "./scheduler.js";

export function collectScheduledJobs(agents: readonly AgentDefinition[]): ScheduledJob[] {
	return agents.flatMap((agent) =>
		(agent.proactive?.jobs ?? []).map((job) => ({
			id: job.id,
			agentId: agent.id,
			roomId: job.room,
			kind: job.kind,
			prompt: job.prompt,
			...(job.intervalMinutes ? { intervalMinutes: job.intervalMinutes } : {}),
			...(job.cron ? { cron: job.cron } : {}),
			...(job.quietIfNoop !== undefined ? { quietIfNoop: job.quietIfNoop } : {}),
			...(job.noOpToken ? { noOpToken: job.noOpToken } : {}),
		})),
	);
}

export function loadSchedulerState(statePath: string): Record<string, SchedulerJobState> {
	try {
		const raw = readFileSync(statePath, "utf-8");
		const parsed = JSON.parse(raw);
		if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
		return parsed as Record<string, SchedulerJobState>;
	} catch {
		return {};
	}
}

export function saveSchedulerState(statePath: string, state: Record<string, SchedulerJobState>): void {
	mkdirSync(dirname(statePath), { recursive: true });
	writeFileSync(statePath, `${JSON.stringify(state, null, 2)}\n`, "utf-8");
}
