# NixOS Fleet Architecture

`nazar` is moving toward a fully declarative NixOS-first fleet. Today the VMs are declarative NixOS guests managed on Proxmox; the strategic host direction is NixOS + microVM after a tested migration.

## Rules

See `runbooks/CANONICAL_OPERATING_MODEL.md` for the top-level platform/deployment decision. The rules below implement that model.

- NixOS is the default OS for every VM.
- Nazar owns central VM inventory, shared VM baseline policy, and deploy-rs orchestration. VM-specific service code/config may live in dedicated VM repositories and be consumed as flake inputs.
- `alex` is the canonical human admin user on NixOS VMs. Normal VM shell access is key-only SSH from `nazar` to private NAT aliases, for example `ssh alex@<vm-name>`.
- VM passwords stay locked for normal operation. Do not add a shared VM password. Future console break-glass passwords, if needed, must be unique per VM and delivered through encrypted `sops-nix`/secret material.
- Root VM SSH remains key-only for break-glass and current compatibility; it is not the canonical human login.
- Runtime state is allowed, but it must be named and documented.
- Secrets are not committed. Use encrypted SOPS files or an explicitly documented external secret store.
- Proxmox host config is still Debian/Proxmox-managed for now; VM configs are declarative first.
- Each VM may rebuild itself from the generated `/etc/nazar/self#<vm>` integration flake for VM-owned service/application changes.
- `nazar` remains the fleet infrastructure orchestrator and fallback deployer: evaluate/build from `/root/nazar` on the current host, then deploy NixOS system changes to existing VMs over the private NAT aliases with `deploy-rs` as `alex`.

See also `runbooks/NIXOS_DECLARATIVE_VM_POLICY.md`.

## Repository layout

```text
flake.nix                         # fleet entrypoint
nix/fleet/vms.nix                 # VM inventory, IPs, VMIDs, roles
nix/lib/mk-nixos-host.nix         # helper for nixosConfigurations
nix/modules/common/               # shared NixOS VM modules
nix/modules/services/             # reusable service modules
/root/forgejo/                    # VM 101 Forgejo host/service flake
nix/users/admin-keys.nix          # public SSH keys only
nix/sops/                         # encrypted secrets only
/root/minecraft/                  # VM 110 PaperMC host/service flake
/root/ownloom/                    # VM 120 OwnLoom packages/modules flake
/root/ownloom-data/               # VM 121 DAV/Radicale host/service flake
```

## Current and planned VM ranges

```text
101-109 / 10.10.10.21-29   infrastructure services
110-119 / 10.10.10.30-39   game servers
120-139 / 10.10.10.40-59   OwnLoom split services
900-999                    disposable restore/test VMs only
```

## First fleet members

```text
git            VMID 101  10.10.10.21  Forgejo private Git server; service repo `/root/forgejo`
minecraft      VMID 110  10.10.10.30  PaperMC Minecraft server; service repo `/root/minecraft`
ownloom        VMID 120  10.10.10.40  OwnLoom app/Pi/wiki VM; service repo `/root/ownloom`
ownloom-data   VMID 121  10.10.10.41  DAV/Radicale data VM; service repo `/root/ownloom-data`
```


## VM repository split

Nazar remains the orchestrator. The service repositories expose NixOS modules/packages and consume `vm`/`fleet` via Nazar's `specialArgs`; they do not own production deploy-rs nodes, VMIDs, MACs, IPs, DNS records, NetBird policy, or Proxmox host forwarding.

Current VM repo inputs are locked to Forgejo remotes:

```text
forgejo        git+ssh://git@git.nazar.studio:10022/nazar/forgejo.git
minecraft      git+ssh://git@git.nazar.studio:10022/nazar/minecraft.git
ownloom        git+ssh://git@git.nazar.studio:10022/nazar/ownloom.git
ownloom-data   git+ssh://git@git.nazar.studio:10022/nazar/ownloom-data.git
```

Local working copies are kept at `/root/forgejo`, `/root/minecraft`, `/root/ownloom`, and `/root/ownloom-data` for recovery and direct maintenance. VM-local worktrees under `/home/alex/<repo>` are the preferred place for day-to-day VM-owned code changes.


### Forgejo input recovery fallback

Because the VM service flakes are hosted on VM 101 (`git`), a fresh disaster-recovery evaluator may need the sibling working copies or an off-host mirror before it can evaluate Nazar. The normal lock points at Forgejo, but recovery builds can override the VM inputs with local clones:

```bash
cd /root/nazar
nix build .#git-qcow2   --override-input forgejo path:/root/forgejo   --override-input minecraft path:/root/minecraft   --override-input ownloom path:/root/ownloom   --override-input ownloom-data path:/root/ownloom-data
```

Keep recent off-host copies or git bundles of `nazar`, `forgejo`, `minecraft`, `ownloom`, and `ownloom-data` with the VM backups so VM 101 recovery does not depend solely on VM 101 being online.

Production compatibility remains in Nazar:

```bash
nix build .#git-qcow2
nix build .#minecraft-qcow2
nix build .#ownloom-qcow2
nix build .#ownloom-data-qcow2
nix run .#deploy-git
nix run .#deploy-minecraft
nix run .#deploy-ownloom
nix run .#deploy-ownloom-data
```

