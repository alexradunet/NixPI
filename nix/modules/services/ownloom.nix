{
  inputs,
  lib,
  vm,
  ...
}:
{
  imports = [
    inputs.ownloom.nixosModules.ownloom-core
    inputs.ownloom.nixosModules.ownloom-web
  ];

  assertions = [
    {
      assertion = vm.service == "ownloom";
      message = "The OwnLoom service module should only be imported by the ownloom VM.";
    }
    {
      assertion = (vm.ownloom.web.httpPort or 80) == 80;
      message = "OwnLoom is expected to expose HTTP on port 80 inside the private MicroVM network.";
    }
    {
      assertion = vm.dns == "ownloom.nazar.studio";
      message = "OwnLoom canonical private DNS must be ownloom.nazar.studio.";
    }
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/ownloom/secrets 0700 root root - -"
  ];

  # OwnLoom intentionally runs the phase-1 private web UI as the VM admin user
  # through the upstream module, so it can drive Pi/self-evolution workflows.
  # Keep exposure WireGuard-only.
}
