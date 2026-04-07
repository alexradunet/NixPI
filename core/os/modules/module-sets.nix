{
  nixpiBaseNoShell = [
    ./options.nix
    ./network.nix
    ./update.nix
  ];

  nixpiBase = [
    ./options.nix
    ./network.nix
    ./update.nix
    ./shell.nix
  ];

  nixpiNoShell = [
    ./options.nix
    ./network.nix
    ./update.nix
    ./app.nix
    ./broker.nix
    ./service-surface.nix
    ./tooling.nix
    ./ttyd.nix
  ];

  nixpi = [
    ./options.nix
    ./network.nix
    ./update.nix
    ./app.nix
    ./broker.nix
    ./service-surface.nix
    ./tooling.nix
    ./shell.nix
    ./ttyd.nix
  ];
}
