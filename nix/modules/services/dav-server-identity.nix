{ lib, ... }:
{
  # Ephemeral tmpfs root for the dav-server MicroVM. The service module in the
  # dav-server repo does not own filesystems; this guest-level identity module
  # pins the root just like minecraft-identity.nix pins UID/GID.
  fileSystems."/" = {
    device = lib.mkDefault "tmpfs";
    fsType = lib.mkDefault "tmpfs";
    options = lib.mkDefault [
      "size=2G"
      "mode=755"
    ];
  };
}
