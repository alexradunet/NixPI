{ ... }:

{
  imports = [
    ./matrix.nix
    ./service-surface.nix
    ./netbird-provisioner.nix
    ./nixpi-netbird-watcher.nix
  ];
}
