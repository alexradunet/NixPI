# Service Architecture

> 📖 [Emoji Legend](LEGEND.md)

Audience: maintainers and operators deciding how Bloom capabilities should be packaged.

## 🌱 Why This Capability Model Exists

Bloom uses multiple mechanisms because not every problem should become a runtime tool.

The rule is simple: use the lightest mechanism that solves the problem.

## 🧩 How To Choose The Right Layer

| Layer | When to use it | Current examples |
|------|-----------------|------------------|
| 📜 Skill | Pi needs instructions, reference material, or a repeatable procedure | `first-boot`, `recovery`, `self-evolution` |
| 🧩 Extension | Pi needs tools, hooks, commands, or direct session integration | `bloom-os`, `bloom-garden`, `bloom-objects` |
| 📦 Service | a standalone workload should run outside the Pi process | `dufs`, `code-server`, Matrix bridges |

OS-level infrastructure sits beside this model rather than inside it:

- `Bloom Home` on port `8080`
- `bloom-matrix.service`
- `netbird.service`
- `pi-daemon.service`

### Skills

Bundled skill directories in `core/pi-skills/` are seeded into `~/Bloom/Skills/` by `bloom-garden`:

- `first-boot`
- `local-llm`
- `object-store`
- `os-operations`
- `recovery`
- `self-evolution`

### Extensions

Extensions are the Pi-facing integration layer. They register:

- tools
- session hooks
- commands
- resource discovery

Current extension families:

| Extension | Main responsibility |
|-----------|---------------------|
| `bloom-persona` | persona injection, guardrails, compacted context |
| `bloom-localai` | local provider registration |
| `bloom-os` | NixOS updates, local proposal validation, systemd, and health workflows |
| `bloom-episodes` | episodic memory |
| `bloom-objects` | durable object store |
| `bloom-garden` | Bloom directory bootstrap, status, and blueprint seeding |
| `bloom-setup` | persona-step progress after the first-boot wizard |

### Service Packages

Service packages are optional workload assets shipped in `services/`.

Typical package:

```text
services/{name}/
  SKILL.md
  quadlet/
    bloom-{name}.container
  Containerfile          optional, required for locally built images
```

These packages remain in-tree as reference assets, examples, and image inputs. Bloom no longer ships a default TypeScript runtime extension for installing, reconciling, or bridging them on-node.

## 📦 Reference

Bundled packages:

| Package | Image source | Notes |
|---------|--------------|-------|
| `fluffychat` | local image `localhost/bloom-fluffychat:latest` | optional Bloom Web Chat client built from a pinned FluffyChat release and exposed on port `8081` |
| `dufs` | pinned upstream image | packaged WebDAV file server on port `5000` |
| `code-server` | local image `localhost/bloom-code-server:latest` | built from `services/code-server/Containerfile` and exposed on port `8443` |
| `_template` | scaffold source | basis for new service packages |

Machine-readable catalog:

- `services/catalog.yaml` contains packaged service and bridge metadata

Current bridge names from `services/catalog.yaml`:

- `whatsapp`
- `telegram`
- `signal`

Keep this distinction clear:

- daemon: core platform runtime
- Bloom Home: image-baked access page generated from installed web services
- service packages: optional packaged workloads kept in-tree, outside the default runtime control plane

## 🔗 Related

- [../README.md](../README.md)
- [../AGENTS.md](../AGENTS.md)
- [../services/README.md](../services/README.md)
- [daemon-architecture.md](daemon-architecture.md)
- [supply-chain.md](supply-chain.md)
