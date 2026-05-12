{ pkgs, ... }:
{
  services.netbird = {
    enable = true;

    clients.default.config = {
      # NetBird's embedded SSH server is not canonical on VMs; admin shell
      # access goes through `netbird ssh root@nazar` and then regular OpenSSH
      # as `alex` over the private vmbr1 NAT bridge. Set explicit false values so prior
      # mutable client state is converged back to this model.
      ServerSSHAllowed = false;
      EnableSSHRoot = false;
    };
  };

  # Keep basic account-management/networking tools in the NetBird service PATH
  # for routing/firewall integration.
  systemd.services.netbird.path = [
    pkgs.shadow
    pkgs.iproute2
    pkgs.iptables
  ];
}
