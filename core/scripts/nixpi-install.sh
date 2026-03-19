#!/usr/bin/env bash
set -euo pipefail

flake="${1:-github:alexradunet/nixPI#desktop}"
primary_user="${NIXPI_PRIMARY_USER:-${SUDO_USER:-${USER:-}}}"

if [[ -z "${primary_user}" ]]; then
	echo "Unable to determine the primary user. Set NIXPI_PRIMARY_USER and retry." >&2
	exit 1
fi

export NIXPI_PRIMARY_USER="${primary_user}"

exec sudo --preserve-env=NIXPI_PRIMARY_USER \
	nixos-rebuild switch --impure --flake "${flake}"
