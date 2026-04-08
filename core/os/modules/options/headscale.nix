{ lib, ... }:

{
  options.nixpi.headscale = {
    enable = lib.mkEnableOption "self-hosted Headscale control plane";

    serverUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://headscale.example.com";
      description = ''
        Public URL advertised to tailnet clients.
      '';
    };

    policyFile = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Optional runtime path to a Headscale policy file.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Additional native services.headscale.settings overrides.
      '';
    };
  };
}
