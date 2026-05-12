# Canonical Operating Model

This is the source-of-truth operating model for Nazar and its VM fleet.

## Decision

Use a NixOS-first operating model:

```text
Current host: Debian Proxmox   stable virtualization/recovery layer while migration is evaluated
/root/nazar                    central fleet inventory, shared baseline, infra/network authority
VM service repositories        VM-owned code, NixOS modules, packages, tests, runbooks
Pi on each VM                  human-supervised local coding/debugging/deploy assistant
Future host option             NixOS + microVM, tested in parallel before any cutover
```

The immediate policy is VM self-evolution: a VM-local Pi may edit the VM-owned repo and run the VM's own `nixos-rebuild switch` through the generated `/etc/nazar/self` integration flake. Nazar remains the infrastructure and networking authority.

A full host migration from Debian Proxmox to NixOS + microVM is now an explicit exploration track, but not an in-place production cutover until backups, console/recovery, guest rebuilds, networking, and rollback have been tested.
## Repository ownership

| Repository | Owns | Does not own |
|---|---|---|
| `nazar` | Proxmox host files, fleet inventory, shared VM baseline modules, deploy-rs orchestration, NetBird/firewall/public exposure policy, recovery runbooks | VM product/service implementation |
| `forgejo` | VM 101 Forgejo NixOS host/image/service modules and canonical Git VM runbook | Proxmox host SSH proxy, VMID/IP/DNS, fleet deploy policy |
| `minecraft` | VM 110 PaperMC NixOS host/image/service module and canonical Minecraft runbook | Proxmox host public/NetBird forwarding units |
| `ownloom` | VM 120 OwnLoom packages, NixOS modules, web/Pi/wiki code, canonical OwnLoom runbooks | NetBird/public exposure policy |
| `ownloom-data` | VM 121 Radicale/WebDAV/git-snapshot NixOS modules and canonical data VM runbook | Forgejo infrastructure and fleet backup policy |

## Deployment authority

Deployment is split deliberately:

- VM-owned service/application changes may be deployed from that VM with `nazar-vm-switch`.
- Nazar remains the authority for infrastructure and networking: Proxmox lifecycle, VMID/IP/MAC, resource sizing, NAT/forwarding, public exposure, shared baseline policy, and fleet recovery.
- Nazar also remains a fallback deploy path for any VM after the relevant service repo commit is pushed.

VM repositories expose modules/packages. The generated VM-local flake at `/etc/nazar/self` composes the current Nazar baseline with the local VM repo checkout by adding:

- central fleet metadata: hostname, IP, DNS, service settings;
- shared baseline modules: users, SSH, firewall, NetBird, sops, Nix trust;
- the VM repo's service module from `/home/alex/<repo>`.

This gives each VM its own `sudo nixos-rebuild switch --flake /etc/nazar/self#<vm>` path without giving it broad fleet credentials.
## VM-local Pi workflow

VM-local Pi agents are for authoring and testing their VM-owned repo:

```bash
ssh alex@<vm>
nazar-vm-repo-bootstrap
cd ~/<repo>
pi
nix flake check --no-build
git commit
git push
```

Then deploy the VM locally:

```bash
nazar-vm-switch
# equivalent: sudo nixos-rebuild switch --flake /etc/nazar/self#<vm>
```

Push commits so Nazar can reproduce or roll back the deployed state. Nazar fallback deployment remains:

```bash
cd /root/nazar
nix flake lock --update-input <repo-input>
nix flake check --no-build
nix run .#deploy-<vm>
```

Every Nazar VM gets a declarative context file and Pi context header from the shared Nazar baseline:

```bash
nazar-vm-context                 # markdown
nazar-vm-context --format json   # machine-readable
nazar-deploy-request             # validate local repo state and print the Nazar handoff
```

Pi loads `/home/alex/.pi/agent/AGENTS.md` at startup, and that file points back to `/etc/nazar/vm-context.md`. This is the canonical way VM-local agents learn that they may edit/test/commit/push their VM repo, rebuild the current VM, and leave infrastructure/networking decisions to `/root/nazar`.

## Hypervisor stance

- Keep official Proxmox VE on Debian for the current production host until a tested replacement exists.
- Keep Proxmox noVNC/browser console as the current operator console path.
- Explore NixOS + microVM as the preferred future direction because it is Nix-native, CLI-first, declarative, and agent-friendly.
- Treat Incus as a fallback option if appliance-style import or non-NixOS pet lifecycle becomes important.
- Do not perform a destructive hypervisor cutover until a NixOS+microVM host config, guest rebuild path, networking, backups, monitoring, and rollback have all been rehearsed.
## Recovery requirements

Because VM repos are hosted on the Forgejo VM, keep local clones and off-host git bundles/backups for all repos:

```text
nazar
forgejo
minecraft
ownloom
ownloom-data
```

If Forgejo is unavailable during recovery, build with local overrides:

```bash
cd /root/nazar
nix build .#git-qcow2 \
  --override-input forgejo path:/root/forgejo \
  --override-input minecraft path:/root/minecraft \
  --override-input ownloom path:/root/ownloom \
  --override-input ownloom-data path:/root/ownloom-data
```

## Non-goals

- Do not spread unrestricted fleet credentials to every VM.
- Do not let VM-local worktrees become undocumented mutable production state; commit and push durable changes.
- Do not let VM repos change public exposure, VM identity, or shared networking.
- Do not replace Proxmox with NixOS+microVM without a tested migration and rollback plan.
