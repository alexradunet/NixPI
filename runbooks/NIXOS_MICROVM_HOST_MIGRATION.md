# NixOS + microVM Host Migration Plan

Nazar's strategic direction is full NixOS: declarative host OS, declarative guest/service configs, and CLI-first operations that Pi agents can read and modify safely.

This is a plan, not approval to destroy or replace the current Proxmox host. For the concrete scratch rebuild checklist, see `runbooks/NIXOS_MICROVM_CLEAN_REINSTALL.md`.

## Current recommendation

For this fleet, prefer **NixOS + microvm.nix** over NixOS + Incus if we are willing to rebuild from source-of-truth instead of importing pet appliances.

Why microVM fits Nazar well:

- current important guests are already NixOS;
- VM service definitions are already flakes/modules;
- we want text-first, git-reviewed, agent-readable infrastructure;
- microVMs can be declared and started by the host's NixOS configuration;
- the migration can be a clean rebuild from repos plus restored service data.

Incus remains useful if we need appliance-style import/lifecycle for non-NixOS pets. For a NixOS-only fleet, microVM is more aligned with the desired model.

## Target architecture

```text
Hetzner bare metal
└─ NixOS host
   ├─ declarative storage/networking/firewall/NetBird/SSH/monitoring/backups
   ├─ microvm.nix host module
   ├─ declared microVMs for git, minecraft, ownloom, ownloom-data
   ├─ persistent per-service state directories/volumes
   └─ /root/nazar or successor infra repo as source of truth
```

## Scratch rebuild principle

A scratch rebuild is acceptable only if these are backed up and restore-tested:

- all Git repositories: `nazar`, `forgejo`, `minecraft`, `ownloom`, `ownloom-data`, and wiki/data backup repos;
- Forgejo data if keeping issues/users/settings/history beyond bare Git repos;
- Minecraft world and server state under `/var/lib/minecraft`;
- OwnLoom and OwnLoom Data persistent state, especially DAV/wiki data;
- secrets: age/SOPS keys, host SSH keys if identities must persist, service SSH deploy keys, NetBird setup material, htpasswd/password files;
- DNS/NetBird/public forwarding inventory;
- current `flake.lock` files and off-host git bundles.

If only Git repos are backed up, we can rebuild code/config, but we will lose mutable service state such as Minecraft worlds, Forgejo app database/settings, and DAV/wiki files unless those are separately backed up.

## microVM design notes

Use `microvm.nixosModules.host` on the NixOS host and `microvm.nixosModules.microvm` in each guest configuration.

Important choices to test:

- hypervisor: start with `cloud-hypervisor` for simple NixOS guests, or `qemu` if we need broader device/share support;
- networking: tap/routed networking with static addresses, replacing the current Proxmox `vmbr1` model;
- persistent state: explicit `microvm.volumes` or `microvm.shares` per service;
- boot/autostart: host declaratively lists VM names in `microvm.autostart`;
- console/recovery: document systemd logs, microVM control sockets, and host rescue access;
- backup: host-level backup of declared state directories/volumes plus git bundles.

## Non-negotiable cutover gates

Do not cut over until all of these are true:

1. Off-host backups exist for repos, service state, and secrets.
2. A NixOS host config boots in a disposable VM or spare machine.
3. At least one service microVM boots from the same Nix modules as production.
4. Git/Forgejo can be restored without depending on the old Forgejo VM being online.
5. Minecraft/OwnLoom/OwnLoom Data persistent state restore has been rehearsed.
6. Static networking, NAT, public forwards, NetBird access, DNS assumptions, and firewall policy are reproduced declaratively.
7. Monitoring and backup jobs run on the new host.
8. Rollback is explicit: reinstall Proxmox or boot rescue and restore backups.

## Phases

### Phase 0: current safe improvement

- Keep Debian Proxmox as production host.
- Let each VM self-deploy service changes with `nazar-vm-switch`.
- Keep Nazar as infrastructure/network/fallback deploy authority.

### Phase 1: backup and inventory

Create fresh off-host bundles and state archives:

```bash
mkdir -p /root/nazar-backup/git-bundles
for repo in /root/nazar /root/forgejo /root/minecraft /root/ownloom /root/ownloom-data; do
  name=$(basename "$repo")
  git -C "$repo" bundle create "/root/nazar-backup/git-bundles/$name.bundle" --all
  git -C "$repo" rev-parse HEAD > "/root/nazar-backup/git-bundles/$name.HEAD"
done
```

Then back up service state with service-specific quiesce/stop steps from each runbook. Do not rely on Git alone for mutable data.

### Phase 2: model the NixOS host

Create a host flake/module set for:

- users and SSH keys;
- Nix settings and trusted users;
- Hetzner networking, routed/tap microVM networking, NAT, firewall, and public forwards;
- NetBird client;
- monitoring/alerts;
- backup jobs;
- microvm.nix host module and autostart list.

### Phase 3: model one microVM

Start with the least risky guest, likely `minecraft` if the world is backed up, or a disposable clone.

The guest should reuse the existing service module plus microVM-specific boot/network/persistence module.

Sketch only:

```nix
{
  imports = [
    microvm.nixosModules.microvm
    inputs.minecraft.nixosModules.minecraft
  ];

  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 2;
    mem = 4096;
    interfaces = [ {
      type = "tap";
      id = "vm-minecraft";
      mac = "02:00:00:00:00:30";
    } ];
    shares = [ {
      proto = "virtiofs";
      tag = "minecraft-state";
      source = "/var/lib/microvms/minecraft/state";
      mountPoint = "/var/lib/minecraft";
    } ];
  };
}
```

Exact configuration must be tested against the chosen hypervisor and storage model.

### Phase 4: simulation

Run the proposed host config as a VM or spare-machine install. Validate:

```bash
nixos-rebuild build-vm --flake .#nazar-microvm-sim
```

Inside the simulated host:

```bash
systemctl status microvm@minecraft
ssh alex@<microvm-ip>
systemctl --failed --no-pager
```

### Phase 5: production cutover plan

Only after rehearsal:

1. Announce maintenance window.
2. Stop mutable services.
3. Take final backups/snapshots/git bundles.
4. Boot Hetzner rescue or installer path.
5. Install NixOS host from the tested flake.
6. Restore service state and secrets.
7. Start declared microVMs.
8. Validate private access first, then public service paths.
9. Keep rollback path ready until all services pass checks.

## Open design decisions

- Storage backend: ZFS, btrfs, ext4-on-RAID, or LVM for host and microVM state.
- `cloud-hypervisor` vs `qemu` for the first production microVMs.
- Whether Forgejo should remain a microVM or become a host service during bootstrap.
- Whether VM-local `nazar-vm-switch` remains inside microVMs or host-driven microVM rebuilds become the only activation path.
- Public ingress model: nftables forwards on host vs host reverse proxy.
- Replacement for Proxmox browser noVNC in day-to-day recovery.

## Current stance

Proceed with backup, design, and simulation. Do not destructively replace Proxmox until the cutover gates are satisfied and the operator gives explicit confirmation.
