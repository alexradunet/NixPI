{
  # sops-nix is imported by the flake. Individual hosts/services should add
  # concrete sops.secrets entries once an age recipient and encrypted files exist.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
}
