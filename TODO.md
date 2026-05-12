# TODO

Open operational work only. Completed history belongs in `CHANGELOG.md`, `security/HARDENING_APPLIED.md`, and the focused runbooks.

## P0 / next maintenance window

- Rotate the Hetzner DNS API token used by the Proxmox ACME plugin and update the plugin config without exposing the token in git, shell history, logs, or chats.
- Manually download the current important backup archives from `/var/lib/vz/dump/` to the desktop PC.
- Add/prove backup jobs for VM 120/121 before putting irreplaceable OwnLoom/wiki/DAV data there; treat VM 121 as personal-data critical.
- Perform and document a restore test to a disposable VM ID such as `900`.

## P1 / hardening

- Implement restricted VM-side `nazar-deploy-self` triggers that can only update/deploy the calling VM through Nazar; do not grant broad fleet deploy authority to VMs.
- Add laptop/mobile to the NetBird `admins` group and verify access.
- Disable or narrow broad NetBird default policies after least-privilege policies are verified on all required admin devices.
- Replace the temporary Forgejo bootstrap secret flow with committed `sops-nix` encrypted secret wiring.
- Periodically rerun the Hetzner Rescue exercise.

## P2 / later, only if needed

- Implement automated encrypted off-host backups if manual downloads are no longer enough.
- Create a reusable NixOS VM template if repeated VM creation becomes painful.
- Reconsider an additional private Git mirror only if off-host Git redundancy is needed.
