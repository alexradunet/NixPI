{ lib, config, ... }:

let
  absolutePath = lib.types.pathWith { absolute = true; };
in
{
  options.nixpi.gateway = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the generic NixPI gateway framework is managed as system services.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "nixpi-gateway";
      description = "System account that runs the generic gateway and its transport daemons.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "nixpi-gateway";
      description = "Primary group for the gateway system account.";
    };

    stateDir = lib.mkOption {
      type = absolutePath;
      default = "${config.nixpi.stateDir}/gateway";
      description = "Absolute path holding generic gateway runtime state such as SQLite metadata, Pi sessions, and transport-specific state.";
    };

    legacyStateDir = lib.mkOption {
      type = absolutePath;
      default = "${config.nixpi.stateDir}/signal-gateway";
      description = "Previous dedicated Signal gateway state root used as the source for one-time migration into the generic gateway state directory.";
    };

    legacyRootStateDir = lib.mkOption {
      type = absolutePath;
      default = "/root/.local/state/nixpi-signal-gateway";
      description = "Older root-owned Signal gateway runtime state path used as an additional one-time migration source.";
    };

    agentDir = lib.mkOption {
      type = absolutePath;
      default = "${config.nixpi.stateDir}/gateway-pi";
      description = "Service-owned Pi agent directory containing auth, settings, copied extensions, and local packages for the generic gateway account.";
    };

    legacyAgentDir = lib.mkOption {
      type = absolutePath;
      default = "${config.nixpi.stateDir}/signal-gateway-pi";
      description = "Previous dedicated Signal gateway Pi home used as the source for one-time migration into the generic gateway Pi home.";
    };

    sourceAgentDir = lib.mkOption {
      type = absolutePath;
      default = config.nixpi.agent.piDir;
      description = "Source Pi agent directory used to seed the generic gateway service-owned agent home when no migrated copy exists yet.";
    };

    workspaceDir = lib.mkOption {
      type = absolutePath;
      default = config.nixpi.agent.workspaceDir;
      description = "Workspace path the gateway service user may access so channel sessions can operate on the main NixPI workspace.";
    };

    homeTraversePath = lib.mkOption {
      type = absolutePath;
      default = "/home/${config.nixpi.primaryUser}";
      description = "Parent home path that receives execute-only ACL access so the gateway service user can reach the configured workspace directory.";
    };

    piCwd = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.nixpi.primaryUser}";
      description = "Working directory used as the Pi SDK cwd for gateway conversations.";
    };

    defaultProvider = lib.mkOption {
      type = lib.types.str;
      default = "cortecs";
      description = "Default Pi provider used by the gateway's dedicated Pi home.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "minimax-m2.5";
      description = "Default Pi model used by the gateway's dedicated Pi home.";
    };

    packagePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${config.nixpi.gateway.agentDir}/agent/local-packages/node_modules/@jarcelao/pi-exa-api"
      ];
      description = "Package paths written into the gateway's dedicated agent/settings.json.";
    };

    extensionPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "${config.nixpi.gateway.agentDir}/agent/extensions/wireguard-manager.ts" ];
      description = "Extension paths written into the gateway's dedicated agent/settings.json.";
    };

    maxReplyChars = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1400;
      description = "Maximum characters per gateway reply chunk.";
    };

    maxReplyChunks = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Maximum number of reply chunks emitted for a single Pi response.";
    };

    modules.signal = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the Signal transport module is enabled under the generic gateway.";
      };

      account = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Signal account number used by the Signal transport module, for example +15550001111.";
      };

      allowedNumbers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Phone numbers allowed to chat through the Signal transport module.";
      };

      adminNumbers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Phone numbers treated as Signal transport admins for built-in commands and future policy hooks.";
      };

      stateDir = lib.mkOption {
        type = absolutePath;
        default = "${config.nixpi.gateway.stateDir}/modules/signal";
        description = "Signal transport state root under the generic gateway state directory.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Loopback HTTP port exposed by the native signal-cli daemon for the Signal transport module.";
      };

      directMessagesOnly = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the Signal transport module accepts only direct Signal messages.";
      };
    };
  };
}
