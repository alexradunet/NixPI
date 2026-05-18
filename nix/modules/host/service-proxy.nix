{ lib, ... }:
let
  exposure = import ../../fleet/exposure.nix;
  hostIdentity = import ../../fleet/host.nix;
  privateIp = hostIdentity.private.ip;
  publicIp = hostIdentity.public.ipv4;
  hostNixpi = exposure.host.nixpi or { };
  hostCode = exposure.host.code or { };

  isPublic = route: (route.access or "private") == "public";
  isRouted = route: route.enable or false;
  routeOnPrivateAccess =
    route:
    isRouted route
    && lib.elem (route.access or "private") [
      "private"
      "public"
    ];

  proxyBase = {
    proxyWebsockets = true;
    extraConfig = ''
      client_max_body_size 25m;
      proxy_read_timeout 3600s;
      proxy_send_timeout 3600s;
    '';
  };

  mkVhost =
    {
      domain,
      addr,
      route,
    }:
    {
      serverName = domain;
      listen = [
        {
          inherit addr;
          port = 80;
        }
      ];
      locations."/" = proxyBase // {
        proxyPass = route.backend;
      };
    };

  mkDomainVhosts =
    domain: route:
    (lib.optional (routeOnPrivateAccess route) {
      name = "${domain}-private";
      value = mkVhost {
        inherit domain route;
        addr = privateIp;
      };
    })
    ++ (lib.optional (isRouted route && isPublic route) {
      name = "${domain}-public";
      value = mkVhost {
        inherit domain route;
        addr = publicIp;
      };
    });

  hostNixpiRoute = {
    name = "host-nixpi";
    enable = hostNixpi.enable or false;
    backend = "http://127.0.0.1:${toString (hostNixpi.port or 4815)}";
    access = hostNixpi.access or "private";
  };

  hostCodeRoute = {
    name = "host-code";
    enable = hostCode.enable or false;
    backend = "http://127.0.0.1:${toString (hostCode.port or 4821)}";
    access = hostCode.access or "private";
  };

  nixpiOwnDomain = hostNixpi.domain or null;
  nixpiTunnelAliases = hostNixpi.localTunnelAliases or [ ];
  codeOwnDomain = hostCode.domain or null;

  nixpiDomainVhosts = lib.optionals (nixpiOwnDomain != null && (hostNixpi.enable or false)) (
    mkDomainVhosts nixpiOwnDomain hostNixpiRoute
  );
  nixpiTunnelAliasVhosts = lib.optionals ((hostNixpi.enable or false) && nixpiTunnelAliases != [ ]) (
    lib.concatMap (
      domain: mkDomainVhosts domain (hostNixpiRoute // { access = "private"; })
    ) nixpiTunnelAliases
  );
  codeDomainVhosts = lib.optionals (codeOwnDomain != null && (hostCode.enable or false)) (
    mkDomainVhosts codeOwnDomain hostCodeRoute
  );
  allRoutes = [
    hostNixpiRoute
    hostCodeRoute
  ];
  publicHttpEnabled = lib.any (route: isRouted route && isPublic route) allRoutes;
in
{
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;

    virtualHosts = lib.listToAttrs (nixpiDomainVhosts ++ nixpiTunnelAliasVhosts ++ codeDomainVhosts);
  };

  systemd.services.nginx = {
    after = [
      "network-online.target"
      "nixpi-bun.service"
      "openvscode-server.service"
    ];
    wants = [ "network-online.target" ];
  };

  networking.firewall.allowedTCPPorts = lib.mkIf publicHttpEnabled [ 80 ];
}
