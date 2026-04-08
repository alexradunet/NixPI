{ lib, ... }:

{
  options.nixpi.tailnet = {
    enable = lib.mkEnableOption "admin tailnet client";

    loginServer = lib.mkOption {
      type = lib.types.str;
      example = "https://headscale.example.com";
      description = ''
        Headscale login server used by the Tailscale client.
      '';
    };

    authKeyFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/tailscale-auth-key";
      description = ''
        Runtime path to the auth key file used for enrollment.
      '';
    };

    hostname = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Optional explicit tailnet hostname.
      '';
    };

    extraUpFlags = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional tailscale up flags kept outside the core abstraction.
      '';
    };
  };
}
