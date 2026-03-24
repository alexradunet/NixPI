# NetBird Deep Integration Design

**Date:** 2026-03-24
**Status:** Draft
**Scope:** Cloud-hosted NetBird + Bloom OS (NixOS) + Matrix (Continuwuity)

---

## Overview

Bloom OS currently uses NetBird as a passive mesh networking layer — services are firewalled to `wt0`, and the mesh is activated via setup key during first-boot. This design makes the integration active and declarative across four dimensions:

1. **Network awareness** — NetBird events streamed into Matrix as bot messages; provisioning progress visible during setup
2. **Simpler access** — hostname-based DNS, NetBird-authenticated SSH (no key management)
3. **Harder security** — auto-group enrollment, granular ACL policies, posture checks
4. **Resilience** — declarative cloud state convergence on every activation

Cloud-hosted NetBird is retained (no self-hosted management server). Google/GitHub OAuth is the IdP for JWT group sync.

---

## Architecture

### Two-Layer Model

**Layer 1 — NetBird cloud state** (groups, policies, posture checks, DNS, setup keys)

A new `nixpi-netbird-provisioner` NixOS module drives a systemd oneshot service that calls the NetBird management API on activation to converge cloud state to desired state. Config is declared in NixOS options (`nixpi.netbird.*`) and applied idempotently — creates what's missing, ignores what already matches. Setup keys are create-only (NetBird API does not support mutating existing keys; config changes require manual revocation in the dashboard and a re-run of the provisioner to recreate).

**Layer 2 — Local NixOS config** (SSH daemon, DNS resolver, events bot)

Changes to `network.nix` and new module files configure how the Pi participates in the mesh locally.

### Peer Topology

```
[admin laptop]  ──NetBird mesh──  [Pi / bloom.local]
[phone]         ──NetBird mesh──     ├── Matrix      :6167  (TCP, admins group only)
[other device]  ──NetBird mesh──     ├── Element Web :8081  (TCP, bloom-devices group)
                                     ├── SSH         :22022 (NetBird SSH daemon, admins group)
                                     └── RDP         :3389  (TCP, admins group)
```

No new open ports. All API calls are outbound from the Pi. Services remain gated to `wt0`.

### Data Flow — Events Bot

```
NetBird cloud API (/api/events, newest-first, no cursor support)
    → poll every 60s (systemd timer → oneshot service)
    → compare against last-seen event ID (read from StateDirectory)
    → post new events to Matrix room via Continuwuity client API
    → write new last-seen event ID to StateDirectory
    → #network-activity:<hostname>
```

The NetBird events API returns events newest-first with no cursor/pagination parameter. The watcher fetches the latest 100 events each cycle and filters client-side by last-seen ID. If a burst of >100 events occurs within 60 seconds, intermediate events are silently skipped — acceptable for an informational audit trail.

### Setup Wizard Visibility

During first-boot, the provisioner runs interactively and streams its output to the wizard terminal so the operator can see each step as it completes:

```
[netbird] Creating group: bloom-devices ... ✓
[netbird] Creating group: admins ... ✓ (already existed)
[netbird] Creating setup key: bloom-device ... ✓
[netbird] Creating posture check: min-client-version ... ✓
[netbird] Creating policy: matrix-access ... ✓
[netbird] Creating policy: element-web-access ... ✓
[netbird] Configuring DNS: bloom.local → bloom-devices ... ✓
[netbird] Done. Network topology applied.
```

The wizard also surfaces the `#network-activity` room alias and explains that future peer connections will appear there.

---

## NixOS Options (`nixpi.netbird.*`)

