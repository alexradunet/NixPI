{
  imports = [
    ../../modules/dav-server.nix
  ];

  # Canonical guest module for the Nazar MicroVM orchestrator. Hardware,
  # networking, lifecycle, and persistence are composed by the nazar fleet
  # baseline; this repository owns only DAV service behavior.
  system.stateVersion = "26.05";
}
