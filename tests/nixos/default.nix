# tests/nixos/default.nix
# NixOS integration test suite for Workspace OS
#
# Usage:
#   nix build .#checks.x86_64-linux.workspace-matrix
#   nix build .#checks.x86_64-linux.workspace-firstboot
#   nix build .#checks.x86_64-linux.localai
#   nix build .#checks.x86_64-linux.workspace-network
#   nix build .#checks.x86_64-linux.workspace-daemon
#   nix build .#checks.x86_64-linux.workspace-e2e
#   nix build .#checks.x86_64-linux.workspace-home
#
# Or run all: nix flake check

{ pkgs, lib, piAgent, appPackage }:

let
  # Import shared helpers
  testLib = import ./lib.nix { inherit pkgs lib; };
  
  inherit (testLib) workspaceModules workspaceModulesNoShell mkWorkspaceNode mkTestFilesystems;
  
  # Test function with common dependencies
  mkTest = testFile: import testFile {
    inherit pkgs lib workspaceModules workspaceModulesNoShell piAgent appPackage mkWorkspaceNode mkTestFilesystems;
  };
in
{
  # Matrix homeserver test
  workspace-matrix = mkTest ./workspace-matrix.nix;
  
  # First-boot wizard test
  workspace-firstboot = mkTest ./workspace-firstboot.nix;
  
  # LocalAI inference test (with test model)
  localai = mkTest ./localai.nix;
  
  # Network connectivity test
  workspace-network = mkTest ./workspace-network.nix;
  
  # Pi daemon test
  workspace-daemon = mkTest ./workspace-daemon.nix;
  
  # End-to-end integration test
  workspace-e2e = mkTest ./workspace-e2e.nix;

  # Workspace Home landing page and user service test
  workspace-home = mkTest ./workspace-home.nix;
}
