---
name: first-boot
description: Guides first-time setup of a Bloom OS installation
---

# First-Boot Setup

Use this skill on the first session after a fresh Bloom OS install.

## Prerequisite Check

If `~/.bloom/.setup-complete` exists, setup is already complete. Skip unless user asks to re-run specific steps.

## Setup Style

- Be conversational (one step at a time)
- Let user skip/defer steps
- Prefer Bloom tools over long shell copy-paste blocks
- Clarify tool-vs-shell: `service_install`, `bloom_repo`, etc. are Pi tools (not bash commands)
- On fresh Bloom OS, user `bloom` has passwordless `sudo` for bootstrap tasks.

## Setup Steps

### 1) NetBird Mesh Networking

Check connection status:

```bash
sudo netbird status
```

If not connected, ask the user for their NetBird setup key (from https://app.netbird.io > Setup Keys):

```bash
sudo netbird up --setup-key "<key>"
```

Poll until connected:

```bash
sudo netbird status
```

Look for "Connected" in the output. The user can skip this step and connect later with `sudo netbird up`.

### 2) Git Identity

Ask the user for their name and email, then set globally:

```bash
git config --global user.name "<name>"
git config --global user.email "<email>"
```

### 3) dufs Setup

- Install service package: `service_install(name="dufs", version="0.1.0")`
- Validate service: `service_test(name="dufs")`
- The WebDAV password is the channel token in `~/.config/bloom/channel-tokens/dufs.env` (BLOOM_CHANNEL_TOKEN)
- Direct user to `http://localhost:5000` (username: `admin`)
- dufs serves `$HOME` over WebDAV

If Bloom runs inside a VM, offer access paths:
- QEMU port forward: host `localhost:5000` -> guest `5000`
- SSH tunnel: `ssh -L 5000:localhost:5000 -p 2222 bloom@localhost`

### 4) Optional Services

#### WhatsApp Bridge

- Install: `service_install(name="whatsapp")`
  - This auto-installs STT (whisper.cpp) as a dependency
- Pair: `service_pair(name="whatsapp")` — displays QR code inline, scan with WhatsApp mobile app
- Verify: `service_test(name="whatsapp")`

#### Signal Bridge

- Ask the user for their phone number (E.164 format, e.g. +40749588297)
- Create config: write `SIGNAL_ACCOUNT=+<number>` to `~/.config/bloom/signal.env`
- Install: `service_install(name="signal")`
  - This auto-installs STT (whisper.cpp) as a dependency
- Pair: `service_pair(name="signal")` — displays QR code inline, scan with Signal mobile app (Settings > Linked Devices > Link New Device)
- Verify: `service_test(name="signal")`

#### LLM (optional, local language model)

- Install: `service_install(name="llm", version="0.1.0")`
- Note: requires a GGUF model file in the `bloom-llm-models` volume
- API at `http://localhost:8080` (OpenAI-compatible)

### 5) Mark Setup Complete

```bash
touch ~/.bloom/.setup-complete
```

## Notes

- Revisit skipped steps on demand
- Confirm each critical step before moving on
