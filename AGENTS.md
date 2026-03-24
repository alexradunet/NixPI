# AGENTS.md

Repository rules for coding agents working in this repo.

## Canonical repository

The canonical source-of-truth repository on this machine is:

`/home/alex/nixpi`

## Required workflow

When making changes for this repo, always:

- Edit files in `/home/alex/nixpi`
- Run `git` commands in `/home/alex/nixpi`
- Rebuild from `/home/alex/nixpi`
- Commit and push from `/home/alex/nixpi`

Preferred rebuild command:

`sudo nixos-rebuild switch --flake /home/alex/nixpi#nixpi`

## Do not default to proposal/apply clones

Do not treat any proposal, state, cache, or apply clone as the source-of-truth repo unless the user explicitly asks.

In particular, do not default to:

- `/var/lib/nixpi/pi-nixpi`
- `~/.nixpi/pi-nixpi`

Those paths may exist for local apply/proposal workflows, but they are not the canonical upstream-working repository for this machine.

## If there is ambiguity

If a task could be performed in multiple repo copies, prefer `/home/alex/nixpi` and ask the user before using another path.
