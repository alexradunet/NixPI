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
| Standalone workload needing isolation | **Service** — Container (Podman Quadlet) | ML model, messaging bridge, VPN |

## Evolution Workflow

1. **Detect**: Recognize a capability gap or improvement opportunity
2. **Propose**: Create an evolution object using `memory_create`
3. **Plan**: Design the implementation approach
4. **Implement**: Make the changes locally in the repo or Bloom directory
5. **Verify**: Test and validate
6. **Review**: Have the human inspect the resulting diff before any external publish

## Available Tools

### Object Store (for tracking)
- `memory_create` — Create evolution tracking objects
- `memory_read` — Read evolution details
- `memory_search` — Find existing evolutions

## Evolution Object Fields

- `status`: proposed | planning | implementing | reviewing | approved | applied | rejected
- `risk`: low | medium | high
- `area`: objects | persona | skills | services | system

## Safety Rules

- All system changes require user approval before applying
- Always test changes before deploying
- Document what each evolution changes and why
- Keep a rollback plan for NixOS and service changes
- Persona changes are tracked as evolution objects — never modify persona files directly

## Code Evolution Workflow

When Bloom identifies a code-level fix or improvement to its own OS/extensions, it should prepare the change locally for human review.

**Local repo path**: `~/.bloom/pi-bloom`

### Process

1. **Detect + Plan**
   - Describe the issue and proposed fix in plain language.
2. **Implement locally**
   - Edit the local repo or Bloom files.
3. **Validate**
   - Run local checks such as `npm run build`, `npm run test:unit`, `npm run test:integration`, and `npm run test:e2e` when relevant.
4. **Prepare review**
   - Summarize the diff and the validation results.
5. **Human review**
   - The user reviews the local diff in VS Code or another editor.
6. **External publish**
   - Commit, push, PR creation, merge, and rollout happen outside Bloom.

### Safety

- Bloom prepares local proposals only
- remote publish is always human- or controller-driven
- rollout is always external to the node

## Adding a Service Package

When Bloom identifies a need for a new packaged workload, treat it as maintainer-side package work rather than default runtime behavior.

If the new service exposes a browser or HTTP UI, treat it as a Bloom Home entry as well: scaffold it with `web_service=true` and include the Home metadata (`title`, `icon_text`, `path_hint`, `access_path`) so the built-in landing page advertises it after install.

### Directory Convention

```
services/{name}/
├── quadlet/
│   ├── bloom-{name}.container    # Podman Quadlet container unit
│   ├── bloom-{name}.socket       # Optional socket activation unit
│   └── bloom-{name}-*.volume     # Optional volume definitions
└── SKILL.md                      # Pi skill file (frontmatter + docs)
```

### Quadlet Conventions

- Container name: `bloom-{name}`
- Network: host networking
- Health checks: required (`HealthCmd`, `HealthInterval`, `HealthRetries`)
- Logging: `LogDriver=journald`
- Security: `NoNewPrivileges=true` minimum
- Restart: `on-failure` with `RestartSec=10`
- Optional: `.socket` unit for on-demand activation

### SKILL.md Format

Include frontmatter with `name` and `description`, then document:
- What the service does
- API endpoints (if any)
- Setup instructions
- Common commands
- Troubleshooting

### Installation

```bash
# Install from local package
systemctl --user daemon-reload
systemctl --user start bloom-{name}
```

### Testing

1. Create the service directory with quadlet + SKILL.md
2. Test locally: copy quadlet files to `~/.config/containers/systemd/`, run `systemctl --user daemon-reload && systemctl --user start bloom-{name}`
3. Verify health: `systemctl --user status bloom-{name}`

Reference package:
- `services/dufs/quadlet/` (production HTTP service reference)

### Maintainer Workflow

Use direct repo edits and local testing for service work, then hand the resulting diff to the human for review and external publish.
