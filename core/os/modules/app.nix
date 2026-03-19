# core/os/modules/app.nix
{ pkgs, lib, appPackage, piAgent, ... }:

let
  mkService = import ../lib/mk-service.nix { inherit lib; };
in

{
  environment.systemPackages = [ appPackage piAgent ];

  systemd.tmpfiles.rules = [
    "L+ /usr/local/share/nixpi - - - - ${appPackage}/share/nixpi"
    "d /etc/nixpi/appservices 0755 root root -"
  ];

  systemd.user.services.pi-daemon = mkService {
    description = "nixPI Pi Daemon (Matrix room agent)";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionPathExists = "%h/.nixpi/.setup-complete";
    execStart = "${pkgs.nodejs}/bin/node /usr/local/share/nixpi/dist/core/daemon/index.js";
    environment = [
        "HOME=%h"
        "NIXPI_DIR=%h/nixPI"
        "PATH=${lib.makeBinPath [ piAgent pkgs.nodejs ]}:/run/current-system/sw/bin"
      ];
    restart = "on-failure";
    restartSec = 15;
    readWritePaths = [ "%h/.nixpi" "%h/.pi" "%h/nixPI" ];
  };
}
