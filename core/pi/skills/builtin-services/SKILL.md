---
name: builtin-services
description: Reference for Garden's built-in user-facing services that are always available on every node
---

# Built-In Services

Garden ships these services as part of the base NixOS system. They are not optional packages and they do not need to be installed from the repo.

## Always Available

- `Garden Home` on `:8080` — landing page with links to the built-in web services
- `Garden Web Chat` on `:8081` — FluffyChat web client for the local Garden Matrix server
- `Garden Files` on `:5000` — dufs WebDAV/file browser for `~/Public/Garden`
- `code-server` on `:8443` — browser IDE for working on the local machine

## Operational Notes

- These services are managed as declarative user systemd units
- Use `systemd_control` for status, restart, and stop/start operations
- They should be treated as stable base OS capabilities, not as optional service packages

## Expected Unit Names

- `garden-home`
- `garden-fluffychat`
- `garden-dufs`
- `garden-code-server`

## URLs

Preferred access is over NetBird:

- `http://<netbird-host>:8080`
- `http://<netbird-host>:8081`
- `http://<netbird-host>:5000`
- `http://<netbird-host>:8443`

Local access on the machine also works:

- `http://localhost:8080`
- `http://localhost:8081`
- `http://localhost:5000`
- `http://localhost:8443`
