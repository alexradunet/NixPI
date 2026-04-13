# core/os/modules/options.nix
# Compatibility entrypoint for legacy imports. The dendritic module loader imports
# the feature modules under ./options/ directly and excludes this file.
{ ... }:
{
  imports = [
    ./options/foundation.nix
    ./options/bootstrap.nix
    ./options/security.nix
    ./options/integrations.nix
    ./options/update.nix
    ./options/agent.nix
    ./options/gateway.nix
    ./options/pi-core.nix
    ./options/defaults.nix
  ];
}
