# Remove Nginx — Direct Mesh Exposure Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove nginx from Bloom OS and expose services directly to the NetBird mesh on their native ports.

**Architecture:** Services bind via host networking (already the pattern for dufs/code-server). NetBird DNS resolves `{name}.bloom.mesh` → mesh IP. Firewall trusts `wt0` only. The `service-routing.ts` orchestrator becomes DNS-only.

**Tech Stack:** TypeScript, Vitest, Podman Quadlet, systemd, Fedora bootc Containerfile

**Spec:** `docs/superpowers/specs/2026-03-11-remove-nginx-netbird-direct-exposure-design.md`

---

## Chunk 1: Core Code — Simplify service-routing to DNS-only

### Task 1: Rewrite service-routing.ts tests for DNS-only

**Files:**
- Modify: `tests/lib/service-routing.test.ts`

- [ ] **Step 1: Rewrite the test file**

Replace the entire test file. Remove all nginx mocks and assertions. The new tests verify DNS-only behavior.

```typescript
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../lib/netbird.js", () => ({
	loadNetBirdToken: vi.fn(),
	getLocalMeshIp: vi.fn(),
	ensureBloomZone: vi.fn(),
	ensureServiceRecord: vi.fn(),
}));

import { ensureBloomZone, ensureServiceRecord, getLocalMeshIp, loadNetBirdToken } from "../../lib/netbird.js";
import { ensureServiceRouting } from "../../lib/service-routing.js";

describe("ensureServiceRouting", () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	it("rejects invalid service names", async () => {
		const result = await ensureServiceRouting("INVALID NAME!", 8080);
		expect(result.dns.ok).toBe(false);
		expect(result.dns.error).toBeDefined();
	});

	it("skips DNS when no token is available", async () => {
		vi.mocked(loadNetBirdToken).mockReturnValue(null);

		const result = await ensureServiceRouting("cinny", 18810);
		expect(result.dns.ok).toBe(false);
		expect(result.dns.skipped).toBe(true);
		expect(getLocalMeshIp).not.toHaveBeenCalled();
	});

	it("creates DNS record when token is available", async () => {
		vi.mocked(loadNetBirdToken).mockReturnValue("nbp_test");
		vi.mocked(getLocalMeshIp).mockResolvedValue("100.119.45.12");
		vi.mocked(ensureBloomZone).mockResolvedValue({ ok: true, zoneId: "zone-1" });
		vi.mocked(ensureServiceRecord).mockResolvedValue({ ok: true, recordId: "rec-1" });

		const result = await ensureServiceRouting("dufs", 5000);
		expect(result.dns.ok).toBe(true);
		expect(ensureBloomZone).toHaveBeenCalledWith("nbp_test");
		expect(ensureServiceRecord).toHaveBeenCalledWith("nbp_test", "zone-1", "dufs", "100.119.45.12");
	});

	it("handles mesh IP failure gracefully", async () => {
		vi.mocked(loadNetBirdToken).mockReturnValue("nbp_test");
		vi.mocked(getLocalMeshIp).mockResolvedValue(null);

		const result = await ensureServiceRouting("cinny", 18810);
		expect(result.dns.ok).toBe(false);
		expect(result.dns.error).toContain("mesh IP");
	});

	it("handles zone creation failure gracefully", async () => {
		vi.mocked(loadNetBirdToken).mockReturnValue("nbp_test");
		vi.mocked(getLocalMeshIp).mockResolvedValue("100.119.45.12");
		vi.mocked(ensureBloomZone).mockResolvedValue({ ok: false, error: "API error" });

		const result = await ensureServiceRouting("cinny", 18810);
		expect(result.dns.ok).toBe(false);
		expect(result.dns.error).toContain("API error");
	});

	it("handles record creation failure gracefully", async () => {
		vi.mocked(loadNetBirdToken).mockReturnValue("nbp_test");
		vi.mocked(getLocalMeshIp).mockResolvedValue("100.119.45.12");
		vi.mocked(ensureBloomZone).mockResolvedValue({ ok: true, zoneId: "zone-1" });
		vi.mocked(ensureServiceRecord).mockResolvedValue({ ok: false, error: "record limit reached" });

		const result = await ensureServiceRouting("cinny", 18810);
		expect(result.dns.ok).toBe(false);
		expect(result.dns.error).toContain("record limit reached");
	});
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test -- tests/lib/service-routing.test.ts`
Expected: FAIL — tests import from `../../lib/nginx.js` which still exists but the mock is gone, and `RoutingResult` still has `nginx` field that new tests don't use. The key failure is that the implementation still returns `nginx` in the result.

