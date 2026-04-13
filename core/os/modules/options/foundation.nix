{ lib, ... }:

let
  absolutePath = lib.types.pathWith { absolute = true; };
in
{
  options.nixpi = {
    primaryUser = lib.mkOption {
      type = lib.types.str;
      default = "pi";
      description = "Primary human/operator account for the NixPI machine.";
    };

    allowPrimaryUserChange = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow a one-time intentional change to `nixpi.primaryUser` on an
        already-activated system. When false, NixPI aborts activation before
        user management if the configured primary user drifts from the recorded
        operator account.
      '';
    };

    stateDir = lib.mkOption {
      type = absolutePath;
      default = "/var/lib/nixpi";
      description = "Root directory for service-owned NixPI state.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "System timezone (IANA string, e.g. Europe/Paris).";
    };

    keyboard = lib.mkOption {
      type = lib.types.str;
      default = "us";
      description = "Console keyboard layout (e.g. fr, de, us).";
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos#nixos";
      description = "Flake URI for this NixPI system used by auto-upgrade and the broker.";
    };
  };
}
