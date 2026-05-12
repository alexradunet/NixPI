# OwnLoom Data VM Runbook Stub

The canonical VM 121 OwnLoom Data/NixOS service runbook now lives in the OwnLoom Data repo:

```text
/root/ownloom-data/runbooks/OWNLOOM_DATA_VM.md
```

Nazar remains responsible for the fleet and host-side infrastructure around that VM:

- VM inventory and service contracts: `nix/fleet/vms.nix`
- deploy/build compatibility: `flake.nix` exports `.#ownloom-data-qcow2` and `.#deploy-ownloom-data`
- NetBird/private DNS policy for `data.nazar.studio`
- Forgejo infrastructure used by the existing `nazar/personal-wiki-backup` repository
- backup policy gates in `runbooks/BACKUPS.md`

OwnLoom Data remains NetBird/private-only. This split is code/config only; it does not replace runtime data backups or the existing personal wiki snapshot repository.

Validation from Nazar remains:

```bash
nix flake check --no-build
nix build .#ownloom-data-qcow2
nix run .#deploy-ownloom-data
ssh alex@ownloom-data 'systemctl --failed --no-pager; systemctl is-active radicale nginx; systemctl list-timers ownloom-wiki-git-backup.timer --no-pager'
```
