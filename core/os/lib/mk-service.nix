{ lib }:

{
  description,
  serviceType ? "simple",
  execStart,
  wantedBy ? [ ],
  after ? [ ],
  wants ? [ ],
  unitConfig ? { },
  environment ? [ ],
  workingDirectory ? null,
  execStartPre ? null,
  restart ? null,
  restartSec ? null,
  timeoutStartSec ? null,
  stateDirectory ? null,
  stateDirectoryMode ? "0750",
  readWritePaths ? [ ],
  hardening ? true,
  protectHome ? null,
  serviceConfig ? { },
}:

let
  baseServiceConfig =
    {
      Type = serviceType;
      ExecStart = execStart;
      StandardOutput = "journal";
      StandardError = "journal";
      NoNewPrivileges = lib.mkDefault true;
      PrivateTmp = lib.mkDefault true;
      StartLimitBurst = lib.mkDefault 5;
      StartLimitIntervalSec = lib.mkDefault 60;
    }
    // lib.optionalAttrs (environment != [ ]) {
      Environment = environment;
    }
    // lib.optionalAttrs (workingDirectory != null) {
      WorkingDirectory = workingDirectory;
    }
    // lib.optionalAttrs (execStartPre != null) {
      ExecStartPre = execStartPre;
    }
    // lib.optionalAttrs (restart != null) {
      Restart = restart;
    }
    // lib.optionalAttrs (restartSec != null) {
      RestartSec = restartSec;
    }
    // lib.optionalAttrs (timeoutStartSec != null) {
      TimeoutStartSec = timeoutStartSec;
    }
    // lib.optionalAttrs (stateDirectory != null) {
      StateDirectory = stateDirectory;
      StateDirectoryMode = stateDirectoryMode;
    }
    // lib.optionalAttrs (readWritePaths != [ ]) {
      ReadWritePaths = readWritePaths;
    }
    // lib.optionalAttrs hardening {
      ProtectSystem = lib.mkDefault "strict";
    }
    // lib.optionalAttrs (hardening && protectHome != null) {
      ProtectHome = lib.mkDefault protectHome;
    };
in
{
  inherit description wantedBy after wants unitConfig;
  serviceConfig = baseServiceConfig // serviceConfig;
}
