---
name: self-evolution
description: Detect improvement opportunities and propose system changes through a structured evolution workflow
---

# Self-Evolution Skill

Use this skill when Bloom detects a capability gap or the user requests a system change.

## Choosing the Right Mechanism

When extending capabilities, prefer the lightest option: **Skill → Extension → Service**.

| Need | Mechanism | Example |
|------|-----------|---------|
| Pi needs knowledge or a procedure | **Skill** — create a SKILL.md | Meal planning guide, API reference |
| Pi needs commands, tools, or session hooks | **Extension** — TypeScript (requires PR) | New Pi command, event handler |
| Standalone workload needing isolation | **Service** — OCI container package | ML model, messaging bridge, VPN |

## Evolution Workflow

1. **Detect**: Recognize a capability gap or improvement opportunity
2. **Propose**: Create an evolution object using `persona_evolve` or `memory_create`
3. **Plan**: Design the implementation approach
4. **Implement**: Make the changes (create skills with `skill_create`, update persona with `persona_evolve`)
5. **Verify**: Test and validate
6. **Apply**: Deploy with user approval

## Available Tools

### Skill Self-Creation
- `skill_create` — Create a new skill in `~/Garden/Bloom/Skills/` with proper frontmatter
- `skill_list` — List all skills currently in the Garden vault

### Persona Evolution
- `persona_evolve` — Propose a change to a persona layer (SOUL, BODY, FACULTY, SKILL), tracked as an evolution object requiring user approval

### Object Store (for tracking)
- `memory_create` — Create evolution tracking objects
- `memory_read` — Read evolution details
- `memory_search` — Find existing evolutions

## Creating a Skill

```
skill_create(
  name: "meal-planning",
  description: "Help plan weekly meals based on preferences and schedule",
  content: "# Meal Planning\n\nUse this skill when..."
)
```

Skills are automatically discovered from `~/Garden/Bloom/Skills/` at session start.

## Proposing a Persona Change

```
persona_evolve(
  layer: "SKILL",
  slug: "add-health-tracking",
  title: "Add health tracking capability",
  proposal: "Add health tracking to the SKILL layer..."
)
```

Evolution objects are stored at `~/Garden/Bloom/Evolutions/{slug}.pi.md`.

## Evolution Object Fields

- `status`: proposed | planning | implementing | reviewing | approved | applied | rejected
- `risk`: low | medium | high
- `area`: objects | persona | skills | containers | system

## Safety Rules

- All system changes require user approval before applying
- Always test changes before deploying
- Document what each evolution changes and why
- Keep a rollback plan for container changes
- Persona changes are tracked as evolution objects — never modify persona files directly

## Code Evolution Workflow

When Bloom identifies a code-level fix or improvement to its own OS/extensions, use this workflow to propose changes upstream via pull request.

**Repo path**: `~/.bloom/pibloom` (cloned during first-boot setup)

### Process

1. **Detect** — Identify a bug, config issue, or improvement opportunity
2. **Plan** — Design the fix; document what and why
3. **Branch** — Create a feature branch from `main`:
   - `bloom/fix-*` for bug fixes
   - `bloom/feat-*` for new features
   - `bloom/config-*` for configuration changes
4. **Implement** — Make changes in the local clone
5. **Commit** — Use conventional commits:
   - `fix:` bug fixes
   - `feat:` new features
   - `refactor:` code restructuring
   - `docs:` documentation changes
6. **Push** — Push the branch to origin
7. **PR** — Open a pull request using `gh pr create`
8. **Notify** — Tell the user about the PR and wait for their review

### Safety

- **Never** push directly to `main` — always use a PR
- **Never** force-push
- **Always** test changes before committing (run `npm run build && npm run check` in the repo)
- PRs require human merge — Bloom proposes, the user decides
- Use `bloom_repo_status` to verify repo state before starting

## Adding a Service Package

When Bloom identifies a need for a new containerized service, follow this workflow to create and distribute it as an OCI artifact.

### Directory Convention

```
services/{name}/
├── quadlet/
│   ├── bloom-{name}.container    # Podman Quadlet container unit
│   └── bloom-{name}-*.volume     # Optional volume definitions
└── SKILL.md                      # Pi skill file (frontmatter + docs)
```

### Quadlet Conventions

- Container name: `bloom-{name}`
- Network: `host`
- Health checks: required (`HealthCmd`, `HealthInterval`, `HealthRetries`)
- Logging: `LogDriver=journald`
- Security: `NoNewPrivileges=true` minimum
- Restart: `on-failure` with `RestartSec=10`

### Port Allocation

| Port | Service |
|------|---------|
| 9000 | Whisper (speech-to-text) |

### SKILL.md Format

Include frontmatter with `name` and `description`, then document:
- What the service does
- API endpoints (if any)
- Setup instructions
- Common commands
- Troubleshooting

### Publishing

```bash
# Push to GHCR as OCI artifact
just svc-push {name}

# Test installation locally
just svc-install {name}
```

### Testing

1. Create the service directory with quadlet + SKILL.md
2. Test locally: copy quadlet files to `~/.config/containers/systemd/`, run `systemctl --user daemon-reload && systemctl --user start bloom-{name}`
3. Verify health: `systemctl --user status bloom-{name}`
4. Push to registry: `just svc-push {name}`
