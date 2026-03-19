# core/os/modules/options.nix
# Shared NixOS options consumed by workspace-shell, workspace-firstboot, etc.
{ lib, ... }:

{
  options.workspace.username = lib.mkOption {
    type        = lib.types.str;
    default     = "pi";
    description = ''
      Primary system user for the Workspace machine. All Workspace modules
      derive the user name, home directory, and service ownership from it.
    '';
  };
}
