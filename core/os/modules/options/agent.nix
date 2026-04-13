{ lib, config, ... }:

let
  absolutePath = lib.types.pathWith { absolute = true; };
in
{
  options.nixpi.agent = {
    autonomy = lib.mkOption {
      type = lib.types.enum [
        "observe"
        "maintain"
        "admin"
      ];
      default = "maintain";
      description = "Default privileged autonomy level granted to the always-on agent.";
    };

    allowedUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nixpi-update.service" ];
      description = "Systemd units the broker may operate on.";
    };

    broker.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the root-owned NixPI operations broker is enabled.";
    };

    envFiles = lib.mkOption {
      type = lib.types.listOf absolutePath;
      default = [ ];
      example = [ "/var/lib/nixpi/secrets/exa.env" ];
      description = "Environment files sourced by the Pi runtime wrapper before launching pi. Use this for secrets that must stay out of the Nix store.";
    };

    elevation.duration = lib.mkOption {
      type = lib.types.str;
      default = "30m";
      description = "Default duration for a temporary admin elevation grant.";
    };

    osUpdate.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the broker may apply or roll back NixOS generations.";
    };

    stagedHostConfig = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether the broker may sync a staged host-local NixOS file into the
          installed `/etc/nixos` tree and optionally rebuild immediately.
          Defaults true so hosts following the `/srv/<hostname>-private`
          mirror convention can apply staged `nixpi-host.nix` changes through
          the broker without blanket sudo.
        '';
      };

      sourceFile = lib.mkOption {
        type = absolutePath;
        default = "/srv/${config.networking.hostName}-private/nixpi-host.nix";
        description = "Absolute path to the staged host-specific NixOS file that should be synced into /etc/nixos before rebuild.";
      };

      targetFile = lib.mkOption {
        type = absolutePath;
        default = "/etc/nixos/nixpi-host.nix";
        description = "Absolute target path inside the installed host flake that receives the staged host config file.";
      };

      fileMode = lib.mkOption {
        type = lib.types.str;
        default = "0644";
        description = "File mode used when syncing the staged host config into the installed /etc/nixos tree.";
      };
    };

    packagePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/usr/local/share/nixpi" ];
      description = "Package root paths passed to the Pi agent settings.json packages field.";
    };

    piDir = lib.mkOption {
      type = lib.types.str;
      description = "Declarative Pi runtime directory exported as NIXPI_PI_DIR and PI_CODING_AGENT_DIR.";
    };

    workspaceDir = lib.mkOption {
      type = lib.types.str;
      description = "Root directory for the Pi agent workspace (Objects, Episodes, Skills, Persona, etc.).";
    };
  };
}