VM-local Pi agents may author, test, commit, push, and deploy their own VM repo with `nazar-vm-switch`. The shared VM baseline installs `/etc/nazar/vm-context.md`, `/etc/nazar/vm-context.json`, `/etc/nazar/self`, `nazar-vm-context`, `nazar-vm-switch`, `nazar-deploy-request`, and Pi's global `/home/alex/.pi/agent/AGENTS.md` so agents discover this policy automatically. Nazar remains the fallback deployer and the authority for public exposure, VM identity, Proxmox/microVM lifecycle, and shared networking.

## Networking convention

VMs attach to Proxmox bridge `vmbr1` and use static addresses in `10.10.10.0/24`:

```text
gateway:  10.10.10.1
bridge:   vmbr1
NIC name: ens18 by default for Proxmox VirtIO guests; override per VM in `nix/fleet/vms.nix` if needed
```

NetBird remains the preferred private access layer. Public DNS must not point VM services at the Hetzner public IP unless explicitly intended.

## Build/evaluation

The current Proxmox host has Nix installed as tooling only. The host remains Debian + Proxmox until a deliberate NixOS+microVM migration is tested; Nix is used to evaluate and build NixOS VM configurations.

```bash
. /etc/profile.d/nix.sh
cd /root/nazar
nix flake metadata
nix flake check
nix build .#nixosConfigurations.git.config.system.build.toplevel
nix build .#git-qcow2
nix build .#minecraft-qcow2
```

`.#git-qcow2` builds `result/nixos-git.qcow2`; `.#minecraft-qcow2` builds `result/nixos-minecraft.qcow2`. Both can be imported into Proxmox with `qm importdisk`.

## Day-2 NixOS deployment from a VM

For VM-owned service/application work, deploy from inside the VM:

```bash
ssh alex@<vm>
nazar-vm-repo-bootstrap
cd ~/<repo>
# edit/test with Pi or manually
nix flake check --no-build
git add <files>
git commit
git push
nazar-vm-switch
```

`nazar-vm-switch` runs `sudo nixos-rebuild switch --flake /etc/nazar/self#<vm>`. `/etc/nazar/self` is generated by the Nazar shared baseline and composes the local service repo checkout with the fleet metadata and common modules.

Infrastructure/networking changes still go through `/root/nazar`.

## Day-2 NixOS fallback deployment from `nazar`

`deploy-rs` is wired in `flake.nix` under `deploy.nodes`. Each node uses:

```text
hostname = <private NAT alias from nix/fleet/vms.nix>
sshUser  = alex
user     = root
```

This makes `nazar` the orchestrator while preserving the normal VM access model: SSH as `alex` over `vmbr1`, escalate through passwordless sudo, and activate the root NixOS system profile. Deployments build on `nazar` (`remoteBuild = false`) and copy closures over the private bridge (`fastConnection = true`). `alex`/wheel is a trusted Nix user in the common VM module so deploy-rs can import store paths before sudo activation.

Existing pre-orchestrator VMs may need one bootstrap deploy as root before `alex` has Nix trust on that guest:

```bash
nix run .#deploy-<vm-name> -- --ssh-user root
```

After that converges, use the normal `alex` deploy path.

Use a canary first:

```bash
netbird ssh root@nazar
cd /root/nazar
nix flake check --no-build
nix run .#deploy-git
ssh alex@git 'systemctl --failed --no-pager'
```

VM-side handoff helper after a service-repo push:

```bash
ssh alex@<vm>
cd ~/<repo>
nazar-deploy-request
```

Then deploy additional VMs from Nazar when the canary is healthy, checking each service before continuing:

```bash
nix run .#deploy-minecraft
ssh alex@minecraft 'systemctl --failed --no-pager; systemctl is-active minecraft-server'

nix run .#deploy-ownloom
ssh alex@ownloom 'systemctl --failed --no-pager; pi --help >/dev/null && ownloom-context --format json >/dev/null'

nix run .#deploy-ownloom-data
ssh alex@ownloom-data 'systemctl --failed --no-pager; systemctl is-active radicale nginx'
```

All-fleet deployment is intentionally gated by an environment variable. Use it only after a canary deploy, per-VM runbook checks, and a maintenance-window/rollback decision:

```bash
NAZAR_DEPLOY_ALL_CONFIRM=yes nix run .#deploy-all
```

Do not bypass the guarded wrapper with raw fleet-wide `nix run .#deploy -- .#...` targets during normal operations. Avoid combining `deploy-all` with `--skip-checks` except during a documented incident.

Pass deploy-rs flags before the target through the wrapper when needed. Skipping checks should be emergency-only and the reason should be recorded in the operator notes:

```bash
nix run .#deploy-git -- --skip-checks
```

These deploy commands do not create, destroy, resize, restore, or import Proxmox VMs. Proxmox lifecycle changes remain explicit operator actions and require the usual runbook confirmation.

`flake.lock` is generated and should be updated intentionally:

```bash
nix flake lock
```

## Cutover rule

Repository scaffolding is safe. Destructive Proxmox actions are not. Get final explicit confirmation immediately before running commands such as:

```bash
qm stop 101
qm destroy 101 --purge
```
