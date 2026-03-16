# core/os/modules/bloom-update.nix
{ pkgs, lib, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Cachix substituter (pre-built closures; avoids on-device compilation during updates)
  # TODO: replace <cachix-url> and <cachix-pubkey> with real Cachix cache values
  # nix.settings.substituters = [ "https://cache.nixos.org" "<cachix-url>" ];
  # nix.settings.trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "<cachix-pubkey>" ];

  systemd.services.bloom-update = {
    description = "Bloom OS NixOS update";
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];

    serviceConfig = {
      Type            = "oneshot";
      # nixos-rebuild lives at /run/current-system/sw/bin/nixos-rebuild (not in nixpkgs).
      # serviceConfig.path only accepts derivations, so set PATH via Environment instead.
      Environment     = "PATH=/run/current-system/sw/bin:${lib.makeBinPath (with pkgs; [ nix git jq ])}";
      ExecStart       = pkgs.writeShellScript "bloom-update" (builtins.readFile ../../../core/scripts/bloom-update.sh);
      RemainAfterExit = false;

      # Partial sandboxing — service runs as root for nixos-rebuild.
      PrivateTmp = true;
      # ProtectHome omitted — bloom-update.sh writes status to /home/pi/.bloom/
      # ProtectSystem omitted — nixos-rebuild writes to /nix/store and /etc
      # NoNewPrivileges omitted — nixos-rebuild requires privilege escalation
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
