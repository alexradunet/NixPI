# Bloom

> 📖 [Emoji Legend](docs/LEGEND.md)

Very opinionated NixOS build personally for me and my workflows and how I imagine a PC will be in the future. My goal is to leverage the current AI Agents Technology to build an AI Firsts OS designed specifically for one end user to act like a personal life assistant and knowledge management system.

It is very experimental and I am still currently developing it based on my needs and my own code engineering preferences.

I plan to keep this project as minimal as possible so the end user can evolve the OS through Pi without carrying a large default runtime surface.

## 🌱 Why Bloom Exists

BloomOS packages Pi, host integration, memory, and a small set of packaged workload assets into one self-hosted system.

Bloom exists to give Pi:

- a durable home directory under `~/Bloom/`
- first-class host tools for NixOS workflows
- a local repo proposal workflow for human-reviewed system changes
- a private Matrix-based messaging surface
- a minimal but inspectable operating model based on files, NixOS, and systemd

## 🚀 What Ships Today

Current platform capabilities:

- Bloom directory management and blueprint seeding for `~/Bloom/`
- persona injection, shell guardrails, durable-memory digest injection, and compaction context persistence
- local-only Nix proposal support for checking the seeded repo clone, refreshing `flake.lock`, and validating config before review
- host OS management tools for NixOS updates, systemd, health, and reboot scheduling
- markdown-native durable memory in `~/Bloom/Objects/`
- append-only episodic memory in `~/Bloom/Episodes/`
- a unified Matrix room daemon with synthesized host-agent fallback and optional multi-agent overlays
- proactive daemon jobs for heartbeat and simple cron-style scheduled turns
- a first-boot flow split between a bash wizard and a Pi-guided persona step

## 🧭 Start Here

Choose the entry point that matches your job:

- Maintainers: [ARCHITECTURE.md](ARCHITECTURE.md), [AGENTS.md](AGENTS.md), and [docs/README.md](docs/README.md)
- Operators: [docs/pibloom-setup.md](docs/pibloom-setup.md), [docs/quick_deploy.md](docs/quick_deploy.md), and [docs/live-testing-checklist.md](docs/live-testing-checklist.md)
- Packaged workload work: [docs/service-architecture.md](docs/service-architecture.md) and [services/README.md](services/README.md)

## 💻 Default Install

The base image stays intentionally small.

Installed by default:

- `sshd.service`
- `netbird.service`
- `bloom-matrix.service`
- `pi-daemon.service` after setup once AI auth and defaults are ready

Packaged workload assets kept in-repo:

- `fluffychat`
- `dufs`
- `code-server`
- bridge metadata for `whatsapp`, `telegram`, and `signal`

These remain in-tree as reference workloads and image inputs. Bloom no longer ships a default runtime extension for installing or reconciling them on-node.

## 🌿 Repository Layout

| Path | Purpose |
|------|---------|
| `core/` | Bloom core: OS image, daemon, persona, skills, built-in extensions, and shared runtime code |
| `core/pi-extensions/` | Pi-facing Bloom extensions shipped in the default runtime |
| `services/` | bundled workload packages and static metadata |
| `tests/` | unit, integration, daemon, and extension tests |
| `docs/` | live project documentation |

## 🧩 Capability Model

Bloom extends Pi through three layers:

| Layer | What it is | Typical use |
|------|-------------|-------------|
| 📜 Skill | markdown instructions in `SKILL.md` | procedures, guidance, checklists |
| 🧩 Extension | in-process TypeScript | Pi-facing tools, hooks, commands |
| 📦 Service | packaged workload asset | optional long-running software outside the default Pi runtime |

OS-level infrastructure sits beside those layers:

- `bloom-matrix.service`
- `netbird.service`
- `pi-daemon.service`

See [docs/service-architecture.md](docs/service-architecture.md) for the full capability model.

## 📚 Documentation Map

The documentation system is organized as `Why / How / Reference`.

| Topic | Why | How | Reference |
|------|-----|-----|-----------|
| Docs hub | [docs/README.md](docs/README.md) | [docs/README.md](docs/README.md) | [docs/README.md](docs/README.md) |
| Architecture | [ARCHITECTURE.md](ARCHITECTURE.md) | [ARCHITECTURE.md](ARCHITECTURE.md) | [AGENTS.md](AGENTS.md) |
| Daemon | [docs/daemon-architecture.md](docs/daemon-architecture.md) | [docs/daemon-architecture.md](docs/daemon-architecture.md) | [AGENTS.md](AGENTS.md) |
| Packaged workloads | [docs/service-architecture.md](docs/service-architecture.md) | [services/README.md](services/README.md) | [docs/service-architecture.md](docs/service-architecture.md) |
| Setup / deploy | [docs/pibloom-setup.md](docs/pibloom-setup.md) | [docs/quick_deploy.md](docs/quick_deploy.md) | [docs/live-testing-checklist.md](docs/live-testing-checklist.md) |
| Memory | [docs/memory-model.md](docs/memory-model.md) | [docs/memory-model.md](docs/memory-model.md) | [AGENTS.md](AGENTS.md) |
| Trust / supply chain | [docs/supply-chain.md](docs/supply-chain.md) | [docs/supply-chain.md](docs/supply-chain.md) | [docs/supply-chain.md](docs/supply-chain.md) |
| Contribution workflow | [docs/fleet-pr-workflow.md](docs/fleet-pr-workflow.md) | [docs/fleet-pr-workflow.md](docs/fleet-pr-workflow.md) | [AGENTS.md](AGENTS.md) |

## 🔗 Related

- [docs/README.md](docs/README.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [AGENTS.md](AGENTS.md)
