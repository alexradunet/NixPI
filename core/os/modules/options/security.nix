{ lib, ... }:

{
  options.nixpi.security = {
    fail2ban.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether fail2ban protects SSH against brute-force attempts.
        Defaults false so bootstrap and steady-state hosts only enable it intentionally.
      '';
    };

    ssh.passwordAuthentication = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether SSH password authentication is enabled.";
    };

    ssh.allowedSourceCIDRs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "198.51.100.10/32"
        "2001:db8::/48"
      ];
      description = "Source CIDRs allowed to reach the public SSH service.";
    };

    ssh.allowUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Explicit SSH login allowlist. Empty = restrict to primaryUser.";
    };

    trustedInterface = lib.mkOption {
      type = lib.types.str;
      default = "wt0";
      description = "Network interface trusted for NixPI service surface.";
    };

    enforceServiceFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether NixPI service ports are opened only on the trusted interface.";
    };

    passwordlessSudo.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Deprecated blanket passwordless sudo escape hatch. Keep false; use broker instead.";
    };
  };
}
