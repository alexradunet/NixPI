{
  description = "OwnLoom data VM module for Nazar";

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
        ownloom-data-service = ./nix/modules/ownloom-data.nix;
        ownloom-data = ./nix/hosts/ownloom-data/default.nix;
        ownloomData = ownloom-data;
        ownloom-data-image = ./nix/hosts/ownloom-data/image.nix;
        ownloom-data-disko = ./nix/hosts/ownloom-data/disko.nix;
        default = ownloom-data;
      };

      packages = forAllSystems (_system: { });
      checks = forAllSystems (_system: { });
    };
}
