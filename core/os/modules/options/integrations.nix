{ lib, ... }:

let
  absolutePath = lib.types.pathWith { absolute = true; };
in
{
  options.nixpi.integrations.exa = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether Exa-backed web search tools are enabled for the Pi runtime.";
    };

    envFile = lib.mkOption {
      type = absolutePath;
      description = "Absolute path to an environment file that provides EXA_API_KEY for the Pi runtime.";
    };
  };
}
