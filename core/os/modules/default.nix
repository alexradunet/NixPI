{ lib, ... }:

let
  importTree = import ../lib/import-tree.nix { inherit lib; };
in
{
  imports = lib.filter (path: builtins.baseNameOf (toString path) != "options.nix") (importTree ./.);
}
