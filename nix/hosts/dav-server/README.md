# DAV Server MicroVM guest module

Canonical runtime: Nazar MicroVM only.

The module in this directory is intentionally service-only. The `/root/nazar` fleet baseline composes hardware-free MicroVM settings, networking, virtiofs persistence, lifecycle, and deploy policy around it.

Important paths:

- DAV state: `/var/lib/dav-server` from the `dav-server-data` virtiofs share.
- Radicale collections: `/var/lib/radicale/collections` from the `dav-server-radicale` virtiofs share.
- VM-local switch helper: `nazar-vm-switch`.

Validate service changes with `nix flake check --no-build`, commit and push, then use `nazar-vm-switch` or the Nazar fallback app `nix run .#deploy-dav-server`.
