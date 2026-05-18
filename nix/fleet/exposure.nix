{
  # Declarative HTTP exposure policy for host nginx.
  #
  # access = "private" serves the route only on the sshuttle-routed private
  # address, 10.44.0.1.
  # access = "public" additionally exposes the route on the host public IPv4
  # and opens TCP/80. Only use after an explicit hardening review.

  privateDomainExclusions = [ ];

  host = {
    nixpi = {
      enable = true;
      domain = "nixpi.nazar.studio";
      port = 4815;
      access = "private";
      localTunnelAliases = [
        "127.0.0.1"
        "localhost"
      ];
    };

    code = {
      enable = true;
      domain = "code.nazar.studio";
      port = 4821;
      access = "private";
    };

    dav = {
      enable = true;
      domain = "dav.nazar.studio";
      access = "private";
    };
  };
}
