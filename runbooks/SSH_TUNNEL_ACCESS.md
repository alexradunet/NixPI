# SSH Tunnel Access Runbook

> Historical/recovery-only note: this was the original public-SSH tunnel model. The current canonical model is `https://nazar.studio/` for the private dashboard, `https://nazar.studio/zellij/` for browser Zellij, `netbird ssh root@nazar` for shell, and `https://pve.nazar.studio/` over NetBird for Proxmox UI. Public SSH is intentionally blocked in normal boot.

Use this only if the firewall is intentionally rolled back during recovery.

## Connect

From your PC:

```bash
ssh -L 8006:127.0.0.1:8006 root@167.235.12.22
```

Keep that terminal open.

Then browse to:

```text
https://127.0.0.1:8006
```

Login:

```text
User: root
Realm: Linux PAM
```

## Browser certificate warning

This is expected with Proxmox self-signed certs. Accept the warning only if you are connecting through your SSH tunnel to `127.0.0.1:8006` or if you have verified the certificate.

Known SHA256 fingerprint at install time:

```text
85:D4:F5:AC:4A:12:57:72:2F:79:DC:5F:B4:1D:AB:CD:C3:DE:FE:75:E2:7C:17:66:75:4E:0B:C1:A4:2D:74:1A
```

## If port 8006 is blocked publicly

That is expected. Use NetBird for normal access, not a public SSH tunnel.

## If SSH fails

Try:

```bash
ssh -v root@167.235.12.22
```

If SSH is completely inaccessible, use `RECOVERY_RUNBOOK.md` and Hetzner Robot Rescue.
