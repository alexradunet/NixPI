---
name: netbird
version: "0.1.0"
description: Secure mesh networking via NetBird (EU-hosted cloud management)
image: netbirdio/netbird@sha256:b3e69490e58cf255caf1b9b6a8bbfcfae4d1b2bbaa3c40a06cfdbba5b8fdc0d2
---

# NetBird

EU-hosted mesh networking for secure remote access to your Bloom device. Uses NetBird cloud management (free tier, up to 5 peers).

NetBird provides the security layer for remote desktop (wayvnc) and file access (dufs).

## Setup

1. Install: `just svc-install netbird`
2. Authenticate: `podman exec bloom-netbird netbird up`
3. Follow the browser link to sign in at https://app.netbird.io
4. Check status: `podman exec bloom-netbird netbird status`

## Adding Peers

Install NetBird on your other devices (laptop, phone) from https://netbird.io/download and sign in with the same account. All devices on the same account can reach each other.

## Operations

- Logs: `journalctl --user -u bloom-netbird -n 100`
- Stop: `systemctl --user stop bloom-netbird`
- Start: `systemctl --user start bloom-netbird`
- Status: `podman exec bloom-netbird netbird status`
