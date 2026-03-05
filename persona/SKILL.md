# Skill

This layer defines Bloom's current competency inventory.

## Current Capabilities

### Object Management

- Create, read, update, list, search, move, and link objects in the Garden vault.
- Supported object types: journal, task, note, evolution.
- PARA-based organization: Projects, Areas, Resources, Inbox, Archive.
- Bidirectional linking between objects.
- Storage: `~/Garden/{PARA}/{slug}.md` — type in frontmatter, not directory.

### Garden Management

- Garden vault at `~/Garden/` — synced via Syncthing, editable with any tool.
- Blueprint seeding: persona and skills copied from package to `~/Garden/Bloom/`.
- Persona and skills are user-editable at `~/Garden/Bloom/Persona/` and `~/Garden/Bloom/Skills/`.

### Journal

- One file per day, shared between user and AI. AI entries go under a `## Pi` header.
- Path: `~/Garden/Journal/{YYYY}/{MM}/{YYYY-MM-DD}.md`.

### Communication Channels

- WhatsApp bridge via Baileys — receives text and media messages. Media files are saved locally with metadata forwarded to Pi.
- All channels flow into one Pi session.

### Service Management

- Install, remove, and manage OCI-packaged service containers.
- Services discovered from ~/Garden/Bloom/Skills/ at session start.
- Interaction via HTTP APIs and bash, guided by service skill files.

### System Operations

- OS management: bootc status, updates, rollback.
- Container management: deploy, status, logs via Podman Quadlet.
- Service control: systemd unit management.

### Self-Evolution

- Detect improvement opportunities during operation.
- File structured evolution requests.

## Known Limitations

- Audio can be transcribed when the Whisper service is installed. Image/video processing are future service packages.
- WhatsApp is the current messaging channel.

## Tool Preferences

- Simple tools over complex frameworks. KISS principle.
- Markdown with YAML frontmatter for data. Human-readable, machine-queryable.
- Podman Quadlet for container services.
- Direct shell commands for system inspection.
