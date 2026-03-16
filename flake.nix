# flake.nix
{
  description = "Bloom OS — Pi-native AI companion OS on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents-nix = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, llm-agents-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      piAgent = llm-agents-nix.packages.${system}.pi;
      bloomApp = pkgs.callPackage ./core/os/pkgs/bloom-app { inherit piAgent; };

      # Image configuration using NixOS built-in disk-image module
      mkImageSystem = format: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./core/os/hosts/x86_64.nix
          # Import the disk-image module from nixpkgs and set format options
          ({ config, pkgs, ... }: {
            imports = [ "${nixpkgs}/nixos/modules/virtualisation/disk-image.nix" ];
            image.format = format;
            image.efiSupport = true;
          })
        ];
        specialArgs = { inherit piAgent bloomApp; };
      };
    in {
      packages.${system} = {
        bloom-app = bloomApp;

        qcow2 = (mkImageSystem "qcow2").config.system.build.image;

        raw = (mkImageSystem "raw").config.system.build.image;

        iso = (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./core/os/hosts/x86_64.nix
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ];
          specialArgs = { inherit piAgent bloomApp; };
        }).config.system.build.isoImage;
      };

      nixosConfigurations.bloom-x86_64 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./core/os/hosts/x86_64.nix
          ./core/os/hosts/x86_64-disk.nix
        ];
        specialArgs = { inherit piAgent bloomApp; };
      };
    };
}
