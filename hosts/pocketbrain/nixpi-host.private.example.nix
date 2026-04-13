{ config, ... }:
{
  # Copy this file to nixpi-host.private.nix in a private checkout or host-owned
  # private repo. Do not commit the populated private file.

  # Optional: restrict public SSH exposure when you intentionally enable it.
  nixpi.security.ssh.allowedSourceCIDRs = [
    "203.0.113.10/32"
  ];

  # Channel identities and operator allowlists stay private.
  nixpi.gateway = {
    enable = true;
    modules.signal = {
      enable = true;
      account = "+15550001111";
      allowedNumbers = [ "+15550002222" ];
      adminNumbers = [ "+15550002222" ];
    };
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.77.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets.wg-pocketbrain-private.path;

    peers = [
      {
        publicKey = "REPLACE_ME";
        allowedIPs = [ "10.77.0.10/32" ];
      }
      {
        publicKey = "REPLACE_ME";
        allowedIPs = [ "10.77.0.20/32" ];
      }
    ];
  };

  users.users.alex.hashedPassword = "REPLACE_WITH_HASH";
  users.users.root.hashedPassword = "REPLACE_WITH_HASH";

  users.users.alex.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA... alex@device"
  ];
}
