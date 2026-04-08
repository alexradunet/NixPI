# core/os/modules/network.nix
{
  pkgs,
  lib,
  config,
  ...
}:

let
  primaryUser = config.nixpi.primaryUser;
  securityCfg = config.nixpi.security;
  bootstrapCfg = config.nixpi.bootstrap;
  headscaleCfg = config.nixpi.headscale;
  tailnetCfg = config.nixpi.tailnet;
  sshAllowUsers =
    if securityCfg.ssh.allowUsers != [ ] then
      securityCfg.ssh.allowUsers
    else
      lib.optional (primaryUser != "") primaryUser;
  headscaleSettings = lib.recursiveUpdate headscaleCfg.settings (
    {
      server_url = headscaleCfg.serverUrl;
    }
    // lib.optionalAttrs (headscaleCfg.policyFile != null) {
      policy.path = headscaleCfg.policyFile;
    }
  );
  tailnetUpFlags =
    [
      "--login-server"
      tailnetCfg.loginServer
    ]
    ++ lib.optionals (tailnetCfg.hostname != null) [
      "--hostname"
      tailnetCfg.hostname
    ]
    ++ tailnetCfg.extraUpFlags;
in

{
  imports = [ ./options.nix ];

  config = {
    assertions = [
      {
        assertion = securityCfg.trustedInterface != "";
        message = "nixpi.security.trustedInterface must not be empty.";
      }
    ];

    hardware.enableAllFirmware = true;

    services.openssh = {
      enable = bootstrapCfg.ssh.enable;
      openFirewall = false;
      settings = {
        AllowAgentForwarding = false;
        AllowTcpForwarding = false;
        ClientAliveCountMax = 2;
        ClientAliveInterval = 300;
        LoginGraceTime = 30;
        MaxAuthTries = 3;
        PasswordAuthentication = securityCfg.ssh.passwordAuthentication;
        PubkeyAuthentication = "yes";
        PermitRootLogin = "no";
        X11Forwarding = false;
      };
      extraConfig = lib.optionalString (sshAllowUsers != [ ]) ''
        AllowUsers ${lib.concatStringsSep " " sshAllowUsers}
      '';
    };

    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = lib.optionals bootstrapCfg.ssh.enable [ 22 ];
    networking.useDHCP = lib.mkDefault false;
    networking.networkmanager.enable = true;

    services.headscale = lib.mkIf headscaleCfg.enable {
      enable = true;
      settings = headscaleSettings;
    };

    services.tailscale = lib.mkIf tailnetCfg.enable {
      enable = true;
      authKeyFile = tailnetCfg.authKeyFile;
      extraUpFlags = tailnetUpFlags;
      openFirewall = false;
    };

    services.fail2ban = lib.mkIf securityCfg.fail2ban.enable {
      enable = true;
      jails.sshd.settings = {
        enabled = true;
        backend = "systemd";
        bantime = "1h";
        findtime = "10m";
        maxretry = 5;
      };
    };

    systemd.tmpfiles.settings = {
      nixpi-workspace = {
        "${config.nixpi.agent.workspaceDir}".d = {
          mode = "2775";
          user = primaryUser;
          group = primaryUser;
        };
      };
    };

    environment.systemPackages =
      lib.optionals headscaleCfg.enable [ pkgs.headscale ]
      ++ lib.optionals tailnetCfg.enable [ pkgs.tailscale ];
  };
}
