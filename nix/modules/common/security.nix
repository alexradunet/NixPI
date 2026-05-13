{ lib, ... }:
{
  services.openssh = {
    enable = true;
    # Accept only the declarative NixOS authorized_keys files. Do not accept
    # unmanaged per-home ~/.ssh/authorized_keys drift on fleet VMs.
    authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
    # Keep guest SSH host identity stable across ephemeral root reboots. The
    # backing directory is a host-provided virtiofs share declared in
    # nix/modules/host/microvm-guest.nix and created by microvm-host.nix.
    hostKeys = [
      {
        path = "/var/lib/nazar/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      # VM administration is key-only via `alex` from the host `nazar`
      # over private NAT aliases. Root SSH is kept key-only for break-glass and
      # current compatibility, not as the canonical human login.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
      # VM authorized keys are declarative root-owned files under /etc, while
      # some guest homes contain early virtiofs mountpoints. Do not let home
      # directory mode drift block Nazar's one-way SSH administration path.
      StrictModes = false;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/nazar 0750 root root - -"
    "d /var/lib/nazar/ssh 0700 root root - -"
  ];

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 22 ];
  };
}
