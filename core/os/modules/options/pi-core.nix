{ lib, config, ... }:

let
  absolutePath = lib.types.pathWith { absolute = true; };
in
{
  options.nixpi.piCore = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the always-on Pi core local API service is enabled.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "nixpi-core";
      description = "System account that runs the Pi core local API service.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "nixpi-core";
      description = "Primary group for the Pi core service account.";
    };

    stateDir = lib.mkOption {
      type = absolutePath;
      default = "${config.nixpi.stateDir}/pi-core";
      description = "Absolute path holding Pi core runtime state.";
    };

    sessionDir = lib.mkOption {
      type = absolutePath;
      default = "${config.nixpi.piCore.stateDir}/sessions";
      description = "Directory holding Pi core session files.";
    };

    legacySessionDir = lib.mkOption {
      type = absolutePath;
      default = "${config.nixpi.gateway.stateDir}/pi-sessions";
      description = "Previous gateway-owned Pi session directory used as the source for one-time migration into Pi core.";
    };

    agentDir = lib.mkOption {
      type = absolutePath;
      default = "${config.nixpi.stateDir}/pi-core-pi";
      description = "Service-owned Pi home for the always-on Pi core service.";
    };

    legacyAgentDir = lib.mkOption {
      type = absolutePath;
      default = "${config.nixpi.gateway.agentDir}";
      description = "Previous gateway-owned Pi home used as the source for one-time migration into Pi core.";
    };

    sourceAgentDir = lib.mkOption {
      type = absolutePath;
      default = config.nixpi.agent.piDir;
      description = "Source Pi agent directory used to seed the Pi core service-owned home when no migrated copy exists yet.";
    };

    workspaceDir = lib.mkOption {
      type = absolutePath;
      default = config.nixpi.agent.workspaceDir;
      description = "Workspace path the Pi core service may access while handling prompts.";
    };

    homeTraversePath = lib.mkOption {
      type = absolutePath;
      default = "/home/${config.nixpi.primaryUser}";
      description = "Parent home path that receives execute-only ACL access so the Pi core service user can reach the configured workspace directory.";
    };

    piCwd = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.nixpi.primaryUser}";
      description = "Working directory used as the Pi SDK cwd for the Pi core service.";
    };

    defaultProvider = lib.mkOption {
      type = lib.types.str;
      default = "cortecs";
      description = "Default Pi provider used by the Pi core service-owned home.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "minimax-m2.5";
      description = "Default Pi model used by the Pi core service-owned home.";
    };

    packagePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${config.nixpi.piCore.agentDir}/agent/local-packages/node_modules/@jarcelao/pi-exa-api"
      ];
      description = "Package paths written into the Pi core service-owned agent/settings.json.";
    };

    extensionPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "${config.nixpi.piCore.agentDir}/agent/extensions/wireguard-manager.ts" ];
      description = "Extension paths written into the Pi core service-owned agent/settings.json.";
    };

    socketPath = lib.mkOption {
      type = absolutePath;
      default = "/run/nixpi-pi-core/pi-core.sock";
      description = "Unix socket path exposed by the Pi core local API service.";
    };
  };
}
