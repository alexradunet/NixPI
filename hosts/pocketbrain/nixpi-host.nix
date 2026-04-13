{ lib, pkgs, ... }:
{
  # Keep host-specific secrets, recovery credentials, transport identities,
  # WireGuard peers, and operator access policy in the private overlay.
  imports = lib.optional (builtins.pathExists ./nixpi-host.private.nix) ./nixpi-host.private.nix;

  networking.hostName = "pocketbrain";
  nixpi.bootstrap.enable = false;
  nixpi.bootstrap.ssh.enable = false;
  nixpi.primaryUser = "alex";
  nixpi.timezone = "Europe/Bucharest";
  nixpi.keyboard = "us";

  nixpi.integrations.exa.enable = true;
  nixpi.security.fail2ban.enable = true;
  services.fail2ban.ignoreIP = [ "10.77.0.0/24" ];

  services.openssh.enable = true;
  services.resolved.enable = true;

  environment.systemPackages = with pkgs; [
    zellij
  ];

  programs.bash.loginShellInit = lib.mkAfter ''
    case "$-" in
      *i*)
        if [ -n "''${SSH_TTY-}" ] && [ -z "''${ZELLIJ-}" ] && [ -z "''${ZELLIJ_AUTO_ATTACH_DISABLED-}" ] && command -v zellij >/dev/null 2>&1; then
          case "''${TERM-}" in
            ""|dumb) ;;
            *) exec zellij attach -c main ;;
          esac
        fi
        ;;
    esac
  '';

  programs.bash.interactiveShellInit = lib.mkAfter ''
    path_without_nixos_sudo_entries=":$PATH:"
    path_without_nixos_sudo_entries="''${path_without_nixos_sudo_entries//:\/run\/wrappers\/bin:/:}"
    path_without_nixos_sudo_entries="''${path_without_nixos_sudo_entries//:\/run\/current-system\/sw\/bin:/:}"
    path_without_nixos_sudo_entries="''${path_without_nixos_sudo_entries#:}"
    path_without_nixos_sudo_entries="''${path_without_nixos_sudo_entries%:}"
    export PATH="/run/wrappers/bin:/run/current-system/sw/bin''${path_without_nixos_sudo_entries:+:$path_without_nixos_sudo_entries}"
  '';

  # SSH remains reachable only through the trusted WireGuard interface in steady state.
  networking.firewall.allowedUDPPorts = [ 51820 ];
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 22 ];

  nixpi.piCore = {
    enable = true;
    piCwd = "/home/alex";
    defaultProvider = "cortecs";
    defaultModel = "minimax-m2.5";
  };
}
