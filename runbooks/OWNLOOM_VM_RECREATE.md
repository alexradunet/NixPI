# OwnLoom VM Runbook Stub

The canonical VM 120 OwnLoom/NixOS service runbook now lives in the OwnLoom repo:

```text
/root/ownloom/runbooks/OWNLOOM_VM_RECREATE.md
```

Nazar remains responsible for the fleet and host-side infrastructure around that VM:

- VM inventory and service contracts: `nix/fleet/vms.nix`
- deploy/build compatibility: `flake.nix` exports `.#ownloom-qcow2`, `.#ownloom-web`, and `.#deploy-ownloom`
- NetBird/private DNS and public-exposure policy
- Proxmox lifecycle decisions and recovery runbooks

OwnLoom remains NetBird/private-only. Do not add public forwarding, public DNS exposure, or arbitrary shell/code-editing access through the life-management UI without a new explicit hardening decision.

Validation from Nazar remains:

```bash
nix flake check --no-build
nix build .#ownloom-qcow2 .#ownloom-web
nix run .#deploy-ownloom
ssh alex@ownloom 'systemctl --failed --no-pager; pi --help >/dev/null && ownloom-context --format json >/dev/null; systemctl is-active ownloom-web nginx ownloom-zellij-web'
```
