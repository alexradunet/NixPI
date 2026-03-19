---
name: matrix
version: 0.1.0
description: Continuwuity Matrix homeserver (native OS service, no federation)
---

# Matrix Homeserver

Native Continuwuity Matrix server baked into the Workspace OS image.

## Overview

Workspace runs its own Matrix homeserver as a native systemd service (`workspace-matrix.service`). Users register with any Matrix client and message Pi directly. No data leaves the device. No federation - fully private.

## Setup

The Matrix server starts automatically on boot. User accounts are created during the first-boot setup:

1. Pi creates a bot account (`@pi:workspace`) automatically
2. Pi guides the user to register with their preferred Matrix client
3. User creates a DM with `@pi:workspace`

## Configuration

- Server name: `workspace`
- Port: `6167`
- Registration: token-required (see `/var/lib/continuwuity/registration_token`)
- Federation: disabled
- Data: `/var/lib/continuwuity/`

## Bridges

External messaging platforms (WhatsApp, Telegram, Signal) connect via mautrix bridge containers. Bridge packaging still exists in the repo catalog, but bridge lifecycle helpers are no longer part of the default Workspace runtime and should be treated as maintainer-only setup.

## Troubleshooting

- Logs: `journalctl -u workspace-matrix -n 100`
- Status: `systemctl status workspace-matrix`
- Restart: `sudo systemctl restart workspace-matrix`
- Reload (after appservice registration): `sudo systemctl reload workspace-matrix`
