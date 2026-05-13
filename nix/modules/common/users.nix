{ pkgs, ... }:
let
  humanAdminKeys = import ../../users/admin-keys.nix;
  nazarMicrovmAdminKeys = import ../../users/nazar-microvm-admin-keys.nix;
  adminKeys = humanAdminKeys ++ nazarMicrovmAdminKeys;
  rootBreakGlassHashFile = "/var/lib/nazar/secrets/root-password-hash";
in
{
  # VM users are declarative and immutable. `alex` is the canonical human
  # administrator on every NixOS VM; root remains key-only for current
  # compatibility and break-glass administration.
  users.mutableUsers = false;

  users.users.root = {
    openssh.authorizedKeys.keys = adminKeys;
    # Lock password login. Do not add shared VM passwords here.
    hashedPassword = "!";
  };

  users.users.alex = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = adminKeys;
    # Normal VM access is key-only. Future console break-glass passwords, if
    # ever needed, must be unique per VM and delivered through encrypted secret
    # material such as sops-nix, not plaintext Nix or git.
    hashedPassword = "!";
  };

  security.sudo.wheelNeedsPassword = false;

  systemd.tmpfiles.rules = [
    # Keep the VM admin home owned by alex even when child virtiofs mounts
    # are created early. OpenSSH StrictModes checks the home directory before
    # accepting declarative /etc/ssh/authorized_keys.d keys.
    "d /home/alex 0750 alex users - -"
    "d /var/lib/nazar 0750 root root -"
    "d /var/lib/nazar/secrets 0700 root root -"
  ];

  assertions = [
    {
      assertion = nazarMicrovmAdminKeys != [ ];
      message = "MicroVMs must trust at least one Nazar-host-only SSH key for one-way host -> VM administration.";
    }
  ];

  # Optional console break-glass password. SSH password auth remains
  # disabled in security.nix; this only makes root password usable from a real
  # console/recovery path when the external secret file has been provisioned.
  system.activationScripts.nazar-root-break-glass-password = {
    deps = [ "users" ];
    text = ''
      if [ -s ${rootBreakGlassHashFile} ]; then
        chown root:root ${rootBreakGlassHashFile}
        chmod 0600 ${rootBreakGlassHashFile}
        IFS= read -r root_hash < ${rootBreakGlassHashFile}
        if [ -n "$root_hash" ]; then
          printf 'root:%s\n' "$root_hash" | ${pkgs.shadow}/bin/chpasswd --encrypted
        fi
      fi
    '';
  };
}
