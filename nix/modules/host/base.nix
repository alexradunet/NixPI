{ pkgs, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "alex"
      "@wheel"
    ];
    auto-optimise-store = true;
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [
      "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    iproute2
    jq
    mdadm
    nftables
    pciutils
    rsync
    smartmontools
    tmux
    vim
    wget
  ];

  boot.tmp.cleanOnBoot = true;
  services.fstrim.enable = true;
  documentation.nixos.enable = false;
}
