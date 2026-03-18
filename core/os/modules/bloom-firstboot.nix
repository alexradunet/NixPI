# core/os/modules/bloom-firstboot.nix
{ config, pkgs, ... }:

let
  u = config.bloom.username;
in
{
  imports = [ ./bloom-options.nix ];

  systemd.services.bloom-firstboot = {
    description = "Bloom First-Boot Setup";
    wantedBy = [ "multi-user.target" ];
    # getty.target blocks all console logins until this completes.
    before = [ "getty.target" ];
    after = [
      "network-online.target"
      "bloom-matrix.service"
      "netbird.service"
      "user@1000.service"
    ];
    wants = [
      "network-online.target"
      "bloom-matrix.service"
      "netbird.service"
      "user@1000.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = u;
      ExecStart = "${pkgs.bash}/bin/bash ${../../scripts/bloom-firstboot.sh}";
      StandardOutput = "journal";
      StandardError = "journal";
      # systemctl --user needs XDG_RUNTIME_DIR to reach the user bus socket.
      # UID 1000 is deterministic for the first normal user in NixOS.
      Environment = "XDG_RUNTIME_DIR=/run/user/1000";
      # Exit 1 = non-fatal partial failure; user can recover via bloom-wizard.sh.
      SuccessExitStatus = "0 1";
    };
    unitConfig.ConditionPathExists = "!/home/${u}/.bloom/.setup-complete";
  };

  # Narrow sudo rules for commands bloom-firstboot.sh needs in a non-TTY context.
  # NOTE: bloom-shell.nix already grants the primary user full NOPASSWD sudo,
  # making these rules currently redundant. Kept for future hardening documentation.
  security.sudo.extraRules = [
    {
      users = [ u ];
      commands = [
        { command = "/run/current-system/sw/bin/cat /var/lib/continuwuity/registration_token"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/journalctl -u bloom-matrix --no-pager"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/netbird up --setup-key *"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/systemctl start netbird.service"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  # Enable linger for the primary user via tmpfiles to avoid polkit dependency at runtime.
  systemd.tmpfiles.rules = [ "f+ /var/lib/systemd/linger/${u} - - - -" ];
}
