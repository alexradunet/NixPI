# core/os/modules/bloom-update.nix
{ pkgs, lib, config, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  systemd.services.bloom-update = {
    description = "Bloom OS NixOS update";
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];

    serviceConfig = {
      Type            = "oneshot";
      # nixos-rebuild lives at /run/current-system/sw/bin/nixos-rebuild (not in nixpkgs).
      # serviceConfig.path only accepts derivations, so set PATH via Environment instead.
      Environment = [
        "PATH=/run/current-system/sw/bin:${lib.makeBinPath (with pkgs; [ nix git jq ])}"
        "BLOOM_USERNAME=${config.bloom.username}"
      ];
      ExecStart       = pkgs.writeShellScript "bloom-update" (builtins.readFile ../../../core/scripts/bloom-update.sh);
      RemainAfterExit = false;
    };
  };

  systemd.timers.bloom-update = {
    description = "Bloom OS update check timer";
    wantedBy    = [ "timers.target" ];

    timerConfig = {
      OnBootSec        = "5min";
      OnUnitActiveSec  = "6h";
      Persistent       = true;
    };
  };
}
