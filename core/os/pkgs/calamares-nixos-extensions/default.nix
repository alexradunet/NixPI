{
  stdenv,
  lib,
  glibcLocales,
  python3,
  pkgs,
  nixpiSource,
}:

let
  nixpiCalamaresHelpers = builtins.readFile ./nixpi_calamares.py;
in
stdenv.mkDerivation {
  pname = "calamares-nixos-extensions";
  version = "0.3.23-nixpi";

  src = "${pkgs.path}/pkgs/by-name/ca/calamares-nixos-extensions/src";
  nativeBuildInputs = [ python3 ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    cp -r "$src" source
    chmod -R u+w source

    python <<'PY'
from pathlib import Path

path = Path("source/modules/nixos/main.py")
text = path.read_text()
helper_code = ${builtins.toJSON nixpiCalamaresHelpers}

old_header = """{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

"""
new_header = """{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nixpi-install.nix
    ];

"""
text = text.replace(old_header, new_header, 1)

marker = 'def env_is_set(name):\n'
text = text.replace(marker, helper_code + "\n\n" + marker, 1)

old_write = """    # Write the configuration.nix file
    libcalamares.utils.host_env_process_output(["cp", "/dev/stdin", config], None, cfg)
"""
new_write = """    # Materialize the NixPI installation helpers and the standard /etc/nixos flake.
    write_nixpi_install_artifacts(
        root_mount_point,
        variables,
        cfg,
        libcalamares.utils.host_env_process_output,
    )

    # Write the configuration.nix file used by nixos-install itself.
    libcalamares.utils.host_env_process_output(["cp", "/dev/stdin", config], None, cfg)
"""
text = text.replace(old_write, new_write, 1)

path.write_text(text)
PY

    mkdir -p "$out"/{etc,lib,share}/calamares
    cp -r source/modules "$out/lib/calamares/"
    cp -r source/config/* "$out/etc/calamares/"
    cp -r source/branding "$out/share/calamares/"

    substituteInPlace "$out/etc/calamares/settings.conf" --replace-fail @out@ "$out"
    substituteInPlace "$out/etc/calamares/modules/locale.conf" --replace-fail @glibcLocales@ "${glibcLocales}"
    substituteInPlace "$out/lib/calamares/modules/nixos/main.py" --replace-fail "@nixpiSource@" "${nixpiSource}"
    PYTHONPYCACHEPREFIX="$(mktemp -d)" python3 -m py_compile "$out/lib/calamares/modules/nixos/main.py"

    runHook postInstall
  '';

  meta = {
    description = "Calamares modules for NixPI installs on NixOS";
    homepage = "https://github.com/alexradunet/NixPI";
    license = with lib.licenses; [ mit cc-by-40 cc-by-sa-40 ];
    platforms = lib.platforms.linux;
  };
}
