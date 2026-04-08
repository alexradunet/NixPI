# Service Architecture

> Built-in service surface and terminal interfaces

## Current Model

NixPI ships its operator-facing runtime directly from the base NixOS system. The current built-in service set is:

| Service | Purpose |
|---------|---------|
| `nixpi-app-setup.service` | Seeds the Pi runtime state under `~/.pi` |
| `sshd.service` | Remote shell access |
| `wireguard-wg0.service` | Preferred private management overlay |

## Operational Notes

- SSH and local terminals are the supported operator entrypoints
- The Pi runtime is invoked directly with `pi`
- Use `systemctl status nixpi-app-setup.service`, `sshd.service`, and `wireguard-wg0.service` for host-level inspection
