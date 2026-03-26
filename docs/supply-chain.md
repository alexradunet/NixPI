# Supply Chain Notes

NixPI now relies on Nix inputs and Nixpkgs packages for its built-in service surface instead of a separate packaged-service layer.

The important supply-chain boundary is therefore:

- `flake.nix` inputs
- the selected Nixpkgs revision
- NixPI's own source tree

Built-in services such as `nixpi-chat`, the local web chat on `:8080`, and the Pi runtime packages are provisioned from those sources rather than from a mutable runtime package catalog.
