# Synthetic Provider + Crow-4B Local Model Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Synthetic as a cloud LLM provider (API-key auth, free tier) and switch the built-in local model from Qwen3.5-9B to Crow-4B (Opus 4.6 distill) for faster inference on constrained hardware.

**Architecture:** Two independent changes: (1) Install `@benvargas/pi-synthetic-provider` as a Pi package in the OS image so users can access cloud models via Synthetic's OpenAI-compatible API, and (2) replace the 9B local model with Crow-4B-Opus-4.6-Distill (2.71GB Q4_K_M vs ~5.5GB), which is an Opus 4.6 distillation on Qwen 3.5 architecture — better instruction following at half the size.

**Tech Stack:** TypeScript, Pi SDK (`@mariozechner/pi-coding-agent`), llama.cpp, bootc/Containerfile, systemd

---

### Task 1: Install pi-synthetic-provider in the OS image

**Files:**
- Modify: `os/Containerfile:99-105` (global npm install section)
- Modify: `os/Containerfile:122-123` (Pi settings.json)

**Step 1: Add `@benvargas/pi-synthetic-provider` to global npm install**

In `os/Containerfile`, add the package to the global install line (around line 100):

```dockerfile
RUN HOME=/tmp npm install -g --cache /tmp/npm-cache \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @mariozechner/pi-coding-agent@${PI_CODING_AGENT_VERSION} \
    @benvargas/pi-synthetic-provider@latest \
    @biomejs/biome@${BIOME_VERSION} \
    typescript@${TYPESCRIPT_VERSION} \
    && rm -rf /tmp/npm-cache /var/roothome/.npm /root/.npm
```

**Step 2: Add synthetic provider package path to Pi settings**

Update the settings.json line to include the synthetic provider package. First, find the global install path at build time:

```dockerfile
RUN SYNTH_PKG=$(npm root -g)/@benvargas/pi-synthetic-provider && \
    mkdir -p /usr/local/share/bloom/.pi/agent && \
    printf '{"packages": ["/usr/local/share/bloom", "%s"]}' "$SYNTH_PKG" \
    > /usr/local/share/bloom/.pi/agent/settings.json
```

**Step 3: Verify the install works**

Run: `npm run build`
Expected: Build succeeds (no source changes needed — this is OS-level only)

**Step 4: Commit**

```bash
git add os/Containerfile
git commit -m "feat(os): add pi-synthetic-provider for cloud model access"
```

---

### Task 2: Switch local model from Qwen3.5-9B to Crow-4B

**Files:**
- Modify: `os/Containerfile:78-82` (model download)
- Modify: `os/sysconfig/bloom-llm-local.service` (service description + model path)
- Modify: `extensions/bloom-setup/index.ts:20-36` (provider registration)

**Step 1: Update model download in Containerfile**

Replace the Qwen3.5-9B download (lines 78-82) with Crow-4B:

```dockerfile
# Download Crow-4B GGUF model (4B params — Opus 4.6 distill on Qwen3.5, fast + smart)
RUN mkdir -p /usr/local/share/bloom/models && \
    curl -L "https://huggingface.co/crownelius/Crow-4B-Opus-4.6-Distill-Heretic_Qwen3.5/resolve/main/Crow-4B-Opus-4.6-Distill-Heretic_Qwen3.5.Q4_K_M.gguf" \
    -o /usr/local/share/bloom/models/crow-4b.gguf && \
    chown llm:llm /usr/local/share/bloom/models/crow-4b.gguf
```

**Step 2: Update systemd service**

In `os/sysconfig/bloom-llm-local.service`, update the description and model path:

