{ pkgs, ... }:
let
  pi = pkgs.callPackage ../../packages/pi { };
in
{
  imports = [ ../common/pi-default-packages.nix ];

  environment.systemPackages = [
    pi
    pkgs.nodejs
  ];

  environment.sessionVariables = {
    PI_TELEMETRY = "0";
    PI_SKIP_VERSION_CHECK = "1";
  };
}
