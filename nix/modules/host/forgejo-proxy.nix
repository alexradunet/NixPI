{ fleet, pkgs, ... }:
let
  git = fleet.vms.git;
in
{
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;

    virtualHosts.${git.dns} = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
        {
          addr = "[::]";
          port = 80;
        }
      ];
      locations."/" = {
        proxyPass = "http://${git.ip}:${toString git.webPort}";
        proxyWebsockets = true;
      };
    };
  };

  systemd.services.git-ssh-proxy = {
    description = "Private Forgejo Git SSH proxy to the git MicroVM";
    after = [
      "network-online.target"
      "microvm@git.service"
    ];
    wants = [
      "network-online.target"
      "microvm@git.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.socat ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString git.sshPort},reuseaddr,fork TCP:${git.ip}:${toString git.sshPort}";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
