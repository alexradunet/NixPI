{
  config,
  fleet,
  lib,
  ...
}:
let
  minecraft = fleet.services.minecraft;
  mcPort = minecraft.minecraft.port or 25565;
  mcVoicePort = minecraft.minecraft.voiceChatPort or 24454;
in
{
  networking.firewall = {
    enable = true;
    allowPing = true;
    checkReversePath = "loose";

    allowedTCPPorts = lib.mkAfter [ mcPort ];
    allowedUDPPorts = lib.mkAfter [ mcVoicePort ];
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = false;
    "net.ipv6.conf.all.forwarding" = false;
  };

  assertions = [
    {
      assertion = config.services.minecraft-server.enable;
      message = "Minecraft must run as a host NixOS service.";
    }
  ];
}
