{ lib }:

let
  collect =
    dir:
    let
      entries = builtins.readDir dir;
      names = lib.sort builtins.lessThan (builtins.attrNames entries);
      importEntry =
        name:
        let
          path = dir + "/${name}";
          entryType = entries.${name};
        in
        if entryType == "directory" then
          collect path
        else if entryType == "regular" && lib.hasSuffix ".nix" name && name != "default.nix" then
          [ path ]
        else
          [ ];
    in
    lib.flatten (map importEntry names);
in
collect
