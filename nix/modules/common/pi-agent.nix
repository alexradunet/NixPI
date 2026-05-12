{
  config,
  inputs,
  lib,
  pkgs,
  vm,
  ...
}:
let
  repoName =
    {
      git = "forgejo";
      minecraft = "minecraft";
      ownloom-data = "ownloom-data";
    }
    .${vm.hostname} or vm.hostname;
  repoRoot = "/home/alex/${repoName}";
  repoUrl = "ssh://git@10.10.10.21:10022/nazar/${repoName}.git";
  piPackage = inputs.ownloom.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  globalSettings = pkgs.writeText "nazar-vm-pi-global-settings.json" (
    builtins.toJSON {
      packages = [ ];
      extensions = [ ];
      skills = [ ];
      prompts = [ ];
      themes = [ ];
    }
  );
  projectSettings = pkgs.writeText "nazar-vm-pi-project-settings.json" (
    builtins.toJSON {
      packages = [ ];
    }
  );
  bootstrap = pkgs.writeShellScriptBin "nazar-vm-repo-bootstrap" ''
    set -euo pipefail

    repo_name=${lib.escapeShellArg repoName}
    repo_root=${lib.escapeShellArg repoRoot}
    repo_url=${lib.escapeShellArg repoUrl}

    mkdir -p "$repo_root/.pi"
    cd "$repo_root"

    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"

    if [ ! -d .git ]; then
      git init -b main
    fi

    if git remote get-url origin >/dev/null 2>&1; then
      git remote set-url origin "$repo_url"
    else
      git remote add origin "$repo_url"
    fi

    git fetch origin main
    git checkout -B main --track origin/main

    echo "VM repo ready: $repo_root ($repo_url)"
    echo "Pi will load Nazar VM instructions from /home/alex/.pi/agent/AGENTS.md."
    echo "You may edit, test, commit, and push here; production deploys are handed off with: nazar-deploy-request"
    echo "Next: cd $repo_root && pi"
  '';
in
{
  environment.systemPackages = [
    piPackage
    pkgs.nodejs
    bootstrap
  ];

  environment.sessionVariables = {
    PI_CODING_AGENT_DIR = "/home/alex/.pi/agent";
    PI_SKIP_VERSION_CHECK = "1";
    PI_TELEMETRY = "0";
    NAZAR_VM_REPO = repoRoot;
  };

  systemd.tmpfiles.rules = [
    "d /home/alex/.pi 0755 alex users - -"
    "d /home/alex/.pi/agent 0755 alex users - -"
    "d ${repoRoot} 0755 alex users - -"
    "d ${repoRoot}/.pi 0755 alex users - -"
  ];

  system.activationScripts.nazar-vm-pi-settings = lib.stringAfter [ "users" ] ''
    install -d -m 0755 -o alex -g users /home/alex/.pi/agent
    install -d -m 0755 -o alex -g users ${lib.escapeShellArg "${repoRoot}/.pi"}
    install -m 0644 -o alex -g users ${lib.escapeShellArg globalSettings} /home/alex/.pi/agent/settings.json
    install -m 0644 -o alex -g users ${lib.escapeShellArg projectSettings} ${lib.escapeShellArg "${repoRoot}/.pi/settings.json"}
  '';
}
