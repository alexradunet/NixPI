# core/os/disk/x86_64-disk.nix
# Declarative disk layout via disko.
# Replaces core/os/disk_config/bib-config.toml filesystem block.
# At install time, run: sudo disko-install --flake .#bloom-x86_64 --disk main /dev/sdX
{
  disk = {
    main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "defaults" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "btrfs";
              mountpoint = "/";
              mountOptions = [ "defaults" "compress=zstd" ];
            };
          };
        };
      };
    };
  };
}
