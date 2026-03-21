{ lib, pkgs, modulesPath, installerHelper, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  system.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.config.allowUnfree = true;

  isoImage = {
    appendToMenuLabel = "NixPI Installer";
    edition = "nixpi";
    volumeID = "NIXPI_INSTALL";
    forceTextMode = true;
    grubTheme = null;
  };

  image.fileName = "nixpi-installer-${pkgs.stdenv.hostPlatform.system}.iso";

  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];

  networking.hostName = "nixpi-installer";
  networking.networkmanager.enable = true;
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  services.getty.autologinUser = lib.mkDefault "nixos";
  systemd.services."serial-getty@ttyS0".enable = true;
  systemd.services."serial-getty@ttyS0".serviceConfig.ExecStart = [
    ""
    "${lib.getExe' pkgs.util-linux "agetty"} --login-program ${pkgs.shadow}/bin/login --autologin nixos --keep-baud ttyS0 115200,38400,9600 vt220"
  ];

  environment.systemPackages = with pkgs; [
    git
    just
    curl
    gum
  ] ++ [
    installerHelper
  ];
}
