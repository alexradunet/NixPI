# NixOS Integration Tests for Workspace OS

This directory contains NixOS integration tests for the Workspace OS platform. These tests use the `pkgs.testers.runNixOSTest` framework to spin up QEMU VMs and verify that Workspace services work correctly together.

## Test Suite

| Test | Description | Duration | Nodes |
|------|-------------|----------|-------|
| `config` | Fast build test of the default installed system closure | ~1 min | None |
| `boot` | Basic VM boot and service startup test | ~3 min | 1 |
| `workspace-matrix` | Matrix homeserver (Conduwuity) functionality | ~3 min | 1 |
| `workspace-firstboot` | First-boot preparation and unattended prefill automation | ~5 min | 1 |
| `localai` | LocalAI inference service with test model | ~10 min | 1 |
| `workspace-network` | Network connectivity and SSH between nodes | ~5 min | 2 |
| `workspace-daemon` | Pi daemon Matrix agent connection | ~5 min | 2 |
| `workspace-e2e` | Full end-to-end integration test | ~10 min | 2 |
| `workspace-home` | Workspace Home plus built-in user web services | ~5 min | 1 |

## Running Tests

### Run all tests
```bash
nix flake check
```

### Run a specific test
```bash
nix build .#checks.x86_64-linux.workspace-matrix --no-link -L
```

### Interactive test driver
```bash
$(nix-build -A checks.x86_64-linux.workspace-matrix.driverInteractive)/bin/nixos-test-driver
>>> workspace.start()
>>> workspace.shell_interact()
```

## Test Structure

```
tests/nixos/
├── lib.nix              # Shared test helpers and module lists
├── default.nix          # Test suite entry point
├── workspace-matrix.nix     # Matrix homeserver test
├── workspace-firstboot.nix  # First-boot wizard test
├── localai.nix    # LocalAI inference test
├── workspace-network.nix    # Network/mesh test
├── workspace-daemon.nix     # Pi daemon test
├── workspace-e2e.nix        # End-to-end integration test
├── workspace-home.nix       # Workspace Home and built-in user services test
└── README.md            # This file
```

## Writing New Tests

When writing new NixOS tests:

1. **Don't set `nixpkgs.config` in test nodes** - The test framework injects its own `pkgs` and will reject `nixpkgs.config` settings. Use `pkgsUnfree` in `flake.nix` if you need unfree packages.

2. **Escape `''` in test scripts** - The Nix indented string syntax uses `''`. To include literal `''` in Python test scripts (e.g., for empty SSH passphrases), escape it as `''''`.

3. **Escape `${` in test scripts** - Nix interprets `${` as antiquotation. Escape it as `''${` inside indented strings.

4. **Use `bloomModulesNoShell` when defining your own user** - The `workspace-shell.nix` module defines the primary Workspace user from `workspace.username`, so tests that define their own should use `bloomModulesNoShell` instead of `bloomModules`.

Example:
```nix
{ pkgs, lib, bloomModulesNoShell, piAgent, appPackage, mkTestFilesystems, ... }:

pkgs.testers.runNixOSTest {
  name = "my-test";
  
  nodes.server = { ... }: {
    imports = bloomModulesNoShell ++ [ mkTestFilesystems ];
    _module.args = { inherit piAgent appPackage; };
    
    workspace.username = "workspace";
    users.users.workspace = { ... };
  };
  
  testScript = ''
    server.start()
    server.wait_for_unit("multi-user.target")
    
    # Escape '' in shell commands
    server.succeed("ssh-keygen -N '''' -f /root/.ssh/id_rsa")
    
    # Use string concatenation instead of f-strings with ${}
    msg = "Hello " + name
  '';
}
```

## CI Integration

The NixOS tests run in CI via `.github/workflows/nixos-tests.yml`:

- **Fast checks** (`config`) run on every PR
- **VM tests** require KVM and run on self-hosted runners or can be triggered manually
- Tests are skipped if KVM is not available

To enable full VM tests in CI:
1. Set up a self-hosted runner with KVM support
2. Set the `NIXOS_TEST_RUNNER` repository variable to the runner label
3. Optionally configure Cachix for faster builds

## Debugging Failed Tests

When a test fails, you can:

1. **Check the test log**: The `-L` flag shows full test output
   ```bash
   nix build .#checks.x86_64-linux.workspace-matrix -L
   ```

2. **Run interactively**: Use the interactive driver to debug
   ```bash
   $(nix-build -A checks.x86_64-linux.workspace-matrix.driverInteractive)/bin/nixos-test-driver
   >>> server.start()
   >>> server.execute("systemctl status workspace-matrix")
   >>> server.shell_interact()  # Get a shell
   ```

3. **Check VM logs**: Tests capture systemd journal output which is printed on failure

## References

- [NixOS Test Driver Documentation](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)
- [NixOS Testing Infrastructure](https://nixos.wiki/wiki/NixOS_Testing_infrastructure)
- [Integration testing with NixOS virtual machines](https://nix.dev/tutorials/integration-testing-using-virtual-machines.html)
