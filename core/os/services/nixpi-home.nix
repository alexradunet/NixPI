{ pkgs }:

{ config, lib, options, ... }:

let
  inherit (lib) mkOption types;
  webroot = builtins.dirOf config.configData."webroot/index.html".path;
in
{
  _class = "service";

  options.nixpi-home = {
    port = mkOption {
      type = types.port;
    };

    bindAddress = mkOption {
      type = types.str;
    };

    primaryUser = mkOption {
      type = types.str;
    };

    elementWebPort = mkOption {
      type = types.port;
    };

    matrixPort = mkOption {
      type = types.port;
    };

    matrixClientBaseUrl = mkOption {
      type = types.str;
    };

    trustedInterface = mkOption {
      type = types.str;
    };
  };

  config = {
    process.argv = [
      "${pkgs.static-web-server}/bin/static-web-server"
      "--host"
      config.nixpi-home.bindAddress
      "--port"
      (toString config.nixpi-home.port)
      "--root"
      webroot
      "--health"
    ];

    configData = {
      "webroot/index.html".text = ''
        <!doctype html>
        <html lang="en">
        <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>NixPI Home</title></head>
        <body>
          <h1>NixPI Home</h1>
          <p>Primary interfaces: terminal, Matrix, and Element Web.</p>
          <h2>Local access</h2>
          <ul>
            <li>Home: <a href="http://localhost:${toString config.nixpi-home.port}">http://localhost:${toString config.nixpi-home.port}</a></li>
            <li>Element Web: <a href="http://localhost:${toString config.nixpi-home.elementWebPort}">http://localhost:${toString config.nixpi-home.elementWebPort}</a></li>
            <li>Matrix: <a href="http://localhost:${toString config.nixpi-home.matrixPort}">http://localhost:${toString config.nixpi-home.matrixPort}</a></li>
          </ul>
          <h2>Remote access</h2>
          <p>Use your NetBird hostname or mesh IP on interface ${config.nixpi-home.trustedInterface}. Home stays on bare HTTP. Element Web and Matrix use the secure HTTPS entry point on port 8443 for browser-safe remote access.</p>
          <ul>
            <li>Home: <a data-page-link href="http://localhost/">http://localhost/</a></li>
            <li>Home direct port: <a data-home-direct-link href="http://localhost:${toString config.nixpi-home.port}/">http://localhost:${toString config.nixpi-home.port}/</a></li>
            <li>Element Web: <a data-element-link href="http://localhost:${toString config.nixpi-home.elementWebPort}/">http://localhost:${toString config.nixpi-home.elementWebPort}/</a></li>
            <li>Matrix URL: <a data-matrix-link href="${config.nixpi-home.matrixClientBaseUrl}">${config.nixpi-home.matrixClientBaseUrl}</a></li>
          </ul>
          <script>
            (function () {
              const currentHost = window.location.hostname;
              if (!currentHost) return;
              const pageUrl = window.location.origin.replace(/\/$/, "") + "/";
              const homeDirectUrl = "http://" + currentHost + ":${toString config.nixpi-home.port}/";
              const elementUrl = "https://" + currentHost + ":8443/";
              const matrixUrl = "https://" + currentHost + ":8443";
              for (const node of document.querySelectorAll("[data-page-link]")) {
                node.textContent = pageUrl;
                node.href = pageUrl;
              }
              for (const node of document.querySelectorAll("[data-home-direct-link]")) {
                node.textContent = homeDirectUrl;
                node.href = homeDirectUrl;
              }
              for (const node of document.querySelectorAll("[data-element-link]")) {
                node.textContent = elementUrl;
                node.href = elementUrl;
              }
              for (const node of document.querySelectorAll("[data-matrix-link]")) {
                node.textContent = matrixUrl;
                node.href = matrixUrl;
              }
            })();
          </script>
        </body>
        </html>
      '';
    };

    # `system.services` portability: guard systemd-specific config so this module
    # can be consumed by non-systemd init systems if NixOS ever supports them.
    # See nixpkgs nixos/README-modular-services.md.
  } // lib.optionalAttrs (options ? systemd) {
    systemd.service = {
      description = "NixPI Home landing page";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = config.nixpi-home.primaryUser;
        Group = config.nixpi-home.primaryUser;
        UMask = "0007";
        Restart = "on-failure";
        RestartSec = "10";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = false;
      };
    };
  };
}
