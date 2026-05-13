{ fleet, lib, ... }:
let
  exposure = import ../../fleet/exposure.nix;
  privateIp = "10.44.0.1";

  isPrivateAccess =
    route:
    (route.enable or false)
    && lib.elem (route.access or "private") [
      "private"
      "public"
    ];

  domainsFor = vm: [ vm.dns ] ++ (vm.aliases or [ ]);

  vmHasPrivateRoute =
    name:
    let
      vmExposure = exposure.vms.${name} or { };
    in
    lib.any isPrivateAccess [
      (vmExposure.service or { })
      (vmExposure.nixpi or { })
      (vmExposure.subagent or { })
    ];

  privateServiceDomains = lib.concatMap (
    name: if vmHasPrivateRoute name then domainsFor fleet.vms.${name} else [ ]
  ) (lib.attrNames fleet.vms);

  privateNixpiDomains = lib.concatMap (
    name:
    let
      vm = fleet.vms.${name};
      vmExposure = exposure.vms.${name} or { };
    in
    lib.optional (isPrivateAccess (vmExposure.nixpi or { })) vm.nixpi.dns
  ) (lib.attrNames fleet.vms);

  hostNixpiDomains = lib.optional (isPrivateAccess (
    exposure.host.nixpi or { }
  )) exposure.host.nixpi.domain;

  privateDomainExclusions = exposure.privateDomainExclusions or [ ];
  privateDomains = lib.subtractLists privateDomainExclusions (
    lib.unique (privateServiceDomains ++ privateNixpiDomains ++ hostNixpiDomains)
  );
in
{
  # Private services bind to a host-local dummy address. sshuttle clients route
  # this address over SSH, while the address is never exposed on the public NIC.
  systemd.network.netdevs."20-nazar-private" = {
    netdevConfig = {
      Name = "nazar-private";
      Kind = "dummy";
    };
  };

  systemd.network.networks."20-nazar-private" = {
    matchConfig.Name = "nazar-private";
    addresses = [ { Address = "${privateIp}/32"; } ];
    networkConfig = {
      DHCP = "no";
      LinkLocalAddressing = "no";
    };
    linkConfig.RequiredForOnline = "no";
  };

  # Keep host-local commands aligned with the same private service view that
  # sshuttle clients get declaratively in nix/modules/laptop/nazar-sshuttle.nix.
  networking.hosts.${privateIp} = privateDomains;
}
