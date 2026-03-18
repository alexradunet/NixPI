# Supply Chain And Image Policy

> 📖 [Emoji Legend](LEGEND.md)

Audience: maintainers changing packaged images or image trust policy.

## 🌱 Why This Policy Exists

Bloom packages software that runs on user-owned hosts.

Image sourcing rules exist to make package trust decisions explicit and to avoid silent drift from mutable remote tags.

## 🛡️ How The Current Policy Works

For packaged services and bridges, prefer:

1. digests
2. explicit non-`latest` tags

Disallowed by policy for normal remote images:

- implicit `latest`
- `latest*`

This remains the repo policy even though Bloom no longer ships a default runtime scaffolding/install extension.

### Current Exception

`services/catalog.yaml` intentionally includes local-build images such as:

- `code-server` -> `localhost/bloom-code-server:latest`

Reason:

- the workload is built locally from repository source
- the mutable tag refers to a local artifact, not to a remote registry trust decision

### Current Scope

These packages are treated as in-repo workload assets and reference material. Publishing or activating them is a maintainer workflow outside the default Bloom runtime.

## 📚 Reference

Current repo sources of truth:

- `services/catalog.yaml` for packaged service and bridge image refs
- `services/*/quadlet/` for runtime unit behavior
- `flake.nix` and `justfile` for the Bloom OS image

Review checklist:

- are remote runtime images pinned
- are local-image exceptions documented
- do docs describe the current maintainer workflow instead of the removed runtime workflow
- does `services/catalog.yaml` still match the packaged services in the repo

## 🔗 Related

- [service-architecture.md](service-architecture.md)
- [../services/catalog.yaml](../services/catalog.yaml)
