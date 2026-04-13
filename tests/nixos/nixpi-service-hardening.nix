{ mkTestFilesystems, ... }:

{
  name = "nixpi-service-hardening";

  nodes.nixpi =
    { pkgs, lib, ... }:
    let
      fakeSignalDaemon = pkgs.writeShellScript "fake-nixpi-signal-daemon" ''
                exec ${pkgs.python3}/bin/python3 - <<'PY'
        import time
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/api/v1/check":
                    body = b'{"ok":true}'
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                    return
                if self.path == "/api/v1/events":
                    self.send_response(200)
                    self.send_header("Content-Type", "text/event-stream")
                    self.send_header("Cache-Control", "no-cache")
                    self.end_headers()
                    self.wfile.write(b"retry: 10000\\n\\n")
                    self.wfile.flush()
                    while True:
                        time.sleep(60)
                self.send_response(404)
                self.end_headers()

            def log_message(self, format, *args):
                return

        ThreadingHTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
        PY
      '';
    in
    {
      imports = [
        ../../core/os/hosts/vps.nix
        mkTestFilesystems
      ];

      networking.hostName = "nixpi-service-hardening-test";
      nixpi = {
        primaryUser = "pi";
        bootstrap.enable = false;
        bootstrap.ssh.enable = false;
        piCore.enable = true;
        gateway = {
          enable = true;
          modules.signal = {
            enable = true;
            account = "+15550001111";
            allowedNumbers = [ "+15550002222" ];
            adminNumbers = [ "+15550002222" ];
          };
        };
      };

      systemd.services.nixpi-signal-daemon.serviceConfig.ExecStart = lib.mkForce fakeSignalDaemon;
    };

  testScript = ''
    import shlex

    nixpi = machines[0]

    def assert_unit_property(unit, prop, expected):
        nixpi.succeed(
            f"systemctl show {unit} -p {prop} --value | grep -qx {shlex.quote(expected)}"
        )

    def assert_readwrite_path(unit, expected_path):
        nixpi.succeed(
            f"systemctl show {unit} -p ReadWritePaths --value | tr ' ' '\\n' | grep -Fx {shlex.quote(expected_path)}"
        )

    def assert_owner_mode(path, expected_owner_group, expected_mode):
        expected = f"{expected_owner_group} {expected_mode}"
        nixpi.succeed(
            f"stat -c '%U:%G %a' {shlex.quote(path)} | grep -qx {shlex.quote(expected)}"
        )

    nixpi.start()
    nixpi.wait_for_unit("multi-user.target", timeout=300)
    nixpi.wait_for_unit("nixpi-app-setup.service", timeout=120)
    nixpi.wait_for_unit("nixpi-pi-core-setup.service", timeout=120)
    nixpi.wait_for_unit("nixpi-gateway-setup.service", timeout=120)
    nixpi.wait_for_unit("nixpi-pi-core.service", timeout=120)
    nixpi.wait_for_unit("nixpi-signal-daemon.service", timeout=120)
    nixpi.wait_for_unit("nixpi-gateway.service", timeout=120)
    nixpi.wait_until_succeeds("test -S /run/nixpi-pi-core/pi-core.sock", timeout=60)
    nixpi.succeed("curl --unix-socket /run/nixpi-pi-core/pi-core.sock -fsS http://localhost/api/v1/health >/dev/null")
    nixpi.succeed("curl -fsS http://127.0.0.1:8080/api/v1/check >/dev/null")
    nixpi.fail("journalctl -b --no-pager | grep -F 'Detected unsafe path transition'")

    common_yes_props = [
        "NoNewPrivileges",
        "PrivateTmp",
        "PrivateDevices",
        "LockPersonality",
        "ProtectClock",
        "ProtectControlGroups",
        "ProtectKernelModules",
        "ProtectKernelTunables",
        "RestrictRealtime",
        "RestrictSUIDSGID",
    ]

    for unit in ["nixpi-pi-core.service", "nixpi-gateway.service", "nixpi-signal-daemon.service"]:
        for prop in common_yes_props:
            assert_unit_property(unit, prop, "yes")
        assert_unit_property(unit, "ProtectSystem", "strict")

    assert_unit_property("nixpi-pi-core.service", "ProtectHome", "no")
    assert_unit_property("nixpi-gateway.service", "ProtectHome", "yes")
    assert_unit_property("nixpi-signal-daemon.service", "ProtectHome", "yes")

    assert_readwrite_path("nixpi-pi-core.service", "/var/lib/nixpi/pi-core")
    assert_readwrite_path("nixpi-pi-core.service", "/var/lib/nixpi/pi-core/sessions")
    assert_readwrite_path("nixpi-pi-core.service", "/var/lib/nixpi/pi-core-pi")
    assert_readwrite_path("nixpi-pi-core.service", "/run/nixpi-pi-core")
    assert_readwrite_path("nixpi-pi-core.service", "/home/pi/nixpi")

    assert_readwrite_path("nixpi-gateway.service", "/var/lib/nixpi/gateway")
    assert_readwrite_path("nixpi-gateway.service", "/var/lib/nixpi/gateway/tmp")
    assert_readwrite_path("nixpi-gateway.service", "/var/lib/nixpi/gateway/modules/signal")
    assert_readwrite_path("nixpi-gateway.service", "/var/lib/nixpi/gateway/modules/signal/signal-cli-data")

    assert_readwrite_path("nixpi-signal-daemon.service", "/var/lib/nixpi/gateway/modules/signal")
    assert_readwrite_path("nixpi-signal-daemon.service", "/var/lib/nixpi/gateway/modules/signal/signal-cli-data")

    assert_owner_mode("/var/lib/nixpi", "root:root", "755")
    assert_owner_mode("/var/lib/nixpi/services", "pi:pi", "770")
    assert_owner_mode("/var/lib/nixpi/secrets", "root:pi", "750")
    assert_owner_mode("/var/lib/nixpi/broker", "root:pi", "770")
    assert_owner_mode("/var/lib/nixpi/pi-core", "nixpi-core:nixpi-core", "700")
    assert_owner_mode("/var/lib/nixpi/pi-core-pi", "nixpi-core:nixpi-core", "700")
    assert_owner_mode("/var/lib/nixpi/gateway", "nixpi-gateway:nixpi-gateway", "700")
    assert_owner_mode("/var/lib/nixpi/gateway/modules", "nixpi-gateway:nixpi-gateway", "700")
    assert_owner_mode("/var/lib/nixpi/gateway/tmp", "nixpi-gateway:nixpi-gateway", "700")
    assert_owner_mode("/var/lib/nixpi/gateway/modules/signal", "nixpi-gateway:nixpi-gateway", "700")
    assert_owner_mode("/var/lib/nixpi/gateway/modules/signal/signal-cli-data", "nixpi-gateway:nixpi-gateway", "700")

    print("NixPI service hardening test passed!")
  '';
}
