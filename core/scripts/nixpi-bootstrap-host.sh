#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF_USAGE'
Usage: nixpi-bootstrap-host --primary-user USER [--hostname HOSTNAME] [--timezone TZ] [--keyboard LAYOUT] [--nixpi-input FLAKE_REF] [--force]

Bootstrap NixPI onto an already-installed NixOS host by writing narrow /etc/nixos helper files.
If /etc/nixos/flake.nix does not exist, a minimal host flake is generated automatically.
If /etc/nixos/flake.nix already exists, helper files are written and exact manual integration instructions are printed.
EOF_USAGE
}

log() {
	printf '%s\n' "$*" >&2
}

escape_nix_string() {
	local value="${1-}"

	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//$'\n'/\\n}"
	value="${value//$'\r'/\\r}"
	value="${value//\$\{/\\\$\{}"

	printf '%s' "$value"
}

write_host_module() {
	local output_path="$1"
	local hostname_escaped=""
	local primary_user_escaped=""
	local timezone_escaped=""
	local keyboard_escaped=""

	hostname_escaped="$(escape_nix_string "$hostname")"
	primary_user_escaped="$(escape_nix_string "$primary_user")"
	timezone_escaped="$(escape_nix_string "$timezone")"
	keyboard_escaped="$(escape_nix_string "$keyboard")"

	cat >"$output_path" <<EOF_HOST
{ ... }:
{
  networking.hostName = "${hostname_escaped}";
  nixpi.primaryUser = "${primary_user_escaped}";
  nixpi.timezone = "${timezone_escaped}";
  nixpi.keyboard = "${keyboard_escaped}";
}
EOF_HOST
}

write_integration_module() {
	local output_path="$1"

	cat >"$output_path" <<'EOF_INTEGRATION'
{ nixpi, ... }:
{
  imports = [
    nixpi.nixosModules.nixpi
    ./nixpi-host.nix
  ];
}
EOF_INTEGRATION
}

require_writable_helper_path() {
	local output_path="$1"

	if [[ "$force_overwrite" == "true" || ! -e "$output_path" ]]; then
		return 0
	fi

	log "Refusing to overwrite existing ${output_path}."
	log "Review the file and rerun with --force if you want nixpi-bootstrap-host to replace it."
	return 1
}

write_generated_flake() {
	local output_path="$1"
	local nixpi_input_escaped=""
	local hardware_configuration_line=""

	nixpi_input_escaped="$(escape_nix_string "$nixpi_input")"

	if [[ -f "${etc_nixos_dir}/hardware-configuration.nix" ]]; then
		hardware_configuration_line='        ./hardware-configuration.nix'
	fi

	cat >"$output_path" <<EOF_FLAKE
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.nixpi.url = "${nixpi_input_escaped}";
  inputs.nixpi.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, nixpi, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = builtins.currentSystem;
      specialArgs = { inherit nixpi; };
      modules = [
        ./configuration.nix
        ./nixpi-integration.nix
${hardware_configuration_line}
      ];
    };
  };
}
EOF_FLAKE
}

print_manual_integration_instructions() {
	local nixpi_input_escaped=""

	nixpi_input_escaped="$(escape_nix_string "$nixpi_input")"

	cat <<EOF_MANUAL
Manual integration required: /etc/nixos/flake.nix already exists.

1. Add the NixPI input:
   inputs.nixpi.url = "${nixpi_input_escaped}";
   inputs.nixpi.inputs.nixpkgs.follows = "nixpkgs";

2. Ensure your nixosSystem passes the NixPI input:
   specialArgs = { inherit nixpi; };

3. Add the generated helper module to your host's modules list:
   ./nixpi-integration.nix

4. Rebuild manually:
   sudo nixos-rebuild switch --flake /etc/nixos#nixos --impure
EOF_MANUAL
}

main() {
	etc_nixos_dir="${NIXPI_BOOTSTRAP_ROOT:-/etc/nixos}"
	nixos_rebuild_bin="${NIXPI_NIXOS_REBUILD:-nixos-rebuild}"
	primary_user=""
	hostname="nixos"
	timezone="UTC"
	keyboard="us"
	nixpi_input="${NIXPI_DEFAULT_INPUT:-github:alexradunet/nixpi}"
	force_overwrite="false"

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--primary-user)
				primary_user="${2:?missing primary user}"
				shift 2
				;;
			--hostname)
				hostname="${2:?missing hostname}"
				shift 2
				;;
			--timezone)
				timezone="${2:?missing timezone}"
				shift 2
				;;
			--keyboard)
				keyboard="${2:?missing keyboard layout}"
				shift 2
				;;
			--nixpi-input)
				nixpi_input="${2:?missing nixpi input}"
				shift 2
				;;
			--force)
				force_overwrite="true"
				shift
				;;
			--help|-h)
				usage
				exit 0
				;;
			*)
				usage >&2
				exit 1
				;;
		esac
	done

	if [[ -z "$primary_user" ]]; then
		usage >&2
		exit 1
	fi

	if [[ "$etc_nixos_dir" != "/etc/nixos" && "$nixos_rebuild_bin" == "nixos-rebuild" ]]; then
		log "NIXPI_BOOTSTRAP_ROOT is for tests/staging only when it differs from /etc/nixos."
		log "Refusing to use NIXPI_BOOTSTRAP_ROOT=${etc_nixos_dir} with the default nixos-rebuild because rebuild/manual instructions target /etc/nixos#nixos."
		log "Unset NIXPI_BOOTSTRAP_ROOT for a real host bootstrap, or set NIXPI_NIXOS_REBUILD to a staging/test stub."
		exit 1
	fi

	mkdir -p "$etc_nixos_dir"

	require_writable_helper_path "${etc_nixos_dir}/nixpi-host.nix"
	require_writable_helper_path "${etc_nixos_dir}/nixpi-integration.nix"

	write_host_module "${etc_nixos_dir}/nixpi-host.nix"
	write_integration_module "${etc_nixos_dir}/nixpi-integration.nix"

	if [[ -f "${etc_nixos_dir}/flake.nix" ]]; then
		print_manual_integration_instructions
		return 0
	fi

	write_generated_flake "${etc_nixos_dir}/flake.nix"
	exec "$nixos_rebuild_bin" switch --flake /etc/nixos#nixos --impure
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
