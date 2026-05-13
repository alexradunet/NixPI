{
  description = "DAV server VM module for Nazar";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
    in
    {
      nixosModules = rec {
        dav-server-service = ./nix/modules/dav-server.nix;
        dav-server = ./nix/hosts/dav-server/default.nix;
        davServer = dav-server;
        dav-server-image = ./nix/hosts/dav-server/image.nix;
        dav-server-disko = ./nix/hosts/dav-server/disko.nix;
        default = dav-server;
      };

      packages = forAllSystems (_system: { });
      checks = forAllSystems (_system: { });
    };
}