### Task 2: Rewrite service-routing.ts as DNS-only

**Files:**
- Modify: `lib/service-routing.ts`

- [ ] **Step 1: Rewrite the implementation**

Replace the entire file. Remove all nginx imports and logic. Simplify `RoutingResult` to DNS-only.

```typescript
/** Orchestration: creates NetBird DNS records for service subdomain routing. */

import { ensureBloomZone, ensureServiceRecord, getLocalMeshIp, loadNetBirdToken } from "./netbird.js";
import { validateServiceName } from "./services-validation.js";
import { createLogger } from "./shared.js";

const log = createLogger("service-routing");

const BLOOM_ZONE_DOMAIN = "bloom.mesh";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface RoutingResult {
	dns: { ok: boolean; skipped?: boolean; error?: string };
}

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------

/**
 * Ensure DNS routing for a service: create `{name}.bloom.mesh` A record.
 *
 * If no NetBird token is available, DNS is skipped (reported as `skipped`).
 * Services are directly reachable on their native port via the mesh IP.
 */
export async function ensureServiceRouting(
	serviceName: string,
	port: number,
	_options?: { websocket?: boolean; maxBodySize?: string },
	signal?: AbortSignal,
): Promise<RoutingResult> {
	const guard = validateServiceName(serviceName);
	if (guard) {
		return { dns: { ok: false, error: guard } };
	}

	const token = loadNetBirdToken();
	if (!token) {
		log.info("no NetBird API token — skipping DNS record creation", { serviceName });
		return { dns: { ok: false, skipped: true } };
	}

	const meshIp = await getLocalMeshIp(signal);
	if (!meshIp) {
		return { dns: { ok: false, error: "Could not determine local mesh IP from netbird status" } };
	}

	const zone = await ensureBloomZone(token);
	if (!zone.ok || !zone.zoneId) {
		return { dns: { ok: false, error: zone.error ?? "Failed to ensure bloom.mesh zone" } };
	}

	const record = await ensureServiceRecord(token, zone.zoneId, serviceName, meshIp);
	return { dns: { ok: record.ok, error: record.error } };
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `npm run test -- tests/lib/service-routing.test.ts`
Expected: All 5 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/service-routing.ts tests/lib/service-routing.test.ts
git commit -m "refactor: simplify service-routing to DNS-only, remove nginx integration"
```

### Task 3: Delete nginx.ts and its tests

**Files:**
- Delete: `lib/nginx.ts`
- Delete: `tests/lib/nginx.test.ts`

- [ ] **Step 1: Delete the files using git rm**

```bash
git rm lib/nginx.ts tests/lib/nginx.test.ts
```

- [ ] **Step 2: Run full test suite to verify no breakage**

Run: `npm run test`
Expected: All tests pass. No other file imports from `lib/nginx.js` (we already removed the import in service-routing.ts).

- [ ] **Step 3: Run type check**

Run: `npm run build`
Expected: Clean build with no errors.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: delete nginx.ts and tests — no longer needed"
```

### Task 4: Update actions-install.ts to remove nginx references

**Files:**
- Modify: `extensions/bloom-services/actions-install.ts`

- [ ] **Step 1: Update the routing call and log lines**

In `extensions/bloom-services/actions-install.ts`:

Change the routing call at line 92-101. Remove the `websocket` option and nginx log line:

```typescript
// Old (line 91-101):
	// Set up subdomain routing (DNS + nginx vhost) if port is defined
	if (catalogEntry?.port) {
		const routing = await ensureServiceRouting(
			params.name,
			catalogEntry.port,
			{ websocket: catalogEntry.websocket },
			signal,
		);
		if (!routing.nginx.ok) log.warn("nginx vhost failed", { service: params.name, error: routing.nginx.error });
		if (!routing.dns.ok && !routing.dns.skipped)
			log.warn("DNS record failed", { service: params.name, error: routing.dns.error });
	}

// New:
	// Set up DNS routing ({name}.bloom.mesh) if port is defined
	if (catalogEntry?.port) {
		const routing = await ensureServiceRouting(params.name, catalogEntry.port, undefined, signal);
		if (!routing.dns.ok && !routing.dns.skipped)
			log.warn("DNS record failed", { service: params.name, error: routing.dns.error });
	}
