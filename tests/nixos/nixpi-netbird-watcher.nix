{ lib, nixPiModulesNoShell, mkTestFilesystems, piAgent, appPackage, setupPackage, ... }:

{
  name = "nixpi-netbird-watcher";

  nodes.nixpi = { pkgs, lib, ... }: {
    _module.args = { inherit piAgent appPackage setupPackage; };
    imports = nixPiModulesNoShell ++ [ mkTestFilesystems ];

    nixpi.primaryUser = "pi";
    networking.hostName = "testpi";
    system.stateVersion = "25.05";
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    virtualisation.diskSize = 4096;
    virtualisation.memorySize = 1024;

    users.users.pi = {
      isNormalUser = true;
      group = "pi";
      extraGroups = [ "wheel" ];
    };
    users.groups.pi = { };

    nixpi.netbird.apiTokenFile = "/var/lib/nixpi/netbird-api-token";
    nixpi.netbird.apiEndpoint = "http://127.0.0.1:19998";

    # The watcher test uses a mock Matrix server on the normal local Matrix port.
    services.matrix-continuwuity.enable = lib.mkForce false;

    system.activationScripts.watcher-test-setup = ''
      install -d -m 0750 -o pi -g pi /var/lib/nixpi
      echo -n "test-token" > /var/lib/nixpi/netbird-api-token
      chown pi:pi /var/lib/nixpi/netbird-api-token
      chmod 0600 /var/lib/nixpi/netbird-api-token

      install -d -m 0700 -o pi -g pi /var/lib/nixpi/netbird-watcher
      echo -n "matrix-bot-token" > /var/lib/nixpi/netbird-watcher/matrix-token
      chown pi:pi /var/lib/nixpi/netbird-watcher/matrix-token
      chmod 0600 /var/lib/nixpi/netbird-watcher/matrix-token
    '';

    systemd.services.mock-netbird-events = {
      description = "Mock NetBird events API";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "mock-netbird-events" ''
          ${pkgs.python3}/bin/python3 -c "
import http.server, json

EVENTS = [
  {\"id\": \"2\", \"timestamp\": \"2026-03-24T12:01:00Z\", \"activity\": \"peer.add\",
   \"meta\": {\"peer\": \"laptop\", \"ip\": \"100.64.0.2\"}, \"initiator_id\": \"\", \"target_id\": \"\"},
  {\"id\": \"1\", \"timestamp\": \"2026-03-24T12:00:00Z\", \"activity\": \"user.login\",
   \"meta\": {\"email\": \"admin@example.com\"}, \"initiator_id\": \"\", \"target_id\": \"\"},
]

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        if self.path.startswith('/api/events'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(EVENTS).encode())
            return
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps([]).encode())
    def do_POST(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({\"id\": \"test-id\"}).encode())
    def do_PUT(self):
        self.do_POST()

http.server.HTTPServer(('127.0.0.1', 19998), H).serve_forever()
"
        '';
      };
    };

    systemd.services.mock-matrix-api = {
      description = "Mock Matrix API";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "mock-matrix-api" ''
          ${pkgs.python3}/bin/python3 -c "
import http.server, json

MESSAGES = []

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        if self.path.startswith('/_matrix/client/v3/directory/room/'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({\"room_id\": \"!network:testpi\"}).encode())
            return
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({}).encode())
    def do_PUT(self):
        length = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(length))
        MESSAGES.append(body.get('body', \"\"))
        with open('/tmp/matrix-messages.json', 'w') as handle:
            handle.write(json.dumps(MESSAGES))
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({\"event_id\": \"evt1\"}).encode())

http.server.HTTPServer(('127.0.0.1', 6167), H).serve_forever()
"
        '';
      };
    };
  };

  testScript = ''
    import json

    nixpi = machines[0]

    nixpi.start()
    nixpi.wait_for_unit("multi-user.target", timeout=120)
    nixpi.wait_for_unit("mock-netbird-events.service", timeout=30)
    nixpi.wait_for_unit("mock-matrix-api.service", timeout=30)

    nixpi.succeed("systemctl is-active nixpi-netbird-watcher.timer")

    nixpi.succeed("systemctl start nixpi-netbird-watcher.service")

    nixpi.succeed("test -f /var/lib/nixpi/netbird-watcher/last-event-id")
    last_id = nixpi.succeed("cat /var/lib/nixpi/netbird-watcher/last-event-id").strip()
    assert last_id == "2", f"Expected last-event-id '2', got '{last_id}'"

    nixpi.succeed("test -f /tmp/matrix-messages.json")
    messages = nixpi.succeed("cat /tmp/matrix-messages.json")
    assert "New peer joined" in messages, "Missing peer.add message"
    assert "User logged in" in messages, "Missing user.login message"

    nixpi.succeed("systemctl start nixpi-netbird-watcher.service")
    messages2 = nixpi.succeed("cat /tmp/matrix-messages.json")
    assert len(json.loads(messages2)) == 2, "Expected no additional messages on second run"

    print("NetBird watcher test passed")
  '';
}
