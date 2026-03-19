# core/os/modules/options.nix
# Shared NixOS options consumed across nixPI modules.
{ lib, ... }:

let
  mkPortOption = default: description:
    lib.mkOption {
      type = lib.types.port;
      inherit default description;
    };
in
{
  options.nixpi = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "pi";
      description = ''
        Primary system user for the nixPI machine. All nixPI modules
        derive the user name, home directory, and service ownership from it.
      '';
    };

    security = {
      trustedInterface = lib.mkOption {
        type = lib.types.str;
        default = "wt0";
        description = ''
          Network interface trusted to reach the externally exposed nixPI
          service surface.
        '';
      };

      enforceServiceFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether nixPI service ports are opened only on the trusted interface.
        '';
      };

      passwordlessSudo.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether the primary nixPI user gets broad passwordless sudo during
          the current bootstrap-oriented phase of the project.
        '';
      };
    };

    services = {
      bindAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = ''
          Bind address used by the built-in nixPI service surface.
        '';
      };

      home = {
        enable = lib.mkEnableOption "nixPI Home service" // { default = true; };
        port = mkPortOption 8080 "TCP port for the nixPI Home landing page.";
      };

      chat = {
        enable = lib.mkEnableOption "nixPI web chat service" // { default = true; };
        port = mkPortOption 8081 "TCP port for the nixPI Chat web client.";
      };

      files = {
        enable = lib.mkEnableOption "nixPI Files service" // { default = true; };
        port = mkPortOption 5000 "TCP port for the nixPI file browser.";
      };

      code = {
        enable = lib.mkEnableOption "nixPI code-server service" // { default = true; };
        port = mkPortOption 8443 "TCP port for the nixPI browser IDE.";
      };
    };

    matrix = {
      bindAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = ''
          Bind address used by the local Matrix homeserver listener.
        '';
      };

      port = mkPortOption 6167 "TCP port for the local Matrix homeserver.";

      enableRegistration = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether Matrix account registration is enabled.
        '';
      };

      maxUploadSize = lib.mkOption {
        type = lib.types.str;
        default = "20M";
        description = ''
          Maximum upload size accepted by the local Matrix homeserver.
        '';
      };
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
