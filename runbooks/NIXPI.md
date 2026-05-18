# Legacy NixPi Runbook

NixPi is no longer part of the production Nazar host configuration. The host now uses the upstream Hermes Agent NixOS module; see [`HERMES.md`](./HERMES.md).

Historical source still lives under `services/nixpi/`, but it is not imported by `nix/hosts/nazar/default.nix`, not exposed through nginx, and not built by the root flake outputs.

If you need to resurrect NixPi, treat that as a new design change and re-add:

- the reusable module import from `services/nixpi/nix/modules/nixpi-bun.nix`
- a host adapter under `nix/modules/host/`
- private exposure in `nix/fleet/exposure.nix`
- nginx routing in `nix/modules/host/service-proxy.nix`
- package/check/dev-shell outputs in `flake.nix`
