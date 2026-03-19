# core/os/modules/network.nix
{ pkgs, lib, config, ... }:

let
  u = config.nixpi.username;
  cfg = config.nixpi.services;
  securityCfg = config.nixpi.security;
  mkService = import ../lib/mk-service.nix { inherit lib; };
  exposedPorts =
    lib.optionals cfg.home.enable [ cfg.home.port ]
    ++ lib.optionals cfg.chat.enable [ cfg.chat.port ]
    ++ lib.optionals cfg.files.enable [ cfg.files.port ]
    ++ lib.optionals cfg.code.enable [ cfg.code.port ]
    ++ [ config.nixpi.matrix.port ];

  nixpiHomeBootstrap = pkgs.writeShellScript "nixpi-home-bootstrap" ''
    set -eu
    mkdir -p "$HOME/.config/nixpi/home" "$HOME/.config/nixpi/home/tmp"
    if [ ! -f "$HOME/.config/nixpi/home/index.html" ]; then
      cat > "$HOME/.config/nixpi/home/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>nixPI Home</title></head>
<body>
  <h1>nixPI Home</h1>
  <ul>
    <li><a href="http://localhost:${toString cfg.chat.port}">nixPI Chat</a></li>
    <li><a href="http://localhost:${toString cfg.files.port}">nixPI Files</a></li>
    <li><a href="http://localhost:${toString cfg.code.port}">code-server</a></li>
  </ul>
</body>
</html>
HTML
    fi
    cat > "$HOME/.config/nixpi/home/nginx.conf" <<'NGINX'
daemon off;
pid /run/user/1000/nixpi-home-nginx.pid;
error_log stderr;
events { worker_connections 64; }
http {
    include ${pkgs.nginx}/conf/mime.types;
    default_type application/octet-stream;
    access_log off;
    client_body_temp_path /home/${u}/.config/nixpi/home/tmp;
    server {
        listen ${toString cfg.home.port};
        root /home/${u}/.config/nixpi/home;
        try_files $uri $uri/ =404;
    }
}
NGINX
  '';

  fluffychatBootstrap = pkgs.writeShellScript "nixpi-chat-bootstrap" ''
    set -eu
    mkdir -p "$HOME/.config/nixpi/chat" "$HOME/.config/nixpi/chat/tmp"
    cat > "$HOME/.config/nixpi/chat/config.json" <<'CONFIG'
{
  "applicationName": "nixPI Chat",
  "defaultHomeserver": "http://localhost:${toString config.nixpi.matrix.port}"
}
CONFIG
    cat > "$HOME/.config/nixpi/chat/nginx.conf" <<'NGINX'
daemon off;
pid /run/user/1000/nixpi-chat-nginx.pid;
error_log stderr;
events { worker_connections 64; }
http {
    include ${pkgs.nginx}/conf/mime.types;
    default_type application/octet-stream;
    access_log off;
    client_body_temp_path /home/${u}/.config/nixpi/chat/tmp;
    server {
        listen ${toString cfg.chat.port};
        location /config.json {
            alias /home/${u}/.config/nixpi/chat/config.json;
        }
        location / {
            root /etc/nixpi/fluffychat-web;
            try_files $uri $uri/ /index.html;
        }
    }
}
NGINX
  '';
in

