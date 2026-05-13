{ fleet, lib, ... }:
let
  public = {
    ipv4 = "167.235.12.22";
    ipv4Gateway = "167.235.12.1";
    ipv6 = "2a01:4f8:262:1b01::2/64";
    ipv6Gateway = "fe80::1";
    nicName = "enp0s31f6";
    nicMac = "90:1b:0e:9e:eb:f6";
  };

  tapNetwork = name: vm: {
    name = "30-${vm.microvm.tap}";
    value = {
      matchConfig.Name = vm.microvm.tap;
      addresses = [ { Address = "${fleet.defaults.gateway}/32"; } ];
      routes = [ { Destination = "${vm.ip}/32"; } ];
      networkConfig = {
        DHCP = "no";
        IPv4Forwarding = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  vmHostEntry = _name: vm: {
    name = vm.ip;
    value = [
      vm.hostname
      "${vm.hostname}.${fleet.defaults.domain}"
    ];
  };
in
{
  networking = {
    hostName = "nazar";
    domain = fleet.defaults.domain;
    useDHCP = false;
    useNetworkd = true;
    nameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];

    # Make host -> MicroVM SSH/deploy use the private routed VM addresses.
    hosts = lib.mapAttrs' vmHostEntry fleet.vms;
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    links."10-uplink-name" = {
      matchConfig.MACAddress = public.nicMac;
      linkConfig.Name = public.nicName;
    };

    networks = {
      "10-uplink" = {
        matchConfig.MACAddress = public.nicMac;
        addresses = [
          {
            Address = "${public.ipv4}/32";
            Peer = "${public.ipv4Gateway}/32";
          }
          { Address = public.ipv6; }
        ];
        routes = [
          {
            Gateway = public.ipv4Gateway;
            GatewayOnLink = true;
          }
          {
            Gateway = public.ipv6Gateway;
            GatewayOnLink = true;
          }
        ];
        networkConfig = {
          DHCP = "no";
          DNS = [
            "1.1.1.1"
            "9.9.9.9"
          ];
          IPv6AcceptRA = false;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    }
    // lib.mapAttrs' tapNetwork fleet.vms;
  };

  assertions = [
    {
      assertion = lib.all (vm: vm ? microvm && vm.microvm ? tap && vm.microvm ? mac) (
        lib.attrValues fleet.vms
      );
      message = "Every VM in nix/fleet/vms.nix must define microvm.tap and microvm.mac.";
    }
  ];
}
