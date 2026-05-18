# Nazar Minecraft service

Nazar-owned PaperMC Minecraft NixOS service module.

This directory owns the reusable Minecraft module. The root Nazar flake imports it into the host configuration and supplies the service context from `nix/fleet/vms.nix`.

## Exports

- `nixosModules.minecraft-service` — PaperMC service module.
- `nixosModules.minecraft` / `default` — aliases for the service module.

## Production

Production evaluation is done by the Nazar monorepo root. Use:

```bash
nix run .#switch-minecraft
```
