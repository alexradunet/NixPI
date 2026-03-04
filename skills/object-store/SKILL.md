---
name: object-store
description: Create, read, update, search, move, and link objects in the Garden vault
---

# Object Store Skill

Use this skill when the user wants to create, read, update, search, move, or link any type of object in Bloom's Garden vault.

## Storage Model

Every object is a Markdown file with YAML frontmatter stored in the Garden vault:
```
~/Garden/{PARA category}/{slug}.md
```

Objects are organized using PARA methodology. The type lives in frontmatter, not in the directory structure.

### PARA Routing

| Field | Target Directory |
|-------|-----------------|
| `project: home-renovation` | `~/Garden/Projects/home-renovation/{slug}.md` |
| `area: health` | `~/Garden/Areas/health/{slug}.md` |
| *(neither)* | `~/Garden/Inbox/{slug}.md` |
| *(archived)* | `~/Garden/Archive/{slug}.md` |

### Core frontmatter fields

- `type`: object type (e.g. `task`, `journal`, `note`)
- `slug`: kebab-case unique identifier within the type
- `title`: human-readable name
- `project`: active project name (routes to Projects/)
- `area`: ongoing area of responsibility (routes to Areas/)
- `origin`: `pi` for AI-created, `user` for human-created
- `created`: ISO timestamp (set automatically)
- `modified`: ISO timestamp (updated automatically)
- `tags`: comma-separated labels
- `links`: references to related objects in `type/slug` format

### Object types

| Type | Purpose |
|------|---------|
| `journal` | Daily entries, reflections, logs |
| `task` | Actionable items with status and priority |
| `note` | Reference notes, permanent records |
| *(custom)* | Any type the user or agent defines |

## Available Tools

### Object Tools

- `memory_create` — Create a new object with type, slug, and fields. Routed to PARA dir based on project/area.
- `memory_read` — Read an object by type and slug (searches all PARA dirs).
- `memory_list` — List objects, filtered by type, PARA category, or frontmatter fields.
- `memory_search` — Search objects by content pattern across all PARA dirs.
- `memory_link` — Create bidirectional links between objects.
- `memory_move` — Relocate an object between PARA categories (project, area, inbox, archive).
- `garden_reindex` — Rebuild the in-memory index after external file changes.

### Journal Tools

- `journal_write` — Write a daily journal entry. AI entries get `.pi.md` suffix.
- `journal_read` — Read journal entries for a date (user + AI).

Journal path: `~/Garden/Journal/{YYYY}/{MM}/{YYYY-MM-DD}.md` (user) or `{YYYY-MM-DD}.pi.md` (AI).

### Garden Tools

- `garden_status` — Show vault location, file counts, and blueprint state.
- `/garden init` — Initialize or re-initialize the Garden vault.
- `/garden update-blueprints` — Apply pending blueprint updates from package.

## When to Use Each Tool

| Situation | Tool |
|-----------|------|
| User mentions something new to track | `memory_create` |
| User asks about a specific item | `memory_read` |
| User wants to see items of a type | `memory_list` |
| User remembers content but not the name | `memory_search` |
| Two objects are related | `memory_link` |
| Object should move to a different project/area | `memory_move` |
| Daily reflection or observation | `journal_write` |
| Review what happened on a day | `journal_read` |
| Files added outside Pi | `garden_reindex` |

## Behavior Guidelines

- Always set `title` when creating objects.
- Suggest PARA fields (`project`, `area`) when the user hasn't provided them.
- Prefer update over create when an object already exists.
- After search, offer to read matched objects.
- Use link proactively when connections are mentioned.
- The Garden vault is synced via Syncthing — files may be edited externally.
