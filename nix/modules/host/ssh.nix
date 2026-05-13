{ lib, ... }:
{
  services.openssh = {
    enable = true;
    authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
    # Canonical daily access is WireGuard first. Public OpenSSH remains only as
    # an alex-only, key-only break-glass path using the deliberately small
    # personal-device key set in nix/users/alex-public-ssh-keys.nix.
    # Root SSH is disabled; Hetzner Rescue is the final root/break-glass path.
    # Firewall opening is interface-scoped below so MicroVM tap links never get
    # host SSH access.
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "alex" ];
      X11Forwarding = false;
    };
  };

  networking.firewall.interfaces = {
    enp0s31f6.allowedTCPPorts = [ 22 ];
    wg0.allowedTCPPorts = [ 22 ];
  };
}
