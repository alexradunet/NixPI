# Nazar DAV service

Reusable NixOS module for the Nazar DAV service: nginx WebDAV plus Radicale.

## Exports

- `nixosModules.dav-server-service` — DAV service module.
- `nixosModules.dav-server` / `nixosModules.davServer` / `default` — aliases for the service module.

## Production

Production evaluation is done by the Nazar monorepo root. Use:

```bash
nix run .#switch-dav-server
```
