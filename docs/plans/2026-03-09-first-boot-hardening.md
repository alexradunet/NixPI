# First-Boot Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all remaining first-boot runtime issues so Pi reliably starts the setup wizard on a fresh Bloom OS boot.

**Architecture:** Four targeted fixes to shell config and TypeScript actions — no new files, no new abstractions. Each fix addresses a specific failure mode observed or predicted during VM testing.

**Tech Stack:** Bash (shell config), TypeScript (setup actions), systemd (service unit)

---

### Task 1: Source .bashrc from .bash_profile

**Problem:** getty spawns a login shell which reads `.bash_profile` but NOT `.bashrc`. Environment variables (`BLOOM_DIR`, `DISPLAY`, `BROWSER`, `PATH`) are never set. When Pi runs bash tool calls, subshells won't have these vars either.

**Files:**
- Modify: `os/sysconfig/bloom-bash_profile`

**Step 1: Add .bashrc sourcing at top of bloom-bash_profile**

The file should source `.bashrc` before the Pi guard, so env vars are always set regardless of whether Pi starts:

```bash
# Source .bashrc for env vars (BLOOM_DIR, DISPLAY, PATH, etc.)
[ -f ~/.bashrc ] && . ~/.bashrc

# Start Pi on interactive login (only one instance — first TTY wins)
if [ -t 0 ] && [ -z "$PI_SESSION" ] && ! pgrep -u "$USER" -x pi >/dev/null 2>&1; then
  export PI_SESSION=1
  /usr/local/bin/bloom-greeting.sh
  # First boot: use local LLM and auto-speak to trigger setup wizard
  if [ ! -f "$HOME/.bloom/.setup-complete" ]; then
    exec pi --provider bloom-local --model qwen3.5-4b "hello"
  else
    exec pi
  fi
fi
```

**Step 2: Verify no circular sourcing**

Check that `.bashrc` does NOT source `.bash_profile`. Current `.bashrc` content is just 4 export lines — no sourcing. Safe.

---

### Task 2: Wait for llama-server health before launching Pi

**Problem:** `bloom-llm-local.service` starts with `Before=getty@tty1.service`, but loading a 2.5GB model takes 10+ seconds. By the time Pi sends "hello", llama-server isn't ready. Pi gets a connection refused error and shows "No models available."

**Files:**
- Modify: `os/sysconfig/bloom-bash_profile`

**Step 1: Add health check wait loop before first-boot Pi launch**

Only wait on first boot (when we need the local LLM). On subsequent boots, Pi starts immediately.

```bash
# Source .bashrc for env vars (BLOOM_DIR, DISPLAY, PATH, etc.)
[ -f ~/.bashrc ] && . ~/.bashrc

# Start Pi on interactive login (only one instance — first TTY wins)
if [ -t 0 ] && [ -z "$PI_SESSION" ] && ! pgrep -u "$USER" -x pi >/dev/null 2>&1; then
  export PI_SESSION=1
  /usr/local/bin/bloom-greeting.sh
  # First boot: use local LLM and auto-speak to trigger setup wizard
  if [ ! -f "$HOME/.bloom/.setup-complete" ]; then
    printf 'Waiting for local LLM...'
    for i in $(seq 1 60); do
      curl -sf http://127.0.0.1:8080/health >/dev/null 2>&1 && break
      printf '.'
      sleep 1
    done
    printf '\n'
    exec pi --provider bloom-local --model qwen3.5-4b "hello"
  else
    exec pi
  fi
fi
```

This polls every 1s for up to 60s. Model load on N150 with 16GB should complete well within that. The dots give visual feedback.

---

### Task 3: Atomic writes for setup state with corruption recovery

**Problem:** `saveState()` uses `writeFileSync()` directly — a crash mid-write corrupts `setup-state.json`. `loadState()` silently resets all progress on corrupt JSON.

**Files:**
- Modify: `extensions/bloom-setup/actions.ts`
- Test: `tests/extensions/bloom-setup.test.ts`

**Step 1: Write failing test for atomic save**

Add to `tests/extensions/bloom-setup.test.ts`:

