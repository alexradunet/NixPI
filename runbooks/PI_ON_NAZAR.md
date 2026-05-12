# Pi on Nazar

Pi is installed on the Proxmox host `nazar` so an admin can SSH into the host and run a coding-agent session directly there.

## Installed state

```text
Host: nazar
Node.js: v20.19.2
npm: 9.2.0
Pi: 0.73.1
Pi binary: /usr/local/bin/pi
Install method: npm global package
Package: @mariozechner/pi-coding-agent
```

Installed with:

```bash
apt-get install -y nodejs npm
npm install -g @mariozechner/pi-coding-agent
```

## What this enables

From a NetBird-connected admin machine:

```bash
netbird ssh root@nazar
pi
```

This starts an interactive Pi coding-agent session directly on the Proxmox host. For manual code navigation in the same shell, inside a manually attached Zellij workspace, or through the private Zellij web terminal at `https://nazar.studio/zellij/`, use the Fresh terminal IDE:

```bash
ide
```

See `runbooks/FRESH_IDE_ON_NAZAR.md`.

Useful working directories:

```text
/etc/pve              Proxmox cluster filesystem/configs
/etc/network          host networking
/etc/nixos            not on Proxmox host; use VM for NixOS config
/var/lib/vz           local Proxmox storage
/var/lib/vz/dump      local backup files
/root                 root home on Proxmox
```

## Authentication status

No Pi provider login/API key was configured during installation.

To use Pi, authenticate interactively or provide an API key.

Interactive login:

```bash
pi
/login
```

Or use an API key environment variable, for example:

```bash
export ANTHROPIC_API_KEY='...'
pi
```

Do not store provider API keys in this repository.

## Security notes

- Pi is a CLI tool, not a network daemon.
- No ports were opened.
- It runs with the permissions of the Unix user that starts it.
- Running Pi as `root` on Proxmox is powerful and potentially dangerous; review changes before applying them.
- Prefer using Pi for inspected, deliberate admin tasks rather than unattended automation.

## Update Pi

```bash
npm install -g @mariozechner/pi-coding-agent
pi --version
```

Note: npm printed deprecation notices indicating the package may move to the `@earendil-works` namespace in the future. Keep an eye on upstream package naming before future upgrades.

## Verify

```bash
ssh nazar 'node --version; npm --version; pi --version; which pi'
```

Expected:

```text
v20.19.2
9.2.0
0.73.1
/usr/local/bin/pi
```
