# Bloom Service Packages

This document is the reference inventory for bundled workload assets kept in-tree.

## 🌱 Why This Page Exists

Use this page when you need the current packaged workload inventory and the practical layout of those packages.

For capability-model decisions, use [../docs/service-architecture.md](../docs/service-architecture.md).

## 📦 How Bundled Packages Are Stored

Bundled service packages live in `services/`.

Typical package:

```text
services/{name}/
  SKILL.md
  quadlet/
    bloom-{name}.container
  Containerfile     optional, for locally built images
```

Bloom no longer ships a default runtime extension that installs these packages on-node. They remain in-tree as:

1. reference workloads
2. image/build inputs
3. examples for future maintainer-side packaging work

## 📚 Reference

Current packages:

| Path | Role |
|------|------|
| `services/fluffychat/` | packaged Bloom Web Chat client built locally from a pinned FluffyChat release on port `8081` |
| `services/dufs/` | packaged WebDAV file server using a pinned upstream image on port `5000` |
| `services/code-server/` | packaged editor service built as a local image and exposed on port `8443` |
| `services/_template/` | scaffold template source for new packages |
| `services/catalog.yaml` | service and bridge metadata catalog |

Built-in infrastructure:

| Path | Role |
|------|------|
| Bloom Home | image-baked landing page on port `8080`, regenerated from installed web services |

Reference-only infrastructure docs:

| Path | Role |
|------|------|
| `docs/matrix-infrastructure.md` | Matrix infrastructure notes |
| `docs/netbird-infrastructure.md` | NetBird infrastructure notes |

Bridge metadata still lives in the `bridges:` section in `services/catalog.yaml`, but bridge lifecycle is no longer part of the default Bloom runtime.

## 🔗 Related

- [../docs/service-architecture.md](../docs/service-architecture.md)
- [../docs/supply-chain.md](../docs/supply-chain.md)
