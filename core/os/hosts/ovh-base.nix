# core/os/hosts/ovh-base.nix
# Plain OVH-compatible base NixOS profile for rescue-mode installs. This
# intentionally does not import the NixPI module layer.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  system.stateVersion = "25.05";

  networking.hostName = lib.mkOverride 900 "ovh-base";
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
  };

  services.qemuGuest.enable = lib.mkDefault true;
}
