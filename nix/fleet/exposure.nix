{
  # Declarative HTTP exposure policy for host nginx.
  #
  # This file owns the active host HTTP routes. VM private service domains are
  # derived from nix/fleet/vms.nix `privateAccess`; keep VM service exposure
  # there instead of duplicating it here. service-proxy.nix still tolerates an
  # optional exposure.vms attrset for future non-service VM routes, but no active
  # VM service route is configured from this file.
  #
  # access = "private" serves the route only on the sshuttle-routed private
  # address, 10.44.0.1.
  # access = "public" additionally exposes the route on the host public IPv4
  # and opens TCP/80. Only use after an explicit hardening review.

  # Domains listed here stay out of generated private /etc/hosts entries.
  # Keep this empty so all private domains are routed through sshuttle.
  privateDomainExclusions = [ ];

  host = {
    site = {
      enable = true;
      domain = "nazar.studio";
      root = ../../www/nazar-dashboard;
      access = "public";
    };

    nixpi = {
      enable = true;
      domain = "nixpi.nazar.studio";
      port = 4815;
      access = "private";
      # Support browser access through SSH local forwards, where the browser
      # sends Host: 127.0.0.1:<local-port> or Host: localhost:<local-port>.
      localTunnelAliases = [
        "127.0.0.1"
        "localhost"
      ];
    };
  };
}
