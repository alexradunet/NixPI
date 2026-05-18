# Nazar

Declarative NixOS configuration for the Hetzner host `nazar` and its host services.

## Scope

This repository owns the host configuration, private access model, nginx routing, DAV/NixPi/Code services, Minecraft, operator switch apps, and service code for Nazar. NixPi, Minecraft, and DAV live as local subflakes under `services/`; the running host remains the deployment authority.

## Services

- Public Minecraft: `mc.nazar.studio` game traffic on `25565/tcp` and voice chat on `24454/udp`.
- Private NixPi: `http://nixpi.nazar.studio/` through sshuttle and host nginx.
- Private Code: `http://code.nazar.studio/` through sshuttle and host nginx.
- Private DAV: `http://dav.nazar.studio/` through sshuttle and host nginx.

## Repository map

```text
nix/hosts/nazar/              # bare-metal host configuration
nix/modules/host/             # host networking, firewall, nginx, DAV, Minecraft, NixPi, Code
nix/modules/laptop/           # client-side sshuttle access module
nix/fleet/                    # service and exposure metadata
services/minecraft/           # Minecraft NixOS service module
services/dav-server/          # DAV/Radicale/WebDAV NixOS service module
services/nixpi/               # NixPi service
```

## Common commands

```bash
nix flake check
nix fmt
nix run .#switch-host
nix run .#switch-minecraft
nix run .#switch-dav-server
```

## Quick health checks

```bash
systemctl is-active sshd systemd-networkd nginx nixpi-bun openvscode-server radicale minecraft-server
curl -I http://dav.nazar.studio/files/
```

## Policy

- Keep deployment authority in this repository.
- Keep private HTTP services bound to the host private address and reachable through sshuttle.
- Keep service modules reusable, but compose production configuration from the root host flake.