```

Do the same for the dependency routing block at line 159-165:

```typescript
// Old (line 159-165):
		// Set up subdomain routing for dependency
		if (depCatalog?.port) {
			const depRouting = await ensureServiceRouting(dep, depCatalog.port, { websocket: depCatalog.websocket }, signal);
			if (!depRouting.nginx.ok) log.warn("dep nginx vhost failed", { dep, error: depRouting.nginx.error });
			if (!depRouting.dns.ok && !depRouting.dns.skipped)
				log.warn("dep DNS record failed", { dep, error: depRouting.dns.error });
		}

// New:
		// Set up DNS routing for dependency
		if (depCatalog?.port) {
			const depRouting = await ensureServiceRouting(dep, depCatalog.port, undefined, signal);
			if (!depRouting.dns.ok && !depRouting.dns.skipped)
				log.warn("dep DNS record failed", { dep, error: depRouting.dns.error });
		}
```

- [ ] **Step 2: Run build to verify types**

Run: `npm run build`
Expected: Clean build — `RoutingResult` no longer has `nginx` field, and we no longer reference it.

- [ ] **Step 3: Commit**

```bash
git add extensions/bloom-services/actions-install.ts
git commit -m "refactor: update install handler to use DNS-only routing"
```

### Task 5: Update ServiceCatalogEntry type and catalog.yaml

**Files:**
- Modify: `lib/services-manifest.ts`
- Modify: `services/catalog.yaml`

- [ ] **Step 1: Remove websocket field from ServiceCatalogEntry**

In `lib/services-manifest.ts`, remove the `websocket` field and update the `port` JSDoc:

```typescript
// Old (lines 34-37):
	/** Host port for nginx reverse proxy routing. */
	port?: number;
	/** Whether the service uses WebSocket connections (adds upgrade headers to nginx vhost). */
	websocket?: boolean;

// New:
	/** Host port for direct mesh access and DNS routing. */
	port?: number;
```

- [ ] **Step 2: Remove websocket entries from catalog.yaml**

In `services/catalog.yaml`, remove the `websocket: true` lines (lines 10 and 27):

```yaml
# Old dufs entry:
  dufs:
    version: "0.1.0"
    category: sync
    image: docker.io/sigoden/dufs:v0.38.0
    optional: false
    port: 5000
    websocket: true
    preflight:
      commands: [podman, systemctl]

# New:
  dufs:
    version: "0.1.0"
    category: sync
    image: docker.io/sigoden/dufs:v0.38.0
    optional: false
    port: 5000
    preflight:
      commands: [podman, systemctl]
```

```yaml
# Old code-server entry:
  code-server:
    version: "0.1.0"
    category: development
    image: localhost/bloom-code-server:latest
    optional: true
    port: 8443
    websocket: true
    preflight:
      commands: [podman, systemctl]

# New:
  code-server:
    version: "0.1.0"
    category: development
    image: localhost/bloom-code-server:latest
    optional: true
    port: 8443
    preflight:
      commands: [podman, systemctl]
```

- [ ] **Step 3: Run build and tests**

Run: `npm run build && npm run test`
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add lib/services-manifest.ts services/catalog.yaml
git commit -m "chore: remove websocket field from catalog — nginx-specific"
```

---

## Chunk 2: Container and OS Changes

### Task 6: Expose Cinny container on all interfaces

**Files:**
- Modify: `services/cinny/quadlet/bloom-cinny.container`

**Spec deviation:** The spec says to use `Network=host` for Cinny, but `Network=host` prevents port remapping. The Cinny image listens on port 80 internally, and we want it exposed on 18810. With host networking we can't remap 80→18810. The cleanest approach is to keep bridge networking (default podman bridge, not `bloom.network`) but publish on all interfaces instead of localhost-only:

- [ ] **Step 1: Update the quadlet file**

```ini
[Unit]
Description=Bloom Cinny Matrix Web Client
After=network-online.target
Wants=network-online.target

[Container]
Image=ghcr.io/cinnyapp/cinny:v4.3.0
ContainerName=bloom-cinny

# Direct mesh access on port 18810 (firewall trusts wt0 only)
PublishPort=18810:80

# Custom config pointing to local homeserver
Volume=%h/.config/bloom/cinny-config.json:/usr/share/nginx/html/config.json:ro,Z

PodmanArgs=--memory=64m
PodmanArgs=--security-opt label=disable
HealthCmd=wget -qO- http://localhost:80/ || exit 1
HealthInterval=30s
HealthRetries=3
HealthTimeout=10s
HealthStartPeriod=30s
NoNewPrivileges=true
LogDriver=journald

[Service]
Restart=on-failure
RestartSec=10
TimeoutStartSec=120
TimeoutStopSec=30

[Install]
WantedBy=default.target
```

