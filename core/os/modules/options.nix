# core/os/modules/options.nix
# Aggregates NixPI option declarations split by concern.
{ lib, ... }:

{
  imports = [
    ./options/core.nix
    ./options/security.nix
    ./options/agent.nix
    ./options/wireguard.nix
  ];

  options.nixpi = {
    bootstrap.keepSshAfterSetup = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether SSH should remain reachable after first-boot setup
        completes. By default SSH is treated as a bootstrap-only path.
      '';
    };

    update = {
      onBootSec = lib.mkOption {
        type = lib.types.str;
        default = "5min";
        description = ''
          Delay before the first automatic update check after boot.
        '';
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "6h";
        description = ''
          Recurrence interval for the automatic update timer.
        '';
      };
    };
  };
}
