{ lib }:

let
  base = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    LockPersonality = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
  };
in
{
  root = extra: base // extra;

  nonRoot =
    extra:
    base
    // {
      AmbientCapabilities = [ ];
      CapabilityBoundingSet = [ "" ];
    }
    // extra;
}
