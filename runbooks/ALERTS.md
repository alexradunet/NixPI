# Nazar Alerts Runbook

## Current status

Proxmox notification delivery is configured and tested.

```text
Target: nazar-alerts
Type: SMTP
Provider: Brevo
Server: smtp-relay.brevo.com
Port: 587
Mode: STARTTLS
From: alerts@nazar.help
Recipient: eucico@proton.me
Matcher: nazar-alerts-all -> nazar-alerts
Default mail-to-root matcher: disabled
Test notification: delivered to Proton inbox
```

The SMTP key was entered interactively and is not documented in this repository. Keep it in Proton Pass.

## Validate Proxmox notification config

```bash
pvesh get /cluster/notifications/targets
pvesh get /cluster/notifications/matchers
pvesh get /cluster/notifications/endpoints/smtp/nazar-alerts
```

The endpoint output should show server/from/recipient, but not the SMTP secret.

## Send test notification

```bash
pvesh create /cluster/notifications/targets/nazar-alerts/test
```

Expected: email arrives at `eucico@proton.me` from `alerts@nazar.help`.

## Current coverage

Covered now:

- Proxmox notification framework test messages.
- Proxmox backup/task notifications routed through `nazar-alerts`.
- Proxmox user email metadata for `root@pam` and `alex@pve` points to `eucico@proton.me`.
- mdadm RAID monitor events routed through `nazar-alerts`.
- smartd SMART warnings routed through `nazar-alerts`.

Additional checks now covered:

- ACME/TLS certificate expiry check, daily.
- High disk usage check, hourly.
- Boot/reboot notification, on boot.

True external downtime detection would require an outside monitor, but that is intentionally skipped for now. The boot alert confirms the host came back after any reboot.

## Host alert bridge

Custom host alerts use a small Proxmox notification bridge:

```text
Templates:
  /etc/pve/notification-templates/default/nazar-alert-subject.txt.hbs
  /etc/pve/notification-templates/default/nazar-alert-body.txt.hbs
  /etc/pve/notification-templates/default/nazar-alert-body.html.hbs

Generic sender:
  /usr/local/sbin/nazar-proxmox-notify

RAID wrapper:
  /usr/local/sbin/nazar-mdadm-alert

SMART wrapper:
  /usr/local/sbin/nazar-smartd-alert

ACME certificate expiry check:
  /usr/local/sbin/nazar-acme-cert-check
  /etc/systemd/system/nazar-acme-cert-check.service
  /etc/systemd/system/nazar-acme-cert-check.timer

Disk usage check:
  /usr/local/sbin/nazar-disk-usage-check
  /etc/systemd/system/nazar-disk-usage-check.service
  /etc/systemd/system/nazar-disk-usage-check.timer

Boot/reboot alert:
  /usr/local/sbin/nazar-boot-alert
  /etc/systemd/system/nazar-boot-alert.service
```

The bridge calls `PVE::Notify` and therefore reuses the existing Proxmox matcher/SMTP endpoint. No SMTP key is duplicated in these scripts.

Versioned copies are kept in this repo for recovery/rebuild:

```text
scripts/nazar-alerts/
proxmox/notification-templates/default/nazar-alert-*.hbs
systemd/nazar-*.service
systemd/nazar-*.timer
```

Config backups from before the RAID/SMART integration:

```text
/etc/mdadm/mdadm.conf.pre-nazar-alerts-20260510-181028
/etc/smartd.conf.pre-nazar-alerts-20260510-181028
```

## RAID/mdadm alerts

Current mdadm alert config:

```text
/etc/mdadm/mdadm.conf
  #MAILADDR root
  PROGRAM /usr/local/sbin/nazar-mdadm-alert
```

`MAILADDR root` is intentionally disabled so mdadm does not rely on local-only mail. `PROGRAM` is enough for `mdadm --monitor --scan` and `mdmonitor-oneshot.service` to dispatch alerts.

Validate service:

```bash
grep -nE 'MAILADDR|PROGRAM' /etc/mdadm/mdadm.conf
systemctl status mdmonitor.service mdmonitor-oneshot.timer --no-pager
```

