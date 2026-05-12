# Proxmox ACME Certificate Runbook

Goal: make the Proxmox UI trusted at:

```text
https://pve.ownloom.com:8006
```

without exposing Proxmox publicly.

## Why DNS-01 is used

Proxmox is intentionally private behind NetBird. Public ports for the Proxmox UI remain blocked.

Let's Encrypt still needs proof that we control `ownloom.com`. DNS-01 proves this by creating a temporary TXT record under the domain, for example:

```text
_acme-challenge.pve.ownloom.com
```

This does not require opening public HTTP/HTTPS ports.

## Completed setup

### Hetzner Console API token

A Hetzner Console project API token was created for DNS automation.

```text
Permission: Read & Write
Purpose: allow Proxmox to create/delete ACME DNS TXT records
```

Do not store the token in this repository.

Unlike one-time setup keys, this token should remain valid because Proxmox needs it for automatic certificate renewal.

### Proxmox ACME account

```text
ACME account: default
```

### Proxmox DNS challenge plugin

```text
Plugin ID: hetznercloud-ownloom
Challenge type: DNS
DNS API: hetznercloud
Validation delay: 120 seconds
API data variable: HETZNER_TOKEN
```

The API token is stored in Proxmox ACME plugin configuration, not in docs.

### Proxmox ACME domain

```text
Node: nazar
Domain: pve.ownloom.com
Plugin: hetznercloud-ownloom
Node config: acme=account=default, acmedomain0=domain=pve.ownloom.com,plugin=hetznercloud-ownloom
```

## Current certificate status

Proxmox now serves a browser-trusted Let's Encrypt certificate on:

```text
https://pve.ownloom.com:8006
```

Verified from a NetBird-connected machine:

```text
HTTP: 200
TLS verification: OK
Subject/CN: pve.ownloom.com
Issuer: Let's Encrypt R13
SAN: pve.ownloom.com
Valid from: 2026-05-10
Valid until: 2026-08-08
```

Proxmox certificate file shown by `pvenode cert info`:

```text
pveproxy-ssl.pem
```

The internal Proxmox CA and `pve-ssl.pem` still exist, but the web UI is served by the custom/ACME `pveproxy-ssl.pem` certificate.

## Renewal

Proxmox should automatically renew the ACME certificate before expiry using:

```text
ACME account: default
DNS plugin: hetznercloud-ownloom
Hetzner API token stored in Proxmox plugin config
```

Do not delete the Hetzner Console API token unless you also replace/update the Proxmox ACME plugin configuration.

Current security TODO: rotate the Hetzner DNS API token used by this plugin and update the Proxmox plugin config. Do not paste the new token into chats, docs, shell history, or logs.

Safe update pattern after creating a replacement token in Hetzner Console:

```bash
umask 077
read -rsp 'New Hetzner DNS token: ' HETZNER_TOKEN; echo
TMP=$(mktemp)
printf 'HETZNER_TOKEN=%s\n' "$HETZNER_TOKEN" > "$TMP"
pvenode acme plugin set hetznercloud-ownloom --api hetznercloud --data "$TMP" --validation-delay 120
rm -f "$TMP"
unset HETZNER_TOKEN TMP
```

## Manual verification commands

From a NetBird-connected client:

```bash
curl https://pve.ownloom.com:8006/
```

Expected: no TLS verification error.

On Proxmox:

```bash
pvenode cert info
pvenode config get
pvenode acme account list
# Avoid `pvenode acme plugin list` in shared logs: it can print API token data.
```

Expected certificate includes:

```text
Subject/CN: pve.ownloom.com
Issuer: Let's Encrypt
SAN: pve.ownloom.com
```

## If renewal/order fails later

Common causes:

- Hetzner Console API token deleted or rotated without updating Proxmox;
- token belongs to the wrong project and cannot see the `ownloom.com` DNS zone;
- wrong plugin/API selected; should be `hetznercloud`, not old `hetzner`;
- wrong API data variable; should be `HETZNER_TOKEN`, not `HETZNER_Token`;
- DNS propagation too slow; increase validation delay to 180 or 300 seconds;
- ACME rate limit after repeated failed attempts.

Do not paste API tokens into chats, logs, or docs.