Key changes:
- Removed `Network=bloom.network` (no longer needed — not using nginx proxy)
- Changed `PublishPort=127.0.0.1:18810:80` to `PublishPort=18810:80` (binds all interfaces)
- Updated comment from "nginx proxies" to "direct mesh access"

- [ ] **Step 2: Commit**

```bash
git add services/cinny/quadlet/bloom-cinny.container
git commit -m "feat: expose Cinny directly on mesh — remove localhost-only binding"
```

### Task 7: Update Cinny config for direct Matrix access

**Files:**
- Modify: `services/cinny/cinny-config.json`

- [ ] **Step 1: Update homeserver URL**

The relative path `"/"` only worked because nginx served both Cinny and Matrix on port 80. Now Cinny is on 18810 and Matrix is on 6167.

```json
{
	"defaultHomeserver": 0,
	"homeserverList": ["http://bloom.mesh:6167"],
	"allowCustomHomeservers": true
}
```

- [ ] **Step 2: Commit**

```bash
git add services/cinny/cinny-config.json
git commit -m "fix: point Cinny homeserver to bloom.mesh:6167 (no longer behind nginx)"
```

### Task 8: Update service template for host networking pattern

**Files:**
- Modify: `services/_template/quadlet/bloom-TEMPLATE.container`

- [ ] **Step 1: Update the template**

```ini
[Unit]
Description=Bloom TEMPLATE Service
After=network-online.target
Wants=network-online.target

[Container]
Image=localhost/bloom-TEMPLATE:latest
ContainerName=bloom-TEMPLATE
User=0

# Host networking for direct mesh access
Network=host

# Service state persists across restarts
# TODO: Adjust volume name and mount path for your service
Volume=bloom-TEMPLATE-data:/data/TEMPLATE

Environment=NODE_ENV=production

# Service-specific config
EnvironmentFile=%h/.config/bloom/TEMPLATE.env

PodmanArgs=--memory=256m
PodmanArgs=--security-opt label=disable
# TODO: Assign a unique port (check catalog.yaml for used ports)
HealthCmd=wget -qO- http://localhost:18800/health || exit 1
HealthInterval=30s
HealthRetries=3
HealthTimeout=10s
HealthStartPeriod=60s
NoNewPrivileges=true
LogDriver=journald

[Service]
Restart=on-failure
RestartSec=10
TimeoutStartSec=300
TimeoutStopSec=30

[Install]
WantedBy=default.target
```

Key changes:
- `Network=bloom.network` → `Network=host`
- Removed `PublishPort=127.0.0.1:18800:18800` (host networking exposes directly)
- Updated comment

- [ ] **Step 2: Commit**

```bash
git add services/_template/quadlet/bloom-TEMPLATE.container
git commit -m "chore: update service template to use host networking"
```

### Task 9: Update scaffold action for host networking

**Files:**
- Modify: `extensions/bloom-services/actions-scaffold.ts`

- [ ] **Step 1: Update the scaffold to generate host networking by default**

In `extensions/bloom-services/actions-scaffold.ts`, change line 63 and 67-68:

```typescript
// Old (line 63):
	const network = params.network ?? "bloom.network";

// New:
	const network = params.network ?? "host";
```

Remove the `maybePublish` variable entirely (lines 67-68) and remove `${maybePublish}` from the template string at line 72. With `Network=host`, `PublishPort` is not used.

```typescript
// Old (line 67-68):
	const maybePublish =
		!enableSocket && params.port ? `PublishPort=127.0.0.1:${Math.round(params.port)}:${containerPort}\n` : "";

// Delete these two lines entirely, and in the template string (line 72), remove ${maybePublish}.
```

Also update the socket unit's `ListenStream` to bind all interfaces (line 76):

```typescript
// Old (line 76):
		const socketUnit = `[Unit]\nDescription=Bloom ${params.name} — Socket activation listener\n\n[Socket]\nListenStream=127.0.0.1:${Math.round(params.port)}\nAccept=no\nService=bloom-${params.name}.service\nSocketMode=0660\n\n[Install]\nWantedBy=sockets.target\n`;

// New (remove 127.0.0.1: prefix — bind all interfaces for mesh access):
		const socketUnit = `[Unit]\nDescription=Bloom ${params.name} — Socket activation listener\n\n[Socket]\nListenStream=${Math.round(params.port)}\nAccept=no\nService=bloom-${params.name}.service\nSocketMode=0660\n\n[Install]\nWantedBy=sockets.target\n`;
```

