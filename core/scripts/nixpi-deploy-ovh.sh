#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF_USAGE'
Usage: nixpi-deploy-ovh --target-host root@IP --disk /dev/sdX [--flake .#ovh-vps] [--hostname HOSTNAME] [--bootstrap-user USER --bootstrap-password-hash HASH] [--netbird-setup-key-file PATH] [extra nixos-anywhere args...]

Destructive fresh install for an OVH VPS in rescue mode.

Examples:
  nix run .#nixpi-deploy-ovh -- --target-host root@198.51.100.10 --disk /dev/sda
  nix run .#nixpi-deploy-ovh -- --target-host root@198.51.100.10 --disk /dev/nvme0n1 --hostname bloom-eu-1
  nix run .#nixpi-deploy-ovh -- --target-host root@198.51.100.10 --disk /dev/sda --bootstrap-user human --bootstrap-password-hash '$6$...'
  nix run .#nixpi-deploy-ovh -- --target-host root@198.51.100.10 --disk /dev/sda --netbird-setup-key-file ./netbird-key
EOF_USAGE
}

log() {
  printf '[nixpi-deploy-ovh] %s\n' "$*" >&2
}

resolve_repo_url() {
  local ref="$1"
  if [[ "$ref" == path:* || "$ref" == github:* || "$ref" == git+* || "$ref" == https://* || "$ref" == ssh://* ]]; then
    printf '%s\n' "$ref"
    return 0
  fi

  if [[ "$ref" == . || "$ref" == /* ]]; then
    printf 'path:%s\n' "$(realpath "$ref")"
    return 0
  fi

  printf '%s\n' "$ref"
}

escape_nix_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

build_bootstrap_module() {
  local bootstrap_user="$1"
  local bootstrap_password_hash="$2"
  local netbird_setup_key_target_path="$3"
  local nix_bootstrap_user=""
  local nix_bootstrap_password_hash=""

  if [[ -n "$bootstrap_user" ]]; then
    nix_bootstrap_user="$(escape_nix_string "$bootstrap_user")"
    nix_bootstrap_password_hash="$(escape_nix_string "$bootstrap_password_hash")"
    cat <<EOF_BOOTSTRAP
        ({ lib, ... }: {
          nixpi.primaryUser = lib.mkForce "${nix_bootstrap_user}";
          nixpi.security.ssh.passwordAuthentication = lib.mkForce true;
          nixpi.security.ssh.allowUsers = lib.mkForce [ "${nix_bootstrap_user}" ];
          users.users."${nix_bootstrap_user}".initialHashedPassword = lib.mkForce "${nix_bootstrap_password_hash}";
        })
EOF_BOOTSTRAP
  fi

  if [[ -n "$netbird_setup_key_target_path" ]]; then
    cat <<EOF_NETBIRD
        ({ lib, ... }: {
          nixpi.netbird.enable = lib.mkForce true;
          nixpi.netbird.setupKeyFile = lib.mkForce "${netbird_setup_key_target_path}";
        })
EOF_NETBIRD
  fi
}

build_deploy_flake() {
  local repo_url="$1"
  local base_attr="$2"
  local hostname="$3"
  local disk="$4"
  local bootstrap_user="${5:-}"
  local bootstrap_password_hash="${6:-}"
  local netbird_setup_key_target_path="${7:-}"
  local nix_hostname=""
  local nix_disk=""
  local bootstrap_module=""

  nix_hostname="$(escape_nix_string "$hostname")"
  nix_disk="$(escape_nix_string "$disk")"
  bootstrap_module="$(build_bootstrap_module "$bootstrap_user" "$bootstrap_password_hash" "$netbird_setup_key_target_path")"

  cat <<EOF_FLAKE
{
  inputs.nixpi.url = "${repo_url}";

  outputs = { nixpi, ... }: {
    nixosConfigurations.deploy = nixpi.nixosConfigurations.${base_attr}.extendModules {
      modules = [
        ({ lib, ... }: {
          networking.hostName = lib.mkForce "${nix_hostname}";
          disko.devices.disk.main.device = lib.mkForce "${nix_disk}";
        })
${bootstrap_module}
      ];
    };
  };
}
EOF_FLAKE
}

main() {
  local target_host=""
  local disk=""
  local hostname="ovh-vps"
  local flake_ref="${NIXPI_REPO_ROOT:-.}#ovh-vps"
  local bootstrap_user=""
  local bootstrap_password_hash=""
  local netbird_setup_key_file=""
  local netbird_setup_key_target_path="/var/lib/nixpi/bootstrap/netbird-setup-key"
  local extra_args=()
  local repo_ref=""
  local base_attr=""
  local repo_url=""
  local tmp_dir=""
  local nixos_anywhere_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target-host)
        target_host="${2:?missing target host}"
        shift 2
        ;;
      --disk)
        disk="${2:?missing disk path}"
        shift 2
        ;;
      --flake)
        flake_ref="${2:?missing flake ref}"
        shift 2
        ;;
      --hostname)
        hostname="${2:?missing hostname}"
        shift 2
        ;;
      --bootstrap-user)
        bootstrap_user="${2:?missing bootstrap user}"
        shift 2
        ;;
      --bootstrap-password-hash)
        bootstrap_password_hash="${2:?missing bootstrap password hash}"
        shift 2
        ;;
      --netbird-setup-key-file)
        netbird_setup_key_file="${2:?missing netbird setup key file}"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z "$target_host" || -z "$disk" ]]; then
    usage >&2
    exit 1
  fi

  if [[ "$flake_ref" != *#* ]]; then
    log "Flake ref must include a nixosConfigurations attribute, for example .#ovh-vps"
    exit 1
  fi

  if [[ -n "$bootstrap_user" && -z "$bootstrap_password_hash" ]]; then
    log "--bootstrap-user requires --bootstrap-password-hash"
    exit 1
  fi

  if [[ -z "$bootstrap_user" && -n "$bootstrap_password_hash" ]]; then
    log "--bootstrap-password-hash requires --bootstrap-user"
    exit 1
  fi

  if [[ -n "$netbird_setup_key_file" && ! -f "$netbird_setup_key_file" ]]; then
    log "--netbird-setup-key-file must point to an existing local file"
    exit 1
  fi

  repo_ref="${flake_ref%%#*}"
  base_attr="${flake_ref#*#}"
  repo_url="$(resolve_repo_url "$repo_ref")"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  build_deploy_flake "$repo_url" "$base_attr" "$hostname" "$disk" "$bootstrap_user" "$bootstrap_password_hash" "$netbird_setup_key_target_path" > "$tmp_dir/flake.nix"

  if [[ -n "$netbird_setup_key_file" ]]; then
    install -d -m 0700 "$tmp_dir/var/lib/nixpi/bootstrap"
    install -m 0600 "$netbird_setup_key_file" "$tmp_dir${netbird_setup_key_target_path}"
  fi

  log "WARNING: destructive install to ${target_host} using disk ${disk}"
  log "Using base configuration ${flake_ref} with target hostname ${hostname}"
  log "nixos-anywhere will install the final host configuration directly"
  log "Any /srv/nixpi checkout after install is optional operator convenience"
  if [[ -n "$bootstrap_user" ]]; then
    log "Bootstrap login will be ${bootstrap_user} using initialHashedPassword"
  fi
  if [[ -n "$netbird_setup_key_file" ]]; then
    log "Bootstrap will copy a NetBird setup key file for first-boot enrollment"
  fi
  nixos_anywhere_args=(
    --flake "$tmp_dir#deploy"
    --target-host "$target_host"
  )

  if [[ -n "$netbird_setup_key_file" ]]; then
    nixos_anywhere_args+=(--extra-files "$tmp_dir")
  fi

  nixos_anywhere_args+=("${extra_args[@]}")

  exec "${NIXPI_NIXOS_ANYWHERE:-nixos-anywhere}" "${nixos_anywhere_args[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
