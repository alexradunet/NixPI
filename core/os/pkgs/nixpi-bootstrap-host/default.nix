{
  pkgs,
  lib,
  makeWrapper,
  nixpiDefaultInput ? "github:alexradunet/nixpi",
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "nixpi-bootstrap-host";
  version = "0.1.0";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/nixpi-bootstrap-host"
    install -m 0755 ${../../../scripts/nixpi-bootstrap-host.sh} "$out/share/nixpi-bootstrap-host/nixpi-bootstrap-host.sh"

    makeWrapper ${pkgs.bash}/bin/bash "$out/bin/nixpi-bootstrap-host" \
      --set NIXPI_DEFAULT_INPUT "${nixpiDefaultInput}" \
      --prefix PATH : "${lib.makeBinPath [ pkgs.coreutils pkgs.nix ]}" \
      --add-flags "$out/share/nixpi-bootstrap-host/nixpi-bootstrap-host.sh"

    runHook postInstall
  '';

  meta.mainProgram = "nixpi-bootstrap-host";
}
