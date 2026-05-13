{
  inputs,
  nixpkgs,
  system,
  fleet,
}:
{
  name,
  vm,
  modules ? [ ],
}:
nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit
      inputs
      fleet
      vm
      ;
  };

  modules = modules ++ [
    {
      assertions = [
        {
          assertion = vm.hostname == name;
          message = "Fleet inventory hostname must match nixosConfigurations.${name}.";
        }
      ];
    }
  ];
}