{
  imports = [ ./options.nix ];

  config = {
    assertions = [
      {
        assertion = securityCfg.trustedInterface != "";
        message = "nixpi.security.trustedInterface must not be empty.";
      }
      {
        assertion = cfg.bindAddress != "";
        message = "nixpi.services.bindAddress must not be empty.";
      }
      {
        assertion = lib.length (lib.unique exposedPorts) == lib.length exposedPorts;
        message = "nixPI service ports must be unique across built-in services and Matrix.";
      }
    ];

    hardware.enableAllFirmware = true;
    services.netbird.enable = true;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        PubkeyAuthentication = "yes";
        PermitRootLogin = "no";
      };
    };

    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [ 22 ];
    networking.firewall.interfaces = lib.mkIf securityCfg.enforceServiceFirewall {
      "${securityCfg.trustedInterface}".allowedTCPPorts = exposedPorts;
    };
    networking.networkmanager.enable = true;

    environment.etc."nixpi/fluffychat-web".source = pkgs.fluffychat-web;

    environment.systemPackages = with pkgs; [
      git git-lfs gh
      ripgrep fd bat htop jq curl wget unzip openssl
      just shellcheck biome typescript
      qemu OVMF
      chromium
      netbird
      dufs nginx code-server
    ];

    systemd.user.services = lib.mkMerge [
      (lib.mkIf cfg.home.enable {
        nixpi-home = mkService {
          description = "nixPI Home landing page";
          wantedBy = [ "default.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          execStartPre = "${nixpiHomeBootstrap}";
          execStart = "${pkgs.nginx}/bin/nginx -c %h/.config/nixpi/home/nginx.conf";
          restart = "on-failure";
          restartSec = 10;
          readWritePaths = [ "%h/.config/nixpi/home" ];
        };
      })
      (lib.mkIf cfg.chat.enable {
        nixpi-chat = mkService {
          description = "nixPI web chat client";
          wantedBy = [ "default.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          execStartPre = "${fluffychatBootstrap}";
          execStart = "${pkgs.nginx}/bin/nginx -c %h/.config/nixpi/chat/nginx.conf";
          restart = "on-failure";
          restartSec = 10;
          readWritePaths = [ "%h/.config/nixpi/chat" ];
        };
      })
      (lib.mkIf cfg.files.enable {
        nixpi-files = mkService {
          description = "nixPI Files WebDAV";
          wantedBy = [ "default.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          execStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Public/nixPI";
          execStart = "${pkgs.dufs}/bin/dufs %h/Public/nixPI -A -b ${cfg.bindAddress} -p ${toString cfg.files.port}";
          restart = "on-failure";
          restartSec = 10;
          readWritePaths = [ "%h/Public/nixPI" ];
        };
      })
      (lib.mkIf cfg.code.enable {
        nixpi-code = mkService {
          description = "nixPI code-server";
          wantedBy = [ "default.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          execStart = "${pkgs.code-server}/bin/code-server --bind-addr ${cfg.bindAddress}:${toString cfg.code.port} --auth none --disable-telemetry";
          restart = "on-failure";
          restartSec = 10;
          hardening = false;
        };
      })
    ];

    systemd.tmpfiles.rules = [
      "d /home/${u}/.config 0755 ${u} ${u} -"
      "d /home/${u}/.config/systemd 0755 ${u} ${u} -"
      "d /home/${u}/.config/systemd/user 0755 ${u} ${u} -"
      "d /home/${u}/.config/nixpi 0755 ${u} ${u} -"
      "d /home/${u}/.config/nixpi/home 0755 ${u} ${u} -"
      "d /home/${u}/.config/nixpi/chat 0755 ${u} ${u} -"
      "d /home/${u}/.config/code-server 0755 ${u} ${u} -"
      "d /home/${u}/Public/nixPI 0755 ${u} ${u} -"
    ];

    system.activationScripts.nixpi-builtins = lib.stringAfter [ "users" ] ''
      install -d -m 0755 -o ${u} -g ${u} /home/${u}/.config
      install -d -m 0755 -o ${u} -g ${u} /home/${u}/.config/systemd
      install -d -m 0755 -o ${u} -g ${u} /home/${u}/.config/systemd/user
      install -d -m 0755 -o ${u} -g ${u} /home/${u}/.config/nixpi/home
      install -d -m 0755 -o ${u} -g ${u} /home/${u}/.config/nixpi/home/tmp
      install -d -m 0755 -o ${u} -g ${u} /home/${u}/.config/nixpi/chat
      install -d -m 0755 -o ${u} -g ${u} /home/${u}/.config/nixpi/chat/tmp
      install -d -m 0755 -o ${u} -g ${u} /home/${u}/.config/code-server
      install -d -m 0755 -o ${u} -g ${u} /home/${u}/Public/nixPI

      cat > /home/${u}/.config/nixpi/home/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>nixPI Home</title></head>
<body>
  <h1>nixPI Home</h1>
  <ul>
    <li><a href="http://localhost:${toString cfg.chat.port}">nixPI Chat</a></li>
    <li><a href="http://localhost:${toString cfg.files.port}">nixPI Files</a></li>
    <li><a href="http://localhost:${toString cfg.code.port}">nixPI Code</a></li>
  </ul>
</body>
</html>
HTML

      cat > /home/${u}/.config/nixpi/home/nginx.conf <<'NGINX'
daemon off;
pid /run/user/1000/nixpi-home-nginx.pid;
error_log stderr;
events { worker_connections 64; }
http {
    include ${pkgs.nginx}/conf/mime.types;
    default_type application/octet-stream;
    access_log off;
    client_body_temp_path /home/${u}/.config/nixpi/home/tmp;
    server {
        listen ${toString cfg.home.port};
        root /home/${u}/.config/nixpi/home;
        try_files $uri $uri/ =404;
    }
}
NGINX

      cat > /home/${u}/.config/nixpi/chat/config.json <<'CONFIG'
{
  "applicationName": "nixPI Chat",
  "defaultHomeserver": "http://localhost:${toString config.nixpi.matrix.port}"
}
CONFIG

      cat > /home/${u}/.config/nixpi/chat/nginx.conf <<'NGINX'
daemon off;
pid /run/user/1000/nixpi-chat-nginx.pid;
error_log stderr;
events { worker_connections 64; }
http {
    include ${pkgs.nginx}/conf/mime.types;
    default_type application/octet-stream;
    access_log off;
    client_body_temp_path /home/${u}/.config/nixpi/chat/tmp;
    server {
        listen ${toString cfg.chat.port};
        location /config.json {
            alias /home/${u}/.config/nixpi/chat/config.json;
        }
        location / {
            root /etc/nixpi/fluffychat-web;
            try_files $uri $uri/ /index.html;
        }
    }
}
NGINX

      chown -R ${u}:${u} /home/${u}/.config /home/${u}/Public/nixPI
    '';

    warnings = lib.optional securityCfg.enforceServiceFirewall ''
      nixPI opens Home, Chat, Files, Code, and Matrix only on
      `${securityCfg.trustedInterface}`. Without that interface, only local
      access remains available.
    '';
  };
}
