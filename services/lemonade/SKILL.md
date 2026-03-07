---
name: lemonade
version: 0.1.0
description: Local LLM inference and speech-to-text via Lemonade (OpenAI-compatible API)
image: ghcr.io/lemonade-sdk/lemonade-server:latest
---

# Lemonade Service

Local AI server providing LLM inference (llama.cpp) and speech-to-text (whisper.cpp) behind an OpenAI-compatible API. Runs on CPU by default.

## API

OpenAI-compatible endpoint at `http://localhost:8000/api/v1`.

### Chat Completion

```bash
curl -X POST http://localhost:8000/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Transcribe Audio

```bash
curl -X POST http://localhost:8000/api/v1/audio/transcriptions \
  -F "file=@/path/to/audio.ogg" \
  -F "language=en"
```

### List Models

```bash
curl http://localhost:8000/api/v1/models
```

### Health Check

```bash
curl -sf http://localhost:8000/health
```

## Service Control

```bash
systemctl --user start bloom-lemonade.service
systemctl --user status bloom-lemonade
journalctl --user -u bloom-lemonade -f
```

## Notes

- First start downloads models -- may take several minutes depending on connection
- Memory usage: ~2-4GB during inference (CPU mode)
- Audio files from WhatsApp are at `/var/lib/bloom/media/`
- Swappable with Ollama or any OpenAI-compatible server on port 8000
