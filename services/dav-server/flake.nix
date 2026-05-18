{
  description = "DAV server service module for Nazar";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
    in
    {
      nixosModules = rec {
        dav-server-service = ./nix/modules/dav-server.nix;
        dav-server = dav-server-service;
        davServer = dav-server-service;
        default = dav-server-service;
      };

      packages = forAllSystems (_system: { });
      checks = forAllSystems (_system: { });
    };
}
