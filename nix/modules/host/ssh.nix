{ lib, ... }:
{
  services.openssh = {
    enable = true;
    authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
    # Public OpenSSH remains available for alex from personal secure devices.
    # Root SSH is disabled; Hetzner Rescue is the root/break-glass path.
    # Other devices should use NetBird SSH/JWT identity for alex.
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "alex" ];
      X11Forwarding = false;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 22 ];
    interfaces.wt0.allowedTCPPorts = [ 22 ];
  };
}
