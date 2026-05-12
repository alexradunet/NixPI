# Nazar Private Dashboard

`https://nazar.studio/` is the NetBird-only dashboard for the Proxmox host and private services.

## Access model

- NetBird private DNS maps `nazar.studio` and `pve.nazar.studio` to `100.124.39.100` for admin peers.
- nginx listens only on the Proxmox NetBird IP: `100.124.39.100:80` and `100.124.39.100:443`.
- `nazar.studio` serves the static dashboard and proxies `/zellij/` to localhost.
- `pve.nazar.studio` remains the dedicated Proxmox UI alias.
- Public Reverse Proxy exposure remains disabled by default.

## Live host files

```text
/etc/nginx/sites-available/netbird-private.conf
/etc/nginx/sites-enabled/netbird-private.conf
/var/www/nazar-dashboard/index.html
/etc/systemd/system/nazar-zellij-web.service
/home/alex/.config/zellij/config.kdl
/root/.nazar-secrets/zellij-web-token.txt
```

Repo copies/templates:

```text
proxmox/nginx/netbird-private.conf
proxmox/zellij/config.kdl
www/nazar-dashboard/index.html
systemd/nazar-zellij-web.service
```

The repo copies are documentation/templates for the Debian/Proxmox host; they are not deployed by Nix. When changing the live host, keep the repo copies in sync.

## Apply/update from repo templates

```bash
install -d -m 755 /var/www/nazar-dashboard /etc/nginx/sites-available /etc/systemd/system /home/alex/.config/zellij
cp /root/nazar/www/nazar-dashboard/index.html /var/www/nazar-dashboard/index.html
cp /root/nazar/proxmox/nginx/netbird-private.conf /etc/nginx/sites-available/netbird-private.conf
cp /root/nazar/systemd/nazar-zellij-web.service /etc/systemd/system/nazar-zellij-web.service
cp /root/nazar/proxmox/zellij/config.kdl /home/alex/.config/zellij/config.kdl
chown alex:alex /home/alex/.config/zellij/config.kdl
chmod 600 /home/alex/.config/zellij/config.kdl
systemctl daemon-reload
nginx -t && systemctl reload nginx
systemctl enable --now nazar-zellij-web.service
```

## Zellij web terminal

Zellij web runs as Linux user `alex`, binds to localhost only, and is configured with `web_client { base_url "/zellij/" }` for the nginx subpath:

```text
127.0.0.1:8082
```

Systemd service:

```bash
systemctl status nazar-zellij-web.service
systemctl restart nazar-zellij-web.service
journalctl -u nazar-zellij-web.service -n 100 --no-pager
```

The browser endpoint is:

```text
https://nazar.studio/zellij/
```

Zellij sets `X-Frame-Options: DENY`, so the dashboard links to the terminal instead of embedding it in an iframe.

## Login token

Zellij login tokens are shown only once. The current generated token was saved root-only on the host:

```bash
sudo cat /root/.nazar-secrets/zellij-web-token.txt
```

List token names:

```bash
runuser -u alex -- /nix/var/nix/profiles/default/bin/zellij web --list-tokens
```

Create a replacement token:

```bash
install -d -o root -g root -m 700 /root/.nazar-secrets
runuser -u alex -- /nix/var/nix/profiles/default/bin/zellij web --create-token \
  > /root/.nazar-secrets/zellij-web-token.txt
chmod 600 /root/.nazar-secrets/zellij-web-token.txt
```

Revoke tokens:

```bash
runuser -u alex -- /nix/var/nix/profiles/default/bin/zellij web --revoke-token <token-name>
# or, to revoke everything:
runuser -u alex -- /nix/var/nix/profiles/default/bin/zellij web --revoke-all-tokens
```

Note: `zellij web --create-token --token-name ...` currently fails on this host's Zellij `0.44.2`; use unnamed generated tokens and list/revoke by the generated token name.

## Validation

```bash
nginx -t
systemctl is-active nginx
systemctl is-active nazar-zellij-web.service
ss -ltnp | grep -E ':(80|443|8082)\\b'
curl -k --noproxy '*' --resolve nazar.studio:443:100.124.39.100 https://nazar.studio/ | grep '<title>Nazar private dashboard'
curl -k --noproxy '*' --resolve nazar.studio:443:100.124.39.100 https://nazar.studio/zellij/ | grep '<title>Zellij Web Client'
```

Expected listeners:

```text
nginx:  100.124.39.100:80, 100.124.39.100:443
zellij: 127.0.0.1:8082
```

## Rollback

To restore the old behavior where `nazar.studio` proxied directly to Proxmox, restore the latest nginx backup and stop the Zellij service:

```bash
ls -1 /etc/nginx/sites-available/netbird-private.conf.*.bak
cp /etc/nginx/sites-available/netbird-private.conf.YYYYMMDDHHMMSS.bak \
  /etc/nginx/sites-available/netbird-private.conf
nginx -t && systemctl reload nginx
systemctl disable --now nazar-zellij-web.service
```
