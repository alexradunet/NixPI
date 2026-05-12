{ fleet, lib, ... }:
let
  minecraft = fleet.vms.minecraft;
  mcPort = minecraft.minecraft.port or 25565;
  mcVoicePort = minecraft.minecraft.voiceChatPort or 24454;
in
{
  networking.nftables.enable = true;

  networking.firewall = {
    enable = true;
    allowPing = true;
    checkReversePath = "loose";

    # Most public host services stay closed here. Public OpenSSH is deliberately
    # opened in nix/modules/host/ssh.nix for alex-only key-based access; root SSH
    # is disabled. Public Minecraft is DNATed to the Minecraft MicroVM below, not
    # accepted as host-local INPUT traffic.
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];

    # NetBird-private host/reverse-proxy surface. 80 serves private Forgejo
    # initially; 443 is reserved for private dashboard/TLS restoration after
    # cutover; 10022 proxies Forgejo Git SSH to the git MicroVM.
    interfaces.wt0.allowedTCPPorts = [
      22
      80
      443
      10022
    ];

    extraForwardRules = ''
      # Let MicroVMs initiate egress and reply traffic through the host.
      ip saddr 10.10.10.0/24 accept
      ip daddr 10.10.10.0/24 ct state established,related accept

      # Allow NetBird-private clients to reach routed MicroVM services once
      # NetBird routes/policies are configured.
      iifname "wt0" ip daddr 10.10.10.0/24 accept

      # Approved public Minecraft exposure.
      iifname "enp0s31f6" ip daddr ${minecraft.ip} tcp dport ${toString mcPort} accept
      iifname "enp0s31f6" ip daddr ${minecraft.ip} udp dport ${toString mcVoicePort} accept
    '';
  };

  networking.nat = {
    enable = true;
    externalInterface = "enp0s31f6";
    externalIP = "167.235.12.22";
    internalIPs = [ "10.10.10.0/24" ];
    forwardPorts = [
      {
        sourcePort = mcPort;
        destination = "${minecraft.ip}:${toString mcPort}";
        proto = "tcp";
      }
      {
        sourcePort = mcVoicePort;
        destination = "${minecraft.ip}:${toString mcVoicePort}";
        proto = "udp";
      }
    ];
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = false;
  };

  assertions = [
    {
      assertion = minecraft.service == "minecraft";
      message = "nix/modules/host/firewall.nix expected fleet.vms.minecraft to be the Minecraft service.";
    }
  ];
}
