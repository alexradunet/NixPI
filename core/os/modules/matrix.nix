# core/os/modules/matrix.nix
{ pkgs, config, lib, ... }:

{
  imports = [ ./options.nix ];

  assertions = [
    {
      assertion = config.nixpi.matrix.bindAddress != "";
      message = "nixpi.matrix.bindAddress must not be empty.";
    }
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/matrix-synapse 0750 matrix-synapse matrix-synapse -"
    "d /var/lib/matrix-synapse/media_store 0750 matrix-synapse matrix-synapse -"
  ];

  services.matrix-synapse = {
    enable = true;
    
    settings = {
      server_name = config.networking.hostName;
      public_baseurl = "http://localhost:${toString config.nixpi.matrix.port}";
      
      listeners = [
        {
          port = config.nixpi.matrix.port;
          bind_addresses = [ config.nixpi.matrix.bindAddress ];
          type = "http";
          tls = false;
          x_forwarded = false;
          resources = [
            {
              names = [ "client" "federation" ];
              compress = true;
            }
          ];
        }
      ];
      
      # Use SQLite for simplicity (suitable for single-user/embedded use)
      database.name = "sqlite3";
      database.args = {
        database = "/var/lib/matrix-synapse/homeserver.db";
      };
      
      # Registration settings
      enable_registration = config.nixpi.matrix.enableRegistration;
      enable_registration_without_verification = true;
      suppress_key_server_warning = true;
      
      # Don't require email verification
      registrations_require_3pid = [];
      
      # Disable federation (private homeserver)
      federation_domain_whitelist = [];
      
      # Limit request size for file uploads
      max_upload_size = config.nixpi.matrix.maxUploadSize;
      
      # Disable presence (reduces resource usage)
      use_presence = false;
      
      # URL preview settings
      url_preview_enabled = false;
    };
    
    # Extra configuration lines for registration shared secret
    extraConfigFiles = [ "/var/lib/matrix-synapse/extra.yaml" ];
  };

  # Override the systemd service to add bootstrap script and ensure proper ordering
  systemd.services.matrix-synapse = {
    serviceConfig = {
      # Ensure data directory exists with proper permissions
      StateDirectory = "matrix-synapse";
      StateDirectoryMode = "0750";
    };
    preStart = ''
      # Bootstrap registration shared secret if not exists
      TOKEN_FILE=/var/lib/matrix-synapse/registration_shared_secret
      MACAROON_FILE=/var/lib/matrix-synapse/macaroon_secret_key
      if [ ! -f "$TOKEN_FILE" ]; then
        ${pkgs.openssl}/bin/openssl rand -hex 32 > "$TOKEN_FILE"
        chmod 640 "$TOKEN_FILE"
      fi

      if [ ! -f "$MACAROON_FILE" ]; then
        ${pkgs.openssl}/bin/openssl rand -hex 32 > "$MACAROON_FILE"
        chmod 640 "$MACAROON_FILE"
      fi
      
      # Append generated secrets to the config.
      if [ -f "$TOKEN_FILE" ] && [ -f "$MACAROON_FILE" ]; then
        SECRET=$(cat "$TOKEN_FILE")
        MACAROON_SECRET=$(cat "$MACAROON_FILE")
        cat > /var/lib/matrix-synapse/extra.yaml <<EOF
registration_shared_secret: "$SECRET"
macaroon_secret_key: "$MACAROON_SECRET"
EOF
        chmod 640 /var/lib/matrix-synapse/extra.yaml
      fi
    '';
  };

  # Ensure openssl is available for bootstrap
  environment.systemPackages = [ pkgs.openssl ];

  warnings = lib.optional config.nixpi.matrix.enableRegistration ''
    nixPI keeps Matrix registration enabled to support unattended setup. The
    firewall policy should stay enabled so Matrix is exposed only on
    `${config.nixpi.security.trustedInterface}`.
  '';
}
