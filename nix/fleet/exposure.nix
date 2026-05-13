{
  # Declarative HTTP exposure policy for host nginx.
  #
  # access = "private" serves the route only on the sshuttle-routed private
  # address, 10.44.0.1.
  # access = "public" additionally exposes the route on the host public IPv4
  # and opens TCP/80. Only use after an explicit hardening review.

  # Keep public game names public on configured laptops. Private operator routes
  # for the Minecraft VM use nixpi-minecraft.nazar.studio instead.
  privateDomainExclusions = [
    "balaur.eu"
    "balaur.nazar.studio"
  ];

  host = {
    nixpi = {
      enable = true;
      domain = "nixpi.nazar.studio";
      port = 4815;
      access = "private";
    };
  };

  vms = {
    git = {
      service = {
        enable = true;
        access = "private";
      };
      nixpi = {
        enable = true;
        path = "/nixpi/";
        access = "private";
      };
      subagent = {
        enable = false;
        path = "/subagent/";
        port = 4815;
        access = "private";
      };
    };

    minecraft = {
      service.enable = false;
      nixpi = {
        enable = true;
        path = "/nixpi/";
        access = "private";
      };
      subagent = {
        enable = false;
        path = "/subagent/";
        port = 4815;
        access = "private";
      };
    };

    dav-server = {
      service = {
        enable = true;
        access = "private";
      };
      nixpi = {
        enable = true;
        path = "/nixpi/";
        access = "private";
      };
      subagent = {
        enable = false;
        path = "/subagent/";
        port = 4815;
        access = "private";
      };
    };
  };
}
