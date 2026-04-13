{ lib, buildNpmPackage, nodejs, makeWrapper }:

buildNpmPackage {
  pname = "nixpi-pi-core";
  version = "0.1.0";

  src = ../../../../Agents/pi-core;

  npmDepsHash = "sha256-r52OeTdler05TjEX5U0/Lrm6wIb9nTtLiJnNBouopo8=";

  nativeBuildInputs = [ makeWrapper ];

  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/nixpi-pi-core $out/bin
    cp -r dist node_modules package.json $out/share/nixpi-pi-core/

    makeWrapper ${nodejs}/bin/node $out/bin/nixpi-pi-core \
      --add-flags "$out/share/nixpi-pi-core/dist/main.js"

    runHook postInstall
  '';

  meta = {
    description = "NixPI Pi core local API service";
    license = lib.licenses.mit;
    mainProgram = "nixpi-pi-core";
  };
}