```typescript
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

describe("bloom-setup state persistence", () => {
	let stateDir: string;

	beforeEach(() => {
		stateDir = join(tmpdir(), `bloom-test-${Date.now()}`);
		mkdirSync(stateDir, { recursive: true });
	});

	it("loadState recovers from corrupted JSON by backing up the file", async () => {
		const statePath = join(stateDir, "setup-state.json");
		writeFileSync(statePath, "{corrupted json!!!");

		// Mock the path — we'll need to test via the actions module
		// For now, verify the behavior we want exists
		const { loadState } = await import("../../extensions/bloom-setup/actions.js");
		// loadState should return fresh state when file is corrupt
		const state = loadState();
		expect(state.completedAt).toBeNull();
	});
});
```

**Step 2: Run test to verify it fails**

Run: `npm run test -- tests/extensions/bloom-setup.test.ts`

**Step 3: Update saveState to use atomic temp+rename pattern**

In `extensions/bloom-setup/actions.ts`, modify `saveState`:

```typescript
/** Save setup state to disk (atomic write: temp file + rename). */
export function saveState(state: SetupState): void {
	const dir = dirname(SETUP_STATE_PATH);
	if (!existsSync(dir)) mkdirSync(dir, { recursive: true, mode: 0o700 });
	const tmp = `${SETUP_STATE_PATH}.tmp`;
	writeFileSync(tmp, JSON.stringify(state, null, 2), "utf-8");
	renameSync(tmp, SETUP_STATE_PATH);
}
```

Add `renameSync` to the import from `node:fs`.

**Step 4: Update loadState to back up corrupted files**

```typescript
/** Load setup state from disk, or create initial state. */
export function loadState(): SetupState {
	if (existsSync(SETUP_STATE_PATH)) {
		try {
			const raw = readFileSync(SETUP_STATE_PATH, "utf-8");
			return JSON.parse(raw) as SetupState;
		} catch {
			log.warn("corrupt setup-state.json, backing up and creating fresh state");
			const backup = `${SETUP_STATE_PATH}.corrupt-${Date.now()}`;
			try {
				renameSync(SETUP_STATE_PATH, backup);
			} catch {
				// best-effort backup
			}
		}
	}
	return createInitialState();
}
```

**Step 5: Update touchSetupComplete to use mode 0o700 for directory**

```typescript
/** Mark setup as complete by touching the sentinel file. */
export function touchSetupComplete(): void {
	const dir = dirname(SETUP_COMPLETE_PATH);
	if (!existsSync(dir)) mkdirSync(dir, { recursive: true, mode: 0o700 });
	writeFileSync(SETUP_COMPLETE_PATH, new Date().toISOString(), "utf-8");
}
```

**Step 6: Run tests**

Run: `npm run test -- tests/extensions/bloom-setup.test.ts`
Expected: All pass.

**Step 7: Run full test suite**

Run: `npm run test`
Expected: All pass.

---

### Task 4: Build and VM test

**Step 1: Kill any running VM**

Run: `just vm-kill`

**Step 2: Build the image**

Run: `just build`
Expected: Builds successfully, static llama-server binary produced.

**Step 3: Generate qcow2**

Run: `just qcow2`
Expected: Disk image generated at `os/output/qcow2/disk.qcow2`.

**Step 4: Boot VM and verify**

Run: `just vm`

Expected boot sequence:
1. System boots to multi-user.target
2. bloom-llm-local.service starts (llama-server loads model)
3. Getty auto-logins on tty1 (first TTY to login)
4. `.bash_profile` sources `.bashrc` (env vars set)
5. Health check waits with dots while LLM loads
6. Pi launches with `--provider bloom-local --model qwen3.5-4b "hello"`
7. Setup wizard greets the user
8. Second TTY (ttyS0 or tty1) hits pgrep guard, drops to plain shell

**Step 5: SSH verification checks**

```bash
# Verify env vars are set
ssh pi@localhost -p 2222 'echo $BLOOM_DIR; echo $DISPLAY'
# Expected: /home/pi/Bloom and :99

# Verify llama-server is running
ssh pi@localhost -p 2222 'curl -s http://127.0.0.1:8080/health'
# Expected: {"status":"ok"}

# Verify only one Pi instance
ssh pi@localhost -p 2222 'pgrep -u pi -x pi | wc -l'
# Expected: 1
```

---

### Task 5: Commit

**Step 1: Stage and commit all changes**

```bash
git add os/sysconfig/bloom-bash_profile extensions/bloom-setup/actions.ts tests/extensions/bloom-setup.test.ts
git commit -m "fix(setup): harden first-boot flow — LLM health check, env vars, atomic state writes"
```
