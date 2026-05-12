# Fresh IDE on Nazar

`nazar` has the Fresh terminal IDE installed for codebase navigation from the canonical NetBird shell. Fresh runs inside a terminal session; it is not a web IDE.

## Access

```bash
netbird ssh root@nazar
ide
```

`ide` should point at the Nazar repo session:

```bash
cd /root/nazar
fresh -a nazar "$@"
```

This attaches to a named Fresh session for the repository and works from either the default plain shell or a manually attached Zellij workspace.

## Installed packages

Installed in the root Nix profile:

```text
fresh-editor
nil                         # Nix LSP
typescript-language-server
typescript
bash-language-server
yaml-language-server
vscode-langservers-extracted
marksman                    # Markdown LSP
ripgrep
fd
```

Fresh itself opens no network daemon or public port. It runs inside the existing terminal session, whether that is a plain SSH shell, a manually attached Zellij workspace, or the private Zellij web terminal at `https://nazar.studio/zellij/`.

## Useful commands

```bash
ide                         # open/attach Nazar repo session
ide README.md               # open file in the repo session
fresh --cmd session list    # list Fresh sessions
fresh --version
```

## Files on nazar

```text
/usr/local/bin/nazar-ide
/root/.bash_aliases
/root/.nix-profile/bin/fresh
```

## Notes

This is intentionally a terminal IDE instead of a web IDE on the Proxmox host. The only browser terminal exposure is the separate NetBird-private Zellij web endpoint documented in `runbooks/NAZAR_PRIVATE_DASHBOARD.md`.
