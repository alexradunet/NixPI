# Channel Protocol

Bloom uses a JSON-over-TCP bridge protocol for external messaging platforms. Bridges connect to Bloom's channel server as TCP clients.

## Connection

Bridges connect to `localhost:18800` (configurable via `BLOOM_CHANNELS_PORT`).

## Message Format

All messages are newline-delimited JSON (`\n`-terminated).

### Bridge → Bloom

**Register** — Identify the bridge:
```json
{"type": "register", "channel": "whatsapp"}
```

**Message** — Deliver an incoming text message:
```json
{"type": "message", "channel": "whatsapp", "from": "John", "text": "Hello!", "timestamp": 1709568000}
```

**Message with media** — Deliver an incoming media message:
```json
{
  "type": "message",
  "channel": "whatsapp",
  "from": "John",
  "timestamp": 1709568000,
  "media": {
    "kind": "audio",
    "mimetype": "audio/ogg",
    "filepath": "/var/lib/bloom/media/1709568000-abc123.ogg",
    "duration": 15,
    "size": 24576
  }
}
```

Media fields:
- `kind`: `audio`, `image`, `video`, `document`, or `sticker`
- `mimetype`: MIME type of the file
- `filepath`: Absolute path to the saved file
- `duration`: Duration in seconds (audio/video only)
- `size`: File size in bytes
- `caption`: Optional caption text

### Bloom → Bridge

**Status** — Acknowledge registration:
```json
{"type": "status", "connected": true}
```

**Response** — Send a reply to a user:
```json
{"type": "response", "channel": "whatsapp", "to": "John", "text": "Hey John!"}
```

**Send** — Outbound message (via `/wa` command):
```json
{"type": "send", "channel": "whatsapp", "text": "Hello from Bloom"}
```

## Flow

1. Bridge connects via TCP and sends `register`
2. Bloom responds with `status`
3. Bridge forwards incoming messages as `message`
4. Bloom processes and sends `response` back to the bridge
5. User can send outbound via `/wa` command, which sends `send`

## Current Bridges

- **WhatsApp** (Baileys) — connects as `whatsapp` channel, deployed as a Podman Quadlet container
