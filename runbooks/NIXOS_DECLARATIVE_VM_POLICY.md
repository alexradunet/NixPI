# Declarative NixOS VM Policy

This is the default rule for VMs on `nazar`.

## Rule

All new VMs should run NixOS by default and must be managed declaratively.

A VM is acceptable only when its bootable system can be recreated from version-controlled Nix code plus documented secrets/state restore steps. Manual configuration inside the guest is not a valid long-term operating model.

## Requirements

For every new VM:

- Use NixOS unless there is an explicit documented exception.
- Keep the VM's OS, packages, services, users, firewall, SSH, NetBird, monitoring, and backup hooks in a NixOS configuration.
- Declare `alex` as the canonical human admin user for NixOS VMs. Normal VM shell access is key-only SSH from the Proxmox host `nazar` to private NAT aliases, for example `ssh alex@<vm-name>`.
- Keep SSH password auth disabled for normal operation. Do not use a shared VM password. Console/noVNC break-glass root passwords may exist only as unique per-VM secrets outside git; the common NixOS module applies `/var/lib/nazar/secrets/root-password-hash` when present while SSH password login remains disabled.
- Preserve root VM SSH as key-only for break-glass and current compatibility unless a future migration explicitly removes it.
- Prefer a flake-based host profile, for example `nixosConfigurations.<vm-name>`.
- Use `nazar` as the day-2 production fleet orchestrator: evaluate/build from `/root/nazar` and deploy existing VM system profiles with `deploy-rs` over private NAT aliases as `alex`. VM-local Pi agents may author and test VM repos, but VM-local `nixos-rebuild switch` is not the canonical production path.
- Pin inputs with `flake.lock` or an equivalent lock file.
- Do not install packages, enable services, edit config files, or create users manually inside the guest as the final state.
- Do not rely on ad-hoc shell history, copied files, mutable Docker Compose directories, or manually edited systemd units for reproducibility.
- Runtime state is allowed only as state: databases, repositories, uploaded files, caches, and logs. Its paths, ownership, service integration, and backup/restore procedure must be documented.
- Secrets must not be committed. Declare where secrets live and how they are provisioned, using a real secret mechanism such as `sops-nix`, age, or another documented secret store.
- Proxmox-side VM metadata should be documented: VMID, name, MAC, IP reservation, CPU/RAM/disk, boot mode, backup job, and access path.

## Definition of done for a VM

Before a VM is considered production-ready:

1. The VM can be rebuilt from the Nix configuration without manual guest edits.
2. A fresh VM can be recreated from the repo plus secret material from the password/secret store.
3. Persistent state paths are known and covered by a backup plan.
4. Access is private-by-default through NetBird or an explicitly documented route.
5. Any exception from this policy is documented with a reason and a migration/removal plan.

## Fleet examples

VM 101 (`git`) is a declarative NixOS Forgejo VM built from the `/root/forgejo` service repo and orchestrated by this repository's flake.

VM 110 (`minecraft`) is declared here as a NixOS PaperMC VM; its world data remains mutable state under `/var/lib/minecraft` and needs separate backups.

The retired Debian/Docker Gogs VM was intentionally destroyed without a fresh pre-rebuild backup because only this repository needed to be pushed into the new forge.
