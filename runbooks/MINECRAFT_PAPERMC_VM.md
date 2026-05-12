# Minecraft VM Runbook Stub

The canonical VM 110 PaperMC/NixOS service runbook now lives in the Minecraft repo:

```text
/root/minecraft/runbooks/MINECRAFT_PAPERMC_VM.md
```

Nazar remains responsible for the fleet and host-side infrastructure around that VM:

- VM inventory and service contracts: `nix/fleet/vms.nix`
- deploy/build compatibility: `flake.nix` exports `.#minecraft-qcow2` and `.#deploy-minecraft`
- Proxmox host forwarding/proxy units:
  - `systemd/minecraft-netbird-forward.service`
  - `scripts/proxmox/minecraft-netbird-forward`
  - `systemd/minecraft-public-forward.service`
  - `scripts/proxmox/minecraft-public-forward`
  - `proxmox/nginx/minecraft-web.conf` for the public/static web guide proxy
- Proxmox firewall / public-exposure policy: `runbooks/PROXMOX_FIREWALL.md`

Do not move host-side forwarding into the Minecraft repo; those units run on `nazar`, not inside VM 110.

Validation from Nazar remains:

```bash
nix flake check --no-build
nix build .#minecraft-qcow2
nix run .#deploy-minecraft
ssh alex@minecraft 'systemctl --failed --no-pager; systemctl is-active minecraft-server'
```
