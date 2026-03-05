---
name: whisper
description: Speech-to-text transcription via faster-whisper (OpenAI-compatible API)
---

# Whisper Service

Transcribes audio files to text using faster-whisper. Runs locally on CPU.

## API

OpenAI-compatible endpoint at `http://localhost:9000`.

### Transcribe Audio

POST http://localhost:9000/v1/audio/transcriptions

```bash
curl -X POST http://localhost:9000/v1/audio/transcriptions \
  -F "file=@/path/to/audio.ogg" \
  -F "language=en"
```

Response: `{ "text": "transcribed text" }`

Supported formats: wav, mp3, ogg, flac, m4a, webm

### Health Check

```bash
curl -sf http://localhost:9000/health
```

## Notes

- First start downloads ~500MB model — may take several minutes
- Memory usage: ~1-2GB during transcription
- Audio files from WhatsApp are at `/var/lib/bloom/media/`
- Model: Systran/faster-whisper-small (CPU int8, optimized for mini-PCs)
