# Minecraft MicroVM guest module

Canonical runtime: Nazar MicroVM only.

The module in this directory is intentionally service-only. The `/root/nazar` fleet baseline composes hardware-free MicroVM settings, networking, virtiofs persistence, lifecycle, and deploy policy around it.

Important paths:

- Service state: `/var/lib/minecraft` from the `minecraft-state` virtiofs share.
- Service repo: `/home/alex/minecraft` from the `minecraft-repo` virtiofs share.
- VM-local switch helper: `nazar-vm-switch`.

Validate service changes with `nix flake check --no-build`, commit and push, then use `nazar-vm-switch` or the Nazar fallback app `nix run .#deploy-minecraft`.
