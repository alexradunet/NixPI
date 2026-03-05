---
name: first-boot
description: Guide the user through one-time Bloom system setup on a fresh install
---

# First-Boot Setup

Use this skill on the first session after a fresh Bloom OS install to configure all required services.

## Prerequisites

Check for the setup marker file `~/.bloom/.setup-complete`. If it exists, setup is already done — skip this skill.

## Setup Steps

Walk the user through each step conversationally. Skip steps they've already completed or don't want.

### 1. LLM API Key

Configure the API key for Pi's language model provider:
- Ask which provider (Anthropic, OpenAI, etc.)
- Help set the key in Pi's settings

### 2. GitHub Authentication

Authenticate with GitHub so Bloom can open pull requests for self-evolution:

```bash
gh auth login
```

Follow the interactive flow (browser-based or token). Verify with `gh auth status`.

### 3. Git Configuration

Set identity for commits:

```bash
git config --global user.name "Bloom"
git config --global user.email "bloom@localhost"
```

Ask the user if they want a custom name/email.

### 4. Clone Bloom Repository

Clone the source repo for self-evolution capabilities:

```bash
mkdir -p ~/.bloom
```

Detect the repo URL automatically:
- Run `bootc status --json` and extract the source image reference
- Parse the GitHub owner from the image URL (e.g., `ghcr.io/owner/bloom-os` → `owner`)
- Clone from `https://github.com/{owner}/pibloom.git`

If auto-detection fails, ask the user for their fork URL.

```bash
git clone https://github.com/{owner}/pibloom.git ~/.bloom/pibloom
```

### 5. Syncthing Setup

Syncthing syncs the Garden vault across devices:

- Verify syncthing is running: `systemctl status syncthing@bloom`
- Direct user to the web UI: `http://localhost:8384`
- Help add the `~/Garden` folder for sharing
- Help connect to other devices (share device IDs)

### 6. Service Packages (Optional)

Install desired service packages via `oras`:

**WhatsApp Bridge** — messaging integration:
```bash
mkdir -p /tmp/bloom-svc
oras pull ghcr.io/alexradunet/bloom-svc-whatsapp:latest -o /tmp/bloom-svc/
cp /tmp/bloom-svc/quadlet/* ~/.config/containers/systemd/
mkdir -p ~/Garden/Bloom/Skills/whatsapp
cp /tmp/bloom-svc/SKILL.md ~/Garden/Bloom/Skills/whatsapp/SKILL.md
systemctl --user daemon-reload
systemctl --user start bloom-whatsapp
rm -rf /tmp/bloom-svc
```
Then guide through QR code pairing: `journalctl --user -u bloom-whatsapp -f`

**Whisper** — speech-to-text transcription (recommended with WhatsApp):
```bash
mkdir -p /tmp/bloom-svc
oras pull ghcr.io/alexradunet/bloom-svc-whisper:latest -o /tmp/bloom-svc/
cp /tmp/bloom-svc/quadlet/* ~/.config/containers/systemd/
mkdir -p ~/Garden/Bloom/Skills/whisper
cp /tmp/bloom-svc/SKILL.md ~/Garden/Bloom/Skills/whisper/SKILL.md
systemctl --user daemon-reload
systemctl --user start bloom-whisper
rm -rf /tmp/bloom-svc
```

**Tailscale** — secure remote access:
```bash
mkdir -p /tmp/bloom-svc
oras pull ghcr.io/alexradunet/bloom-svc-tailscale:latest -o /tmp/bloom-svc/
cp /tmp/bloom-svc/quadlet/* ~/.config/containers/systemd/
mkdir -p ~/Garden/Bloom/Skills/tailscale
cp /tmp/bloom-svc/SKILL.md ~/Garden/Bloom/Skills/tailscale/SKILL.md
systemctl --user daemon-reload
systemctl --user start bloom-tailscale
rm -rf /tmp/bloom-svc
```
Then authenticate: `podman exec bloom-tailscale tailscale up`

### 7. Mark Setup Complete

After all desired steps are done:

```bash
touch ~/.bloom/.setup-complete
```

## Notes

- Be conversational — don't dump all steps at once
- Let the user skip or defer any step
- Revisit skipped steps if the user asks later
