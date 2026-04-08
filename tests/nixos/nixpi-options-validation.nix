{
  lib,
  nixPiModulesNoShell,
  mkTestFilesystems,
  mkManagedUserConfig,
  ...
}:

{
  name = "nixpi-options-validation";

  nodes = {
    defaults =
      { config, options, ... }:
      {
        imports = nixPiModulesNoShell ++ [
          mkTestFilesystems
          (mkManagedUserConfig { username = "pi"; })
        ];

        networking.hostName = "nixpi-defaults-test";

        environment.etc = {
          "nixpi-tests/ssh-password-auth".text =
            if config.services.openssh.settings.PasswordAuthentication then "yes" else "no";
          "nixpi-tests/has-headscale-option".text =
            if lib.hasAttrByPath [ "nixpi" "headscale" ] options then "yes" else "no";
          "nixpi-tests/has-tailnet-option".text =
            if lib.hasAttrByPath [ "nixpi" "tailnet" ] options then "yes" else "no";
          "nixpi-tests/has-wireguard-option".text =
            if lib.hasAttrByPath [ "nixpi" "wireguard" ] options then "yes" else "no";
        };
      };

    overrides =
      { config, ... }:
      {
        imports = nixPiModulesNoShell ++ [
          mkTestFilesystems
          (mkManagedUserConfig { username = "pi"; })
        ];

        networking.hostName = "nixpi-overrides-test";

        nixpi = {
          agent.autonomy = "observe";
          security = {
            fail2ban.enable = false;
            ssh.passwordAuthentication = true;
          };
          headscale = {
            enable = true;
            serverUrl = "https://headscale.example.test";
            policyFile = "/run/secrets/headscale-policy.hujson";
            settings = {
              dns = {
                base_domain = "tailnet.example.test";
              };
              log = {
                level = "debug";
              };
            };
          };
          tailnet = {
            enable = true;
            loginServer = "https://headscale.example.test";
            authKeyFile = "/run/secrets/tailscale-auth-key";
            hostname = "nixpi-managed-node";
            extraUpFlags = [
              "--accept-dns=false"
              "--ssh"
            ];
          };
        };

        environment.etc = {
          "nixpi-tests/ssh-password-auth".text =
            if config.services.openssh.settings.PasswordAuthentication then "yes" else "no";
          "nixpi-tests/headscale-enable".text = if config.nixpi.headscale.enable then "yes" else "no";
          "nixpi-tests/headscale-server-url".text = config.nixpi.headscale.serverUrl;
          "nixpi-tests/headscale-policy-file".text =
            config.nixpi.headscale.policyFile or "";
          "nixpi-tests/headscale-base-domain".text =
            config.nixpi.headscale.settings.dns.base_domain or "";
          "nixpi-tests/tailnet-enable".text = if config.nixpi.tailnet.enable then "yes" else "no";
          "nixpi-tests/tailnet-login-server".text = config.nixpi.tailnet.loginServer;
          "nixpi-tests/tailnet-auth-key-file".text = config.nixpi.tailnet.authKeyFile;
          "nixpi-tests/tailnet-hostname".text = config.nixpi.tailnet.hostname or "";
          "nixpi-tests/tailnet-extra-up-flags".text =
            lib.concatStringsSep " " config.nixpi.tailnet.extraUpFlags;
        };
      };
  };

  testScript = ''
    defaults = machines[0]
    overrides = machines[1]

    defaults.start()
    defaults.wait_for_unit("multi-user.target", timeout=300)

    defaults.succeed("id pi")
    defaults.succeed("systemctl cat nixpi-broker.service >/dev/null")
    defaults.succeed("systemctl cat nixpi-update.timer >/dev/null")

    broker_cfg = defaults.succeed(
        "systemctl show nixpi-broker.service -p Environment --value"
        " | grep -oP 'NIXPI_BROKER_CONFIG=\\K\\S+'"
    ).strip()
    defaults.succeed(f"grep -q maintain {broker_cfg}")

    defaults.succeed("systemctl is-active fail2ban")
    defaults.succeed("grep -qx 'no' /etc/nixpi-tests/ssh-password-auth")
    defaults.succeed("grep -qx 'yes' /etc/nixpi-tests/has-headscale-option")
    defaults.succeed("grep -qx 'yes' /etc/nixpi-tests/has-tailnet-option")
    defaults.succeed("grep -qx 'no' /etc/nixpi-tests/has-wireguard-option")

    overrides.start()
    overrides.wait_for_unit("multi-user.target", timeout=300)

    overrides.fail("systemctl is-active fail2ban")
    overrides.succeed("grep -qx 'yes' /etc/nixpi-tests/ssh-password-auth")
    broker_cfg = overrides.succeed(
        "systemctl show nixpi-broker.service -p Environment --value"
        " | grep -oP 'NIXPI_BROKER_CONFIG=\\K\\S+'"
    ).strip()
    overrides.succeed(f"grep -q observe {broker_cfg}")

    overrides.succeed("grep -qx 'yes' /etc/nixpi-tests/headscale-enable")
    overrides.succeed("grep -qx 'https://headscale.example.test' /etc/nixpi-tests/headscale-server-url")
    overrides.succeed("grep -qx '/run/secrets/headscale-policy.hujson' /etc/nixpi-tests/headscale-policy-file")
    overrides.succeed("grep -qx 'tailnet.example.test' /etc/nixpi-tests/headscale-base-domain")
    overrides.succeed("grep -qx 'yes' /etc/nixpi-tests/tailnet-enable")
    overrides.succeed("grep -qx 'https://headscale.example.test' /etc/nixpi-tests/tailnet-login-server")
    overrides.succeed("grep -qx '/run/secrets/tailscale-auth-key' /etc/nixpi-tests/tailnet-auth-key-file")
    overrides.succeed("grep -qx 'nixpi-managed-node' /etc/nixpi-tests/tailnet-hostname")
    overrides.succeed("grep -qx -- '--accept-dns=false --ssh' /etc/nixpi-tests/tailnet-extra-up-flags")

    print("All nixpi-options-validation tests passed!")
  '';
}
