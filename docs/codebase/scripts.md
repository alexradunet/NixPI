# Scripts & Tools

> Setup orchestration and local VM helpers

## Responsibilities

There are only two script areas that matter:

- `core/scripts/setup-wizard.sh` for first-boot orchestration
- `core/scripts/setup-lib.sh` for shared setup side effects
- `tools/run-qemu.sh` for local VM execution

## Cleanup rule

Keep setup logic split by responsibility, not by historical flow:

- `setup-wizard.sh` should own prompts, sequencing, and resume behavior
- `setup-lib.sh` should own reusable helper actions
- VM helpers should not embed product logic

First boot is now a single flow:

1. Login shell launches `setup-wizard.sh` until `~/.nixpi/.setup-complete` exists
2. Wizard handles password, network, Matrix, AI setup, and service refresh
3. Persona completion is tracked only by `~/.nixpi/wizard-state/persona-done`

---

## 📋 When to Run Scripts

| Script | Safe to Run | When |
|--------|-------------|------|
| `setup-wizard.sh` | Production | First boot only |
| `run-qemu.sh` | Development | Anytime for testing |

---

## 🔗 Related

- [Operations: Quick Deploy](../operations/quick-deploy) - Deployment procedures
- [Operations: First Boot](../operations/first-boot-setup) - Setup procedures
- [Tests](./tests) - Testing documentation
