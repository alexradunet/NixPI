{ fleet, vm, ... }:
let
  defaults = fleet.defaults;
  interface = vm.interface or defaults.interface;
in
{
  networking.hostName = vm.hostname;
  networking.domain = defaults.domain;
  networking.useDHCP = false;
  networking.interfaces.${interface}.ipv4.addresses = [
    {
      address = vm.ip;
      prefixLength = defaults.prefixLength;
    }
  ];
  networking.defaultGateway = defaults.gateway;
  networking.nameservers = defaults.nameservers;

  assertions = [
    {
      assertion = vm ? ip;
      message = "Every concrete VM must define a static NAT IP in nix/fleet/vms.nix.";
    }
  ];
}
