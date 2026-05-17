{ fleet, lib, ... }:
let
  hostIdentity = import ../../fleet/host.nix;
  privateDomains = import ../../fleet/private-domains.nix { inherit fleet lib; };
in
{
  # Private services bind to a host-local dummy address. sshuttle clients route
  # this address over SSH, while the address is never exposed on the public NIC.
  systemd.network.netdevs."20-${hostIdentity.private.interfaceName}" = {
    netdevConfig = {
      Name = hostIdentity.private.interfaceName;
      Kind = "dummy";
    };
  };

  systemd.network.networks."20-${hostIdentity.private.interfaceName}" = {
    matchConfig.Name = hostIdentity.private.interfaceName;
    addresses = [ { Address = hostIdentity.private.cidr; } ];
    networkConfig = {
      DHCP = "no";
      LinkLocalAddressing = "no";
    };
    linkConfig.RequiredForOnline = "no";
  };

  # Keep host-local commands aligned with the same private service view that
  # sshuttle clients get declaratively in nix/modules/laptop/nazar-sshuttle.nix.
  networking.hosts.${hostIdentity.private.ip} = privateDomains;
}
