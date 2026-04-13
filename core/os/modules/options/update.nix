{ lib, ... }:

{
  options.nixpi.update = {
    onBootSec = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "Delay before the first automatic update check after boot.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "6h";
      description = "Recurrence interval for the automatic update timer.";
    };
  };
}