- [ ] **Step 2: Run build**

Run: `npm run build`
Expected: Clean.

- [ ] **Step 3: Commit**

```bash
git add extensions/bloom-services/actions-scaffold.ts
git commit -m "refactor: scaffold generates host networking by default"
```

### Task 10: Remove nginx from OS image

**Files:**
- Modify: `os/Containerfile`
- Delete: `os/sysconfig/bloom-nginx.conf`
- Delete: `os/sysconfig/bloom-status.html`

- [ ] **Step 1: Remove nginx from dnf install**

In `os/Containerfile` line 35, remove `nginx \` from the `dnf install` list:

```dockerfile
# Old line 35:
    nginx \

# Remove this line entirely.
```

- [ ] **Step 2: Remove nginx config block**

Delete lines 125-130 from `os/Containerfile`:

```dockerfile
# Delete these lines:
# Nginx reverse proxy — route subdomains to backend services
COPY os/sysconfig/bloom-nginx.conf /etc/nginx/conf.d/bloom.conf
COPY os/sysconfig/bloom-status.html /usr/share/nginx/html/index.html
RUN rm -f /etc/nginx/conf.d/default.conf
RUN setsebool -P httpd_can_network_connect 1
RUN systemctl enable nginx.service
```

- [ ] **Step 3: Delete nginx config files**

```bash
rm os/sysconfig/bloom-nginx.conf os/sysconfig/bloom-status.html
```

- [ ] **Step 4: Run lint**

Run: `npm run check`
Expected: Clean.

- [ ] **Step 5: Commit**

```bash
git add -u os/Containerfile os/sysconfig/bloom-nginx.conf os/sysconfig/bloom-status.html
git commit -m "feat: remove nginx from OS image — services exposed directly via mesh"
```

---

## Chunk 3: Documentation and Cleanup

### Task 11: Update service-management skill

**Files:**
- Modify: `skills/service-management/SKILL.md`

- [ ] **Step 1: Update the Subdomain Access section**

Replace lines 39-47:

```markdown
## Mesh Access

When a service has a `port` defined in `services/catalog.yaml`, `service_install` automatically creates:
- A NetBird DNS A record for `{name}.bloom.mesh` (if `NETBIRD_API_TOKEN` is set in `~/.config/bloom/netbird.env`)

After installation, services are accessible at `http://{name}.bloom.mesh:{port}` from any mesh peer. Services bind directly to the host network — no reverse proxy is needed.

If no NetBird token is configured, DNS is skipped. Services remain accessible via the device's mesh IP and port directly.
```

- [ ] **Step 2: Remove Nginx from OS-Level Infrastructure table**

Replace line 120:

```markdown
# Old:
| Nginx | `nginx.service` | Reverse proxy, Cinny web client |

# Remove this line entirely.
```

- [ ] **Step 3: Commit**

```bash
git add skills/service-management/SKILL.md
git commit -m "docs: update service-management skill — nginx removed, direct mesh access"
```

### Task 12: Update first-boot skill

**Files:**
- Modify: `skills/first-boot/SKILL.md`

- [ ] **Step 1: Update the Matrix step's Cinny URL**

In `skills/first-boot/SKILL.md` line 62, update the Cinny URL:

```markdown
# Old (line 62):
8. Tell user: open `http://<host>/cinny/`, login as `user` (localpart only, not `@user:bloom`), password shown

# New:
8. Tell user: open `http://cinny.bloom.mesh:18810`, login as `user` (localpart only, not `@user:bloom`), password shown
```

- [ ] **Step 2: Commit**

```bash
git add skills/first-boot/SKILL.md
git commit -m "docs: update first-boot Cinny URL to direct mesh access"
```

### Task 13: Final verification

- [ ] **Step 1: Run full build**

Run: `npm run build`
Expected: Clean, no errors.

- [ ] **Step 2: Run full test suite**

Run: `npm run test`
Expected: All tests pass.

- [ ] **Step 3: Run lint**

Run: `npm run check`
Expected: Clean.

- [ ] **Step 4: Verify no stale nginx references in code**

Run: `grep -r "nginx" lib/ extensions/ tests/ --include="*.ts" -l`
Expected: No files returned.

- [ ] **Step 5: Commit any remaining fixes if needed**
