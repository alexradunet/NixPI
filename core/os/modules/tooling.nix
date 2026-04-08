{ pkgs, lib, config, ... }:

let
  nixpiRebuild = pkgs.callPackage ../pkgs/nixpi-rebuild { }; # rebuild the installed /etc/nixos host flake
  nixpiRebuildPull = pkgs.callPackage ../pkgs/nixpi-rebuild-pull { }; # sync/rebuild the conventional /srv/nixpi operator checkout
in
{
  imports = [ ./options.nix ];

  options.nixpi.tooling.qemu.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install QEMU and OVMF for running local NixOS VM tests.
      Can be disabled on production VPS deployments to reduce closure size.
    '';
  };

  config.environment.systemPackages = with pkgs; [
    git
    git-lfs
    gh
    nodejs
    ripgrep
    fd
    bat
    htop
    jq
    curl
    wget
    unzip
    openssl
    just
    shellcheck
    biome
    typescript
    nixpiRebuild
    nixpiRebuildPull
  ]
  ++ lib.optionals config.nixpi.tooling.qemu.enable [ qemu OVMF ]
  ++ lib.optionals config.nixpi.security.fail2ban.enable [ pkgs.fail2ban ];
}