New options added to `options.nix`. The `dns` and `ssh` sub-namespaces are bare attribute sets inside the `nixpi.netbird` option (consistent with how other nested namespaces like `nixpi.matrix` are handled in the existing `options.nix` — no outer `mkOption` wrapper needed when declared directly within the module's `options` block).

```nix
nixpi.netbird = {
  # Path to file containing NetBird management API personal access token
  apiTokenFile = mkOption { type = types.path; };

  # Base URL for NetBird API (overridable for tests)
  apiEndpoint = mkOption {
    type = types.str;
    default = "https://api.netbird.io";
  };

  # Groups to ensure exist in NetBird cloud.
  # "All" is a NetBird built-in reserved group — never include it here;
  # the provisioner skips creating any group named "All".
  # "bloom-pi" is the group the Pi peer is enrolled into via its setup key;
  # it is used as the destination group in ACL policies so policies apply
  # only to the Pi, not to every peer in the mesh.
  groups = mkOption {
    type = types.listOf types.str;
    default = [ "bloom-devices" "admins" "bloom-pi" ];
  };

  # Setup keys with auto-group assignment.
  # Keys are create-only: changes to an existing key's config require
  # manual revocation in the NetBird dashboard, then a provisioner re-run.
  setupKeys = mkOption {
    type = types.listOf (types.submodule {
      options = {
        name        = mkOption { type = types.str; };
        autoGroups  = mkOption { type = types.listOf types.str; };
        ephemeral   = mkOption { type = types.bool; default = false; };
        usageLimit  = mkOption { type = types.int; default = 0; }; # 0 = unlimited
      };
    });
    default = [
      { name = "bloom-pi";     autoGroups = [ "bloom-pi" ];                       ephemeral = false; usageLimit = 1; } # Pi itself
      { name = "bloom-device"; autoGroups = [ "bloom-devices" ];                  ephemeral = false; usageLimit = 0; }
      { name = "admin-device"; autoGroups = [ "bloom-devices" "admins" ];          ephemeral = false; usageLimit = 0; }
    ];
  };

  # ACL policies.
  # destGroup = "bloom-pi" targets only the Pi peer, not every mesh peer.
  # This is the least-privilege choice: policies grant access to Pi services
  # only, regardless of how many other devices are enrolled in the mesh.
  policies = mkOption {
    type = types.listOf (types.submodule {
      options = {
        name          = mkOption { type = types.str; };
        sourceGroup   = mkOption { type = types.str; };
        destGroup     = mkOption { type = types.str; };
        protocol      = mkOption { type = types.enum [ "tcp" "udp" "icmp" "all" ]; default = "tcp"; };
        ports         = mkOption { type = types.listOf types.str; default = []; };
        postureChecks = mkOption { type = types.listOf types.str; default = []; };
      };
    });
    default = [
      { name = "matrix-access";      sourceGroup = "admins";        destGroup = "bloom-pi"; protocol = "tcp"; ports = [ "6167" ]; }
      { name = "element-web-access"; sourceGroup = "bloom-devices"; destGroup = "bloom-pi"; protocol = "tcp"; ports = [ "8081" ]; }
      { name = "rdp-access";         sourceGroup = "admins";        destGroup = "bloom-pi"; protocol = "tcp"; ports = [ "3389" ]; }
      { name = "ssh-access";         sourceGroup = "admins";        destGroup = "bloom-pi"; protocol = "tcp"; ports = [ "22022" ]; }
    ];
  };

  # Posture checks. Currently only minVersion is supported.
  # For other check types (geo, OS version, process), extend via the NetBird dashboard;
  # the provisioner does not manage check types beyond minVersion.
  postureChecks = mkOption {
    type = types.listOf (types.submodule {
      options = {
        name       = mkOption { type = types.str; };
        minVersion = mkOption { type = types.str; };
      };
    });
    default = [ { name = "min-client-version"; minVersion = "0.61.0"; } ];
  };

  # DNS: configure a NetBird nameserver group so peers in targetGroups
  # resolve cfg.dns.domain via the Pi's NetBird IP.
  # localForwarderPort: NetBird's local DNS forwarder port (default 22054 since v0.59.0).
  # If your NetBird client uses a custom CustomDNSAddress, update this to match.
  dns = {
    domain             = mkOption { type = types.str; default = "bloom.local"; };
    targetGroups       = mkOption { type = types.listOf types.str; default = [ "bloom-devices" ]; };
    localForwarderPort = mkOption { type = types.int; default = 22054; };
  };

  # SSH: enable NetBird's built-in SSH daemon on the Pi (port 22022).
  # Authentication uses NetBird's own peer identity (WireGuard key), not OIDC.
  # Access is controlled by the "ssh-access" ACL policy (admins group only).
  # userMappings: maps a NetBird group to the local OS user the SSH session runs as.
  # Note: standard SSH key-based auth on port 22 remains available per
  # nixpi.bootstrap.keepSshAfterSetup; NetBird SSH is an additional access method.
  ssh = {
    enable = mkOption { type = types.bool; default = true; };
    userMappings = mkOption {
      type = types.listOf (types.submodule {
        options = {
          netbirdGroup = mkOption { type = types.str; };
          localUser    = mkOption { type = types.str; };
        };
      });
      default = [ { netbirdGroup = "admins"; localUser = "alex"; } ];
    };
  };
};
```

---

## New Files

### `core/os/modules/netbird-provisioner.nix`

Systemd oneshot service that converges NetBird cloud state on every `nixos-rebuild switch` or boot.

**Behaviour:**
- Runs after `network-online.target`
- Reads API token from `cfg.netbird.apiTokenFile`
- For each resource type in order (groups → setup keys → posture checks → policies → DNS nameserver group):
  - GET existing resources from NetBird API
  - Compare against desired state
  - POST only what is missing (setup keys: create-only; never PUT/PATCH)
  - For policies and posture checks: PUT to update if name matches but config differs
  - Skip group named `"All"` — NetBird built-in, cannot be created via API
- Streams progress lines to stdout (visible in wizard terminal and journald)
- `Restart=on-failure`, `RestartSec=30s`, max 3 attempts
- All API calls use `cfg.netbird.apiEndpoint` (overridable for tests)

**Security:**
- Runs as `nixpi` user (no root)
- API token read from file at runtime, never logged or interpolated into command strings
- No secrets in Nix store

### `core/os/modules/nixpi-netbird-watcher.nix`

Systemd timer + oneshot service that polls NetBird events and posts to Matrix.

**Timer:** `OnBootSec=2min`, `OnUnitActiveSec=60s`

**Service behaviour:**
- GET `/api/events?limit=100` from NetBird cloud API (returns newest-first)
- Load last-seen event ID from `$STATE_DIRECTORY/last-event-id`
  - First run (no state file): process only the 10 newest events (no room flood)
- For each new event (ID newer than last-seen), POST message to `#network-activity:<hostname>`
  via Continuwuity client API using the `@netbird-watcher:<hostname>` bot account
- Write the newest event ID seen this cycle to `$STATE_DIRECTORY/last-event-id`
- If NetBird API unreachable: exit 0, skip cycle (timer will retry in 60s)
- If Matrix unreachable: serialise undelivered event objects (full payload, not just IDs)
  to `$STATE_DIRECTORY/pending-events` as a JSON array (up to 50 entries); deliver on
  next successful cycle by reading from the file — no re-fetch from NetBird API needed.
  Beyond 50 entries, log and discard the oldest.
- `StateDirectory = "nixpi/netbird-watcher"` → `/var/lib/nixpi/netbird-watcher/`
- Runs as `nixpi` user

**Bot account:**
- MXID: `@netbird-watcher:<hostname>`
- Provisioned during first-boot wizard via registration shared secret (same mechanism as existing bot accounts)
- Access token stored at `$STATE_DIRECTORY/matrix-token`
- Room `#network-activity:<hostname>` created by wizard; bot invited and joined before watcher starts

**Event → Message mapping:**

| NetBird event type | Matrix message |
|---|---|
| `peer.add` | `🟢 New peer joined: <name> (<IP>)` |
| `peer.delete` | `🔴 Peer removed: <name>` |
| `user.login` | `🔑 User logged in: <email>` |
| `policy.update` | `🔧 Policy updated: <name> by <user>` |
| `setup_key.used` | `🔐 Setup key used: <name> — new peer enrolled` |

---

## Changes to Existing Files

### `core/os/modules/network.nix`

- Enable NetBird SSH daemon: `services.netbird.clients.default.config.SSHAllowed = true`
- Configure systemd-resolved to forward `cfg.netbird.dns.domain` to `127.0.0.1:<cfg.netbird.dns.localForwarderPort>` (NetBird's local DNS forwarder)
- NetBird SSH on port 22022 becomes the primary remote access method post-setup; standard SSH on port 22 remains governed by `nixpi.bootstrap.keepSshAfterSetup`

### `core/os/modules/firstboot.nix`

- Add wizard step: prompt operator to paste NetBird management API token; write to `nixpi.netbird.apiTokenFile` path
- Run `nixpi-netbird-provisioner` interactively during wizard, streaming output to terminal
- After provisioner completes: create `#network-activity:<hostname>` Matrix room, register `@netbird-watcher:<hostname>` bot account, invite bot, store bot access token
- Display completion summary: provisioner results, room alias, and instructions for what the operator will see there

---

## Error Handling & Resilience

### Provisioner

| Failure | Behaviour |
|---|---|
| API token missing | Fail immediately with clear log message; other services unaffected |
| NetBird API unreachable | Retry 3× with 30s backoff; log warning; existing mesh config unchanged |
| Resource already exists and matches | No API call (silent) |
| Partial failure (one resource fails) | Log and continue; next boot re-attempts the failed resource |
| Setup key config changed in Nix | Log notice: "Key '<name>' already exists — to apply config changes, revoke it in the NetBird dashboard and re-run the provisioner" |

### Watcher

| Failure | Behaviour |
|---|---|
| NetBird API unreachable | Exit 0; timer retries in 60s |
| Matrix unreachable | Serialise full event payloads to `pending-events` state file; deliver next cycle (max 50 buffered) |
| State file missing (first run) | Process only 10 newest events |
| Continuwuity rejects message | Log, continue; no retry for that event |
| >100 events in one 60s window | Events beyond the 100-event fetch window are silently skipped |

### SSH

NetBird SSH daemon on port 22022 is authenticated by NetBird peer identity (WireGuard key). If the NetBird daemon is down or the peer is not in the `admins` group, connection is refused. Bootstrap SSH on port 22 remains the fallback per `nixpi.bootstrap.keepSshAfterSetup`.

### DNS

Fail-open. If NetBird's local DNS forwarder is unavailable, systemd-resolved falls back to upstream resolvers. `bloom.local` stops resolving; internet access and NetBird-IP-based service access are unaffected.

---

## Testing

### New NixOS Tests

**`nixpi-netbird-provisioner` test:**
- Mock NetBird API with local HTTP server; override `nixpi.netbird.apiEndpoint`
- Verify API calls in correct order (groups before policies, posture checks before policies that reference them)
- Verify idempotency: second activation with identical config makes zero POST/PUT calls
- Verify graceful failure on 401 (bad token) and 503 (API down)
- Verify setup key with matching name is not re-created (create-only semantics)
- Verify group `"All"` is never sent to the groups creation endpoint

**`nixpi-netbird-watcher` test:**
- Mock NetBird events API (returning events newest-first) and Matrix client API
- Verify correct message format per event type
- Verify `last-event-id` state file written after each cycle
- Verify first-run behaviour: no state file → only 10 newest events posted
- Verify pending-events state file written when Matrix returns 503
- Verify pending events delivered on next successful cycle
- Verify no Matrix calls when no new events since last-seen ID

### Extensions to Existing Tests

**`nixpi-e2e.nix`:**
- Verify `nixpi-netbird-provisioner.service` reaches `active (exited)`
- Verify `nixpi-netbird-watcher.timer` is active
- Verify `#network-activity` room exists in Matrix after first boot
- Verify `@netbird-watcher` account exists in Continuwuity

**SSH test:**
- Verify `/etc/ssh/ssh_config.d/99-netbird.conf` present when `nixpi.netbird.ssh.enable = true`
- Verify NetBird service config includes `SSHAllowed = true`

---

## Out of Scope

- NetBird self-hosted management server
- NetBird reverse proxy / Matrix federation exposure (federation disabled by design in Bloom OS)
- Real-time event webhooks (cloud-only NetBird feature; polling is the workaround for cloud API)
- Multi-Pi routing peer configuration
- OIDC-based SSH (e.g. Teleport/Smallstep) — NetBird SSH uses peer identity, not OIDC tokens
- Posture check types beyond `minVersion` (geo, OS version, process checks managed via dashboard)
