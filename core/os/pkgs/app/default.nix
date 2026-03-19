# core/os/pkgs/app/default.nix
{ lib, buildNpmPackage, nodejs, piAgent }:

buildNpmPackage {
  pname = "app";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ../../../..;
    filter = path: _type:
      let
        rel = lib.removePrefix (toString ../../../..) (toString path);
      in
        !(lib.hasPrefix "/node_modules" rel
          || lib.hasPrefix "/dist" rel
          || lib.hasPrefix "/coverage" rel
          || lib.hasPrefix "/core/os" rel
          || lib.hasPrefix "/.git" rel
          || lib.hasSuffix ".qcow2" rel
          || lib.hasSuffix ".iso" rel);
  };

  npmDepsHash = "sha256-aTXzcbwrLPMeIxDReEHzRloze2iEfNWNia8QKtTUXz8=";

  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/workspace/core/pi
    cp -r dist package.json node_modules $out/share/workspace/
    cp -r core/pi/persona $out/share/workspace/core/pi/persona
    cp -r core/pi/skills  $out/share/workspace/core/pi/skills

    mkdir -p $out/bin
    install -m 755 ${../../../scripts/setup-lib.sh} $out/bin/setup-lib.sh
    install -m 755 ${../../../scripts/setup-wizard.sh} $out/bin/setup-wizard.sh
    install -m 755 ${../../../scripts/login-greeting.sh} $out/bin/login-greeting.sh

    # Replace @mariozechner/pi-coding-agent with symlinks into piAgent store path.
    # Do NOT remove other @mariozechner packages (e.g. jiti) — only replace pi-coding-agent.
    rm -rf $out/share/workspace/node_modules/@mariozechner/pi-coding-agent
    ln -sf ${piAgent}/lib/node_modules/@mariozechner/pi-coding-agent \
      $out/share/workspace/node_modules/@mariozechner/pi-coding-agent

    # pi-ai lives nested under pi-coding-agent in the piAgent output.
    # If it also exists at top-level @mariozechner, replace it; otherwise skip.
    if [ -d "$out/share/workspace/node_modules/@mariozechner/pi-ai" ]; then
      rm -rf $out/share/workspace/node_modules/@mariozechner/pi-ai
    fi
    ln -sf ${piAgent}/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-ai \
      $out/share/workspace/node_modules/@mariozechner/pi-ai || true

    mkdir -p $out/share/workspace/.pi/agent
    echo '{"packages": ["/usr/local/share/workspace"]}' > $out/share/workspace/.pi/agent/settings.json

    # extensions symlink — package.json references ./core/pi/extensions but compiled JS lands in dist/
    ln -sf $out/share/workspace/dist/core/pi/extensions $out/share/workspace/core/pi/extensions

    # persona and skills symlinks — use absolute paths so they resolve correctly at runtime
    ln -sf $out/share/workspace/core/pi/persona $out/share/workspace/persona
    ln -sf $out/share/workspace/core/pi/skills  $out/share/workspace/skills

    runHook postInstall
  '';

  meta = {
    description = "Workspace AI companion OS TypeScript application";
    license = lib.licenses.mit;
  };
}
