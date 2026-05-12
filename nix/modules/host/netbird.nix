{ pkgs, ... }:
{
  services.resolved.enable = true;

  services.netbird = {
    enable = true;
    # This host is the routing peer for the private MicroVM subnet and the
    # NetBird SSH target for human shell access.
    useRoutingFeatures = "both";
    clients.default = {
      # NetBird SSH needs to be able to switch to local users on NixOS.
      hardened = false;
      config = {
        ServerSSHAllowed = true;
        EnableSSHRoot = false;
        EnableSSHSFTP = false;
        EnableSSHLocalPortForwarding = false;
        EnableSSHRemotePortForwarding = false;
        DisableSSHAuth = false;
      };
    };
  };

  systemd.services.netbird.path = [
    pkgs.shadow
    pkgs.iproute2
    pkgs.iptables
  ];

  systemd.services.nazar-netbird-bootstrap = {
    description = "Enroll nazar into NetBird once from an out-of-git setup key";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "netbird.service"
    ];
    wants = [
      "network-online.target"
      "netbird.service"
    ];
    path = [
      pkgs.coreutils
      pkgs.getent
      pkgs.gnugrep
      pkgs.netbird
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      set -eu

      key_file=/var/lib/nazar/bootstrap/netbird-setup-key

      for _ in $(seq 1 30); do
        if getent hosts api.netbird.io >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      if netbird status 2>/dev/null | grep -qx 'Management: Connected' \
        && netbird status 2>/dev/null | grep -qx 'Signal: Connected'; then
        echo "NetBird already connected; bootstrap not needed."
        rm -f "$key_file" 2>/dev/null || true
        exit 0
      fi

      if [ ! -s "$key_file" ]; then
        echo "No $key_file present; NetBird bootstrap skipped."
        exit 0
      fi

      chown root:root "$key_file"
      chmod 0600 "$key_file"

      netbird up \
        --hostname nazar \
        --allow-server-ssh \
        --setup-key-file "$key_file"

      if netbird status 2>/dev/null | grep -qx 'Management: Connected' \
        && netbird status 2>/dev/null | grep -qx 'Signal: Connected'; then
        shred -u "$key_file" 2>/dev/null || rm -f "$key_file"
      else
        echo "NetBird enrollment command returned, but connected status was not reached yet." >&2
        exit 1
      fi
    '';
  };
}
