# VM repo auto-clone plan

Status: superseded by the canonical MicroVM pattern.

All service guests are MicroVMs. Guest repositories should be exposed through explicit virtiofs shares declared in `nix/fleet/vms.nix`, not through per-VM bootstrap variants.

## Canonical pattern

1. Add a per-service repo share to the VM's `microvm.shares` inventory entry.
2. Mount it at `/home/alex/<repo>` in the guest.
3. Keep ownership/mode in the same share declaration.
4. Let `nazar-vm-repo-bootstrap` initialize or repair the checkout when needed.
5. Use `nazar-vm-switch` for VM-local service deploys and the Nazar deploy app as fallback.

## Policy

Do not introduce separate clone/deploy-key logic for another VM runtime. The only supported runtime is the declarative Nazar MicroVM fleet.
