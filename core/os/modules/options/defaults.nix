{ lib, config, ... }:

let
  bootstrapCfg = config.nixpi.bootstrap;
in
{
  config = {
    nixpi.bootstrap.ssh.enable = lib.mkDefault true;
    nixpi.bootstrap.temporaryAdmin.enable = lib.mkDefault bootstrapCfg.enable;
    nixpi.agent.piDir = lib.mkDefault "/home/${config.nixpi.primaryUser}/.pi";
    nixpi.agent.workspaceDir = lib.mkDefault "/home/${config.nixpi.primaryUser}/nixpi";
    nixpi.gateway.enable = lib.mkDefault config.nixpi.gateway.modules.signal.enable;
    nixpi.piCore.enable = lib.mkDefault config.nixpi.gateway.enable;
    nixpi.integrations.exa.envFile = lib.mkDefault "${config.nixpi.stateDir}/secrets/exa.env";
    nixpi.agent.envFiles = lib.mkIf config.nixpi.integrations.exa.enable (
      lib.mkBefore [ config.nixpi.integrations.exa.envFile ]
    );
  };
}
