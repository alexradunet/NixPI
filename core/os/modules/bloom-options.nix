# core/os/modules/bloom-options.nix
# Shared NixOS options consumed by bloom-shell, bloom-firstboot, etc.
{ lib, ... }:

{
  options.bloom.username = lib.mkOption {
    type        = lib.types.str;
    default     = "pi";
    description = ''
      Primary system user created by the Calamares installer.
      Set in the installer-generated host-config.nix; all Bloom modules
      derive the user name, home directory, and service ownership from it.
    '';
  };
}
