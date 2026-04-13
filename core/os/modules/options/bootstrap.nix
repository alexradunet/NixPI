{ lib, ... }:

{
  options.nixpi.bootstrap = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether the system is intentionally configured in bootstrap mode.
        Bootstrap mode is declarative: it enables the temporary operator
        affordances needed before the host is locked down.
      '';
    };

    ssh.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether SSH is exposed for the selected NixPI system state. Defaults true so steady-state hosts remain remotely reachable unless explicitly locked down.";
    };

    temporaryAdmin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the primary operator receives the declarative bootstrap-time passwordless sudo grant.";
    };
  };
}
