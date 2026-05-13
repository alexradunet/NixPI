# nixpi Changelog

All notable changes to this project will be documented here.

## [1.6.3] - 2026-05-13

### Added
- Support serving NixPi behind a `/nixpi/` reverse-proxy path, including relative bundled JS paths, WebSocket URL selection, and API requests.
- Document the preferred Nazar routing model: `/nixpi/` on existing private service domains, with dedicated `nixpi*.nazar.studio` names as optional direct routes.

## [1.6.2] - 2026-05-13

### Changed
- Rebranded the project from `wgnr-pi` to `nixpi` for Nazar/OwnLoom use.
- Renamed the CLI to `nixpi` and the macOS helper to `nixpi.sh`.
- Renamed configuration variables to `NIXPI_*`.
- Replaced public-facing UI and docs branding with NixPi/Nazar language.

### Added
- Nix flake package export for `nixpi`.
- Reusable NixOS service module at `nixosModules.nixpi`.

## Pre-NixPi upstream baseline

This repository started from the MIT-licensed `wgnr-pi` 1.6.1 codebase, which already provided the Pi RPC bridge, browser WebSocket streaming, session management, model picker, thinking controls, image support, slash commands, session export, and optional Whisper speech-to-text.
