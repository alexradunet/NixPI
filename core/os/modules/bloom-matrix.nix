# core/os/modules/bloom-matrix.nix
{ pkgs, lib, ... }:

{
  environment.etc."bloom/matrix.toml".text = ''
    [global]
    server_name = "bloom"
    database_path = "/var/lib/continuwuity"
    port = [6167]
    address = "0.0.0.0"
    allow_federation = false
    allow_registration = true
    registration_token_file = "/var/lib/continuwuity/registration_token"
    max_request_size = 20000000
    allow_check_for_updates = false
  '';

  systemd.services.bloom-matrix = {
    description = "Bloom Matrix Homeserver (Continuwuity)";
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.openssl pkgs.bash ];

    serviceConfig = {
      Type        = "simple";
      ExecStart   = pkgs.writeShellScript "bloom-matrix-start" ''
        TOKEN_FILE=/var/lib/continuwuity/registration_token
        if [ ! -f "$TOKEN_FILE" ]; then
          openssl rand -base64 32 > "$TOKEN_FILE"
          chmod 640 "$TOKEN_FILE"
        fi
        exec ${pkgs.matrix-continuwuity}/bin/conduwuit
      '';
      Environment = "CONTINUWUITY_CONFIG=/etc/bloom/matrix.toml";
      Restart     = "on-failure";
      RestartSec  = 5;

      # Sandboxing — systemd automatically adds ReadWritePaths for StateDirectory.
      DynamicUser      = true;
      StateDirectory   = "continuwuity";
      RuntimeDirectory = "continuwuity";

      PrivateTmp              = true;
      ProtectSystem           = "strict";
      ProtectHome             = true;
      NoNewPrivileges         = true;
      # DynamicUser already drops all caps; explicit for clarity.
      CapabilityBoundingSet   = "";
      AmbientCapabilities     = "";
      RestrictNamespaces      = true;
      LockPersonality         = true;
      # conduwuit is a Rust binary with no JIT — W+X memory is not needed.
      # If bloom-matrix fails to start, remove MemoryDenyWriteExecute first.
      MemoryDenyWriteExecute  = true;
      RestrictRealtime        = true;
      RestrictSUIDSGID        = true;
      SystemCallFilter        = [ "@system-service" ];
      SystemCallArchitectures = "native";
    };
  };
}
