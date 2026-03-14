# Daemon Architecture

> 📖 [Emoji Legend](LEGEND.md)

This guide explains how `pi-daemon.service` behaves today and where the main moving parts live.

## Mental Model

Bloom's daemon has two runtime modes:

- single-agent mode: one Matrix identity, one Pi session per room
- multi-agent mode: one Matrix identity per agent overlay, one Pi session per `(room, agent)`

Both modes use the same core building blocks:

- Matrix transport through the official `matrix-js-sdk`
- Pi execution through Pi SDK-backed in-process sessions
- daemon-owned lifecycle and retry logic

## Mode Selection

At startup:

1. Bloom loads `~/Bloom/Agents/*/AGENTS.md`.
2. If no valid overlays exist, the daemon starts in single-agent fallback mode.
3. If at least one valid overlay exists, the daemon starts in multi-agent mode.
4. Malformed overlays are skipped with warnings instead of aborting startup.

## Runtime Layout

### Single-Agent Path

Single-agent behavior is centered around:

- [`core/daemon/single-agent-runtime.ts`](../core/daemon/single-agent-runtime.ts)
- [`core/daemon/runtime/pi-room-session.ts`](../core/daemon/runtime/pi-room-session.ts)
- [`core/daemon/room-failures.ts`](../core/daemon/room-failures.ts)

Current behavior:

- one Matrix identity: the primary Pi account
- one Pi session per room
- room alias lookup before first message preamble
- typing state maintained while the agent is actively responding
- repeated room failures can quarantine that room temporarily
- Matrix send failures on final reply forwarding are best-effort and do not crash the runtime

### Multi-Agent Path

Multi-agent behavior is centered around:

- [`core/daemon/multi-agent-runtime.ts`](../core/daemon/multi-agent-runtime.ts)
- [`core/daemon/agent-supervisor.ts`](../core/daemon/agent-supervisor.ts)
- [`core/daemon/router.ts`](../core/daemon/router.ts)
- [`core/daemon/room-state.ts`](../core/daemon/room-state.ts)

Current behavior:

- one Matrix client per configured agent identity
- one Pi session per `(room, agent)`
- routing based on host mode, mentions, cooldowns, and per-root reply budgets
- sequential handoff when multiple agents are explicitly targeted in order
- supervisor shutdown suppresses fresh handoffs and proactive dispatch

## Proactive Jobs

Agent overlays may declare proactive jobs in frontmatter:

```yaml
proactive:
  jobs:
    - id: daily-heartbeat
      kind: heartbeat
      room: "!ops:bloom"
      interval_minutes: 1440
      prompt: |
        Review the room and host state.
        Reply HEARTBEAT_OK if nothing needs surfacing.
      quiet_if_noop: true
      no_op_token: HEARTBEAT_OK
    - id: morning-check
      kind: cron
      room: "!ops:bloom"
      cron: "0 9 * * *"
      prompt: Send the morning operational check-in.
```

Current rules:

- `heartbeat` jobs use `interval_minutes`
- `cron` jobs support `@hourly`, `@daily`, and fixed `minute hour * * *`
- proactive job ids must be unique per `(room, id)` within one agent overlay
- scheduler state is persisted per `(agent, room, job)`
- heartbeat failures back off by the configured interval instead of retrying immediately in a tight loop
- heartbeat replies can be suppressed when `quiet_if_noop: true` and the reply exactly matches `no_op_token`

Implementation files:

- [`core/daemon/scheduler.ts`](../core/daemon/scheduler.ts)
- [`core/daemon/proactive.ts`](../core/daemon/proactive.ts)

## Lifecycle Helpers

Two extracted helpers keep the daemon code testable and readable:

- [`core/daemon/lifecycle.ts`](../core/daemon/lifecycle.ts)
  Shared startup retry/backoff helper.
- [`core/daemon/multi-agent-runtime.ts`](../core/daemon/multi-agent-runtime.ts)
  Multi-agent bridge, supervisor, and scheduler wiring.
- [`core/daemon/single-agent-runtime.ts`](../core/daemon/single-agent-runtime.ts)
  Single-agent bridge, room session, and shutdown wiring.

## Failure Handling

Important current behavior:

- startup uses retry/backoff instead of one-shot failure
- malformed agent overlays are skipped, not fatal
- room failure quarantine only applies to single-agent room sessions
- proactive heartbeat failures are delayed by one full interval before retry
- duplicate-event and cooldown state is bounded and pruned over time

## What To Read First

If you are changing:

- daemon bootstrap or service startup:
  start with [`core/daemon/index.ts`](../core/daemon/index.ts)
- single-agent message flow:
  start with [`core/daemon/single-agent-runtime.ts`](../core/daemon/single-agent-runtime.ts)
- multi-agent routing:
  start with [`core/daemon/multi-agent-runtime.ts`](../core/daemon/multi-agent-runtime.ts) and [`core/daemon/agent-supervisor.ts`](../core/daemon/agent-supervisor.ts)
- proactive scheduling:
  start with [`core/daemon/scheduler.ts`](../core/daemon/scheduler.ts) and [`core/daemon/proactive.ts`](../core/daemon/proactive.ts)
