# Bloom Architect Memory

## Last Full Review
- Date: 2026-03-08, post-slimdown refactor
- Overall: Healthy — major codebase slimdown completed

## Resolved (2026-03-07 slimdown)
- D-1: Duplicated service install → service_install now delegates to installServicePackage
- D-2: systemdDir duplication → bloom-manifest merged into bloom-services
- D-3: Package root resolution → still 3 patterns but acceptable (different contexts)
- L-4: ensureCommand duplication → removed with OCI distribution
- Single-function lib files → 6 files inlined into consumers
- OCI distribution → removed entirely (local-only install)
- extensions/shared.ts → deleted (no-op bridge, unused)
- createRequire hacks → replaced with direct ESM imports

## Current Architecture (9 extensions, 25 tools)
- bloom-persona: identity injection, guardrails, compaction context
- bloom-audit: tool-call audit trail with 30-day retention
- bloom-os: bootc(action), container(action), systemd_control, system_health, update_status, schedule_reboot
- bloom-repo: bloom_repo(action), bloom_repo_submit_pr
- bloom-services: service_scaffold/install/test + manifest_show/sync/set_service/apply (merged from bloom-manifest)
- bloom-objects: memory_create/read/search/link/list
- bloom-garden: garden_status, skill_create/list, persona_evolve
- bloom-channels: Unix socket server, /wa command
- bloom-topics: /topic command, session organization

## Architecture Patterns
- lib/ layer is genuinely pure (no side effects) — good domain core
- Extensions lack port/adapter separation — directly call fs, execFile, net
- Cross-extension coupling is low (communicate via Pi events only)
- Shared env var `_BLOOM_DIR_RESOLVED` is the only cross-extension state

## Pi SDK Import Clarification
- CLAUDE.md says "never import at runtime" — MISLEADING
- `StringEnum`, `Type`, `truncateHead` are VALUE exports requiring runtime import
- They are peerDependencies resolved by Pi — architecturally correct

## Testing Patterns
- `tests/helpers/temp-garden.ts` — creates temp dir, saves/restores env vars
- `tests/helpers/mock-extension-api.ts` — mock with _registeredTools, fireEvent
- Vitest with v8 coverage, thresholds: lib/ 60% lines, extensions/ 20% lines
- 250 tests across 19 test files
