# core/os/hosts/x86_64-installer.nix
# Graphical installer ISO configuration for Bloom OS.
# Uses Calamares GUI installer with GNOME desktop (auto-starts Calamares via GDM).
# Custom calamares-nixos-extensions override provides Bloom-specific wizard pages.
{ lib, pkgs, modulesPath, ... }:

{
  imports = [
    # Calamares + GNOME installer base — handles GDM autologin, Calamares
    # autostart, polkit agent, and display manager out of the box.
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"
  ];

  # Replace upstream calamares-nixos-extensions with our custom Bloom version.
  # Use prev.callPackage so package.nix receives the pre-overlay pkgs and the
  # pre-overlay calamares-nixos-extensions — prevents infinite recursion.
  nixpkgs.overlays = [
    (final: prev: {
      calamares-nixos-extensions = prev.callPackage ../../calamares/package.nix {
        upstreamCalamares = prev.calamares-nixos-extensions;
      };
    })
  ];

  # Support all locales (Calamares needs this for the locale selection step)
  i18n.supportedLocales = [ "all" ];

  # Extra tools available in the live environment
  environment.systemPackages = with pkgs; [
    gparted
  ];

  # ISO-specific settings
  isoImage.volumeID  = lib.mkDefault "BLOOM_INSTALLER";
  image.fileName     = lib.mkDefault "bloom-os-installer.iso";

  boot.kernelParams = [
    "copytoram"
    "quiet"
    "splash"
  ];

  environment.etc."issue".text = ''
    Welcome to Bloom OS Installer!

    The installer will launch automatically on the desktop.

    For help, visit: https://github.com/alexradunet/piBloom

  '';

  programs.firefox.preferences = {
    "browser.startup.homepage" = "https://github.com/alexradunet/piBloom";
  };

  networking.hostName          = lib.mkDefault "bloom-installer";
  networking.networkmanager.enable = true;
  networking.wireless.enable   = lib.mkForce false;
  services.libinput.enable     = true;
}