Send a safe test alert for one array:

```bash
mdadm --monitor --oneshot --test --program /usr/local/sbin/nazar-mdadm-alert /dev/md2
```

Expected command output includes:

```text
mdadm: TestMessage event detected on md device /dev/md2
```

Expected email subject resembles:

```text
[notice] mdadm on nazar.local: RAID TestMessage: /dev/md2
```

## SMART/smartd alerts

Current smartd alert config:

```text
/etc/smartd.conf
  DEVICESCAN -d removable -n standby -m <nomailer> -M exec /usr/local/sbin/nazar-smartd-alert
```

`<nomailer>` prevents smartd from trying local `/usr/bin/mail`; the wrapper reads `SMARTD_*` environment variables and sends through Proxmox notifications.

Validate service:

```bash
grep -nEv '^#|^$' /etc/smartd.conf
systemctl status smartmontools.service --no-pager
```

Send a safe one-device SMART test without changing persistent config:

```bash
tmpconf=$(mktemp)
cat > "$tmpconf" <<'EOF'
/dev/nvme0 -d nvme -a -m <nomailer> -M exec /usr/local/sbin/nazar-smartd-alert -M test
EOF
smartd -q onecheck -n -c "$tmpconf" -s /tmp/smartd-test-state- -A /tmp/smartd-test-attr-
rm -f "$tmpconf" /tmp/smartd-test-state-* /tmp/smartd-test-attr-*
```

Expected output includes:

```text
Test of /usr/local/sbin/nazar-smartd-alert to <nomailer>: successful
```

Expected email subject resembles:

```text
[notice] smartd on nazar.local: SMART error (EmailTest) detected on host: nazar
```

## ACME certificate expiry check

Persistent timer:

```bash
systemctl status nazar-acme-cert-check.timer --no-pager
systemctl status nazar-acme-cert-check.service --no-pager
```

Normal check:

```bash
/usr/local/sbin/nazar-acme-cert-check
```

Forced test alert:

```bash
NAZAR_CERT_WARN_DAYS=365 NAZAR_CERT_CRIT_DAYS=1 /usr/local/sbin/nazar-acme-cert-check
```

Default thresholds:

```text
warning: <= 21 days before expiry
critical: <= 7 days before expiry
```

## Disk usage check

Persistent timer:

```bash
systemctl status nazar-disk-usage-check.timer --no-pager
systemctl status nazar-disk-usage-check.service --no-pager
```

Normal check:

```bash
/usr/local/sbin/nazar-disk-usage-check
```

Forced test alert:

```bash
NAZAR_DISK_WARN_PERCENT=1 NAZAR_DISK_CRIT_PERCENT=99 /usr/local/sbin/nazar-disk-usage-check
```

Default thresholds:

```text
warning: >= 80% used
critical: >= 90% used
```

## Boot/reboot alert

Enabled service:

```bash
systemctl status nazar-boot-alert.service --no-pager
```

Manual test:

```bash
systemctl start nazar-boot-alert.service
```

This sends a notice when the host boots or when the service is manually started. External uptime monitoring is intentionally skipped for now.

## Alert bridge logs

```bash
journalctl --since '1 hour ago' --no-pager \
  | grep -E 'nazar-proxmox-notify|mdadm|smartd|smartmontools|mdmonitor'
```

## Related config

```bash
# Proxmox notifications
pvesh get /cluster/notifications/targets
pvesh get /cluster/notifications/matchers

# Proxmox users/emails
pveum user list

# RAID monitoring
grep -nE 'MAILADDR|PROGRAM' /etc/mdadm/mdadm.conf
systemctl status mdmonitor.service mdmonitor-oneshot.timer --no-pager

# SMART monitoring
grep -nEv '^#|^$' /etc/smartd.conf
systemctl status smartmontools.service --no-pager
```

## Do not leak secrets

Do not paste SMTP keys into chats, docs, shell history, or commits. If the key is exposed, rotate it in Brevo and update the Proxmox SMTP endpoint interactively.