```ini
[Unit]
Description=Bloom Local LLM (llama.cpp + Crow-4B Opus Distill)
After=network.target
Before=getty@tty1.service

[Service]
Type=simple
User=llm
Group=llm
ExecStart=/usr/local/bin/llama-server \
    --model /usr/local/share/bloom/models/crow-4b.gguf \
    --host 127.0.0.1 \
    --port 8080 \
    --ctx-size 8192 \
    --threads 4 \
    --no-mmap \
    --chat-template chatml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Step 3: Update provider registration in bloom-setup extension**

In `extensions/bloom-setup/index.ts`, update the model registration:

```typescript
pi.registerProvider("bloom-local", {
    baseUrl: "http://localhost:8080/v1",
    apiKey: "local",
    api: "openai-completions",
    models: [
        {
            id: "crow-4b",
            name: "Crow 4B (local, Opus distill)",
            reasoning: true,
            input: ["text"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 131072,
            maxTokens: 8192,
        },
    ],
});
```

**Step 4: Run tests**

Run: `npm run test`
Expected: All 283 tests pass (no test references the model ID directly)

**Step 5: Commit**

```bash
git add os/Containerfile os/sysconfig/bloom-llm-local.service extensions/bloom-setup/index.ts
git commit -m "feat(os): switch to Crow-4B Opus distill for faster local inference"
```

---

### Task 3: Update first-boot flow for new model name

**Files:**
- Modify: `os/sysconfig/bloom-bash_profile:18` (pi --model flag)
- Modify: `extensions/bloom-setup/index.ts:2` (comment fix)

**Step 1: Update bash_profile model reference**

In `os/sysconfig/bloom-bash_profile`, change the model flag on line 18:

```bash
    exec pi --provider bloom-local --model crow-4b "hello"
```

**Step 2: Fix comment in index.ts**

Line 20 still says "Qwen3.5-4B" — update:

```typescript
// Register local LLM provider (bundled Crow-4B Opus distill via llama.cpp)
```

**Step 3: Run lint**

Run: `npm run check`
Expected: No lint errors

**Step 4: Commit**

```bash
git add os/sysconfig/bloom-bash_profile extensions/bloom-setup/index.ts
git commit -m "fix(setup): update first-boot to use crow-4b model name"
```

---

### Task 4: Update setup wizard llm_upgrade guidance to mention Synthetic

**Files:**
- Modify: `extensions/bloom-setup/actions.ts:40-41` (llm_upgrade step guidance)

**Step 1: Update the llm_upgrade guidance text**

In `extensions/bloom-setup/actions.ts`, replace the `llm_upgrade` guidance:

```typescript
llm_upgrade:
    "Explain: 'You're running on a local model right now. For much better reasoning, let's connect a cloud AI provider.' Guide them through the options: (1) **Synthetic (free tier)**: Run /model and pick a Synthetic model — models like Kimi K2.5 and MiniMax M2.5 are available for free. They just need to sign up at synthetic.new and add their API key. (2) **Anthropic/OpenAI/Google**: Run /login to sign in via OAuth, then /model to pick Claude Sonnet, GPT-4o, etc. (3) **API keys**: If they prefer, help set ANTHROPIC_API_KEY or OPENAI_API_KEY in ~/.bashrc. (4) **Stay local**: The bundled Crow-4B keeps running — that's fine too.",
```

**Step 2: Run tests**

Run: `npm run test`
Expected: All tests pass

**Step 3: Commit**

```bash
git add extensions/bloom-setup/actions.ts
git commit -m "docs(setup): update llm_upgrade guidance to mention Synthetic provider"
```

---

### Task 5: Build verification

**Step 1: Run full check suite**

```bash
npm run check
npm run test
```

Expected: All pass

**Step 2: Verify Containerfile syntax**

```bash
podman build --dry-run -f os/Containerfile . 2>&1 | head -5
```

Or just verify no syntax errors by reading the file.

**Step 3: Final commit (if any fixups needed)**

---

## Summary of changes

| What | Before | After |
|------|--------|-------|
| Local model | Qwen3.5-9B Q4_K_M (~5.5GB) | Crow-4B Q4_K_M (2.71GB) |
| Local model quality | Base Qwen3.5 | Opus 4.6 distilled |
| Cloud provider | None (just `/login` OAuth) | Synthetic pre-installed + OAuth |
| Image size delta | — | ~-2.8GB (smaller model) |
| Inference speed | Slow on N150 | ~2x faster (half params) |
