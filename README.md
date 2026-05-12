# ownloom-data

OwnLoom Data VM code/config repository for Nazar.

This repository owns VM 121's NixOS host/image modules, Radicale/WebDAV/git-snapshot service module, and canonical OwnLoom Data runbook. The `/root/nazar` repository remains the fleet orchestrator and still owns VMID/IP/MAC/DNS/resources, NetBird/private DNS policy, deploy-rs apps, Forgejo infrastructure, and secrets policy.

## Exports

- `nixosModules.ownloom-data` — installed VM host module
- `nixosModules.ownloom-data-image` — qcow2 image module
- `nixosModules.ownloom-data-service` — Radicale/WebDAV service module
- `nixosModules.ownloom-data-disko` — optional disko layout

## Integration contract

Production evaluation is done by `/root/nazar`. Nazar imports these modules with shared common VM modules and `specialArgs` containing `vm`, `fleet`, and `inputs`. This repo intentionally does not export production `nixosConfigurations` or deploy-rs nodes.

## VM-local Pi workflow

Day-to-day changes should be made from the VM once repo access is provisioned:

```bash
ssh alex@ownloom-data
nazar-vm-repo-bootstrap
cd ~/ownloom-data
pi
nix flake check --no-build
# commit and push to Forgejo
```

Direct VM-local `nixos-rebuild switch` is not the canonical production path. A future `nazar-deploy-self` command may be added, but it must be a restricted trigger for the matching Nazar deploy action.

Nazar remains the deployment orchestrator:

```bash
cd /root/nazar
nix flake lock --update-input ownloom-data
nix run .#deploy-ownloom-data
```

## Validate

```bash
nix flake show
nix flake check --no-build
```

Production builds and deploys are run from `/root/nazar`.
