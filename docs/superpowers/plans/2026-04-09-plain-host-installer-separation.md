# Plain Host Installer Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate plain remote NixOS installation from NixPI by introducing a neutral `plain-host-deploy` surface, keeping OVH as the first provider preset/runbook, and leaving `nixpi-bootstrap-host` as the explicit second-stage path.

**Architecture:** Keep the underlying install implementation shared in-repo, but rename the public deploy package, script, app, tests, and docs so plain-host provisioning is no longer owned by `nixpi-*` entrypoints. Preserve the existing minimal OVH base profile and `nixos-anywhere` flow, while reorganizing product messaging and guard tests around a generic plain-host story plus a separate NixPI bootstrap story.

**Tech Stack:** Nix flakes, `nixos-anywhere`, Bash wrappers, Vitest, NixOS evaluation checks, VitePress docs

---

## File Structure

- Create: `core/scripts/plain-host-deploy.sh`
  Public neutral deploy wrapper replacing `nixpi-deploy-ovh.sh`.
- Create: `core/scripts/plain-host-ovh-common.sh`
  Shared helper logic for the OVH preset under the new plain-host namespace.
- Create: `core/os/pkgs/plain-host-deploy/default.nix`
  Nix package wrapper exposing `plain-host-deploy`.
- Create: `tests/integration/plain-host-deploy.test.ts`
  Integration coverage for the renamed neutral wrapper.
- Create: `docs/install-plain-host.md`
  User-facing “just install standard NixOS” entrypoint.
- Modify: `flake.nix`
  Replace the public package/app entrypoint and keep the OVH host profile wired in.
- Modify: `core/scripts/nixpi-deploy-ovh.sh`
  Remove after migration or replace with a short compatibility stub if needed during the refactor window.
- Modify: `core/scripts/nixpi-ovh-common.sh`
  Remove after moving logic to the new neutral helper.
- Modify: `core/os/pkgs/nixpi-deploy-ovh/default.nix`
  Remove after moving packaging to the new neutral package.
- Modify: `README.md`
  Reframe the repo around plain-host install plus optional NixPI bootstrap.
- Modify: `docs/install.md`
  Narrow this page to NixPI bootstrap on an already installed host and link to plain-host docs for day-0 install.
- Modify: `docs/operations/quick-deploy.md`
  Rename the public command and reframe it as a plain-host install followed by optional NixPI bootstrap.
- Modify: `docs/operations/ovh-rescue-deploy.md`
  Keep OVH-specific rescue guidance, but call the neutral deploy wrapper.
- Modify: `docs/reference/infrastructure.md`
  Replace the imperative helper row for `nixpi-deploy-ovh` with `plain-host-deploy`.
- Modify: `reinstall-nixpi-command.txt`
  Update the sample artifact to call the neutral base installer first.
- Modify: `tests/integration/standards-guard.test.ts`
  Enforce the new public naming boundary and docs language.

### Task 1: Rename the Public Deploy Surface to `plain-host-deploy`

**Files:**
- Create: `core/scripts/plain-host-deploy.sh`
- Create: `core/scripts/plain-host-ovh-common.sh`
- Create: `core/os/pkgs/plain-host-deploy/default.nix`
- Modify: `flake.nix`
- Modify: `tests/integration/plain-host-deploy.test.ts`
- Delete: `core/scripts/nixpi-deploy-ovh.sh`
- Delete: `core/scripts/nixpi-ovh-common.sh`
- Delete: `core/os/pkgs/nixpi-deploy-ovh/default.nix`

- [ ] **Step 1: Write the failing integration test for the new neutral wrapper name**

Create `tests/integration/plain-host-deploy.test.ts` by copying the current deploy-wrapper harness and changing the public contract to `plain-host-deploy`:

```ts
const deployScriptPath = path.join(repoRoot, "core/scripts/plain-host-deploy.sh");

describe("plain-host-deploy.sh", () => {
	it("shows usage and exits non-zero when required arguments are missing", async () => {
		const result = await run("bash", [deployScriptPath], undefined, repoRoot);

		expect(result.exitCode).toBe(1);
		expect(result.stderr).toContain("Usage: plain-host-deploy");
	});

	it("rejects legacy nixpi-specific bootstrap arguments", async () => {
		const result = await runDeploy([
			"--target-host",
			"root@198.51.100.10",
			"--disk",
			"/dev/sda",
			"--bootstrap-user",
			"alice",
		]);

		expect(result.exitCode).toBe(1);
		expect(result.stderr).toContain("Usage: plain-host-deploy");
		expect(result.stderr).toContain("Unsupported legacy option: --bootstrap-user");
	});
});
```

- [ ] **Step 2: Run the test to verify it fails because the new wrapper does not exist yet**

Run: `npx vitest run tests/integration/plain-host-deploy.test.ts`

Expected: FAIL with a missing-file or non-zero shell error referencing `core/scripts/plain-host-deploy.sh`

- [ ] **Step 3: Create the neutral helper and wrapper implementation**

Create `core/scripts/plain-host-ovh-common.sh` with the shared logic moved from the old helper and a neutral log prefix:

```bash
#!/usr/bin/env bash
set -euo pipefail

log() {
	printf '[plain-host-deploy] %s\n' "$*" >&2
}

run_ovh_deploy() {
	# keep the existing flake validation and temporary deploy-flake generation
	# behavior from nixpi-ovh-common.sh, but update log messaging to:
	log "nixos-anywhere will install a plain OVH base system only"
	log "After first boot, optionally run nixpi-bootstrap-host to layer NixPI onto /etc/nixos"
}
```

Create `core/scripts/plain-host-deploy.sh` with the renamed public usage:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/plain-host-ovh-common.sh"

usage() {
  cat <<'EOF_USAGE'
Usage: plain-host-deploy --target-host root@IP --disk /dev/sdX [--flake .#ovh-base] [--hostname HOSTNAME] [extra nixos-anywhere args...]

Destructive plain NixOS base install for an OVH VPS in rescue mode.
Optionally bootstrap NixPI afterward on the installed machine with nixpi-bootstrap-host.
EOF_USAGE
}
```

Create `core/os/pkgs/plain-host-deploy/default.nix`:

```nix
{ pkgs, makeWrapper, bash, nixosAnywherePackage }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "plain-host-deploy";
  version = "0.1.0";

  installPhase = ''
    mkdir -p "$out/bin" "$out/share/plain-host-deploy"
    install -m 0755 ${../../../scripts/plain-host-deploy.sh} "$out/share/plain-host-deploy/plain-host-deploy.sh"
    install -m 0755 ${../../../scripts/plain-host-ovh-common.sh} "$out/share/plain-host-deploy/plain-host-ovh-common.sh"
    makeWrapper ${bash}/bin/bash "$out/bin/plain-host-deploy" \
      --set NIXPI_NIXOS_ANYWHERE ${nixosAnywherePackage}/bin/nixos-anywhere \
      --add-flags "$out/share/plain-host-deploy/plain-host-deploy.sh"
  '';

  meta.mainProgram = "plain-host-deploy";
}
```

Update `flake.nix` package and app wiring:

```nix
plain-host-deploy = pkgs.callPackage ./core/os/pkgs/plain-host-deploy {
  nixosAnywherePackage = nixos-anywhere.packages.${system}.nixos-anywhere;
};
```

```nix
plain-host-deploy = {
  type = "app";
  program = "${self.packages.${system}.plain-host-deploy}/bin/plain-host-deploy";
};
```

- [ ] **Step 4: Run the renamed wrapper test and the existing OVH config test**

Run: `npx vitest run tests/integration/plain-host-deploy.test.ts tests/integration/ovh-base-config.test.ts`

Expected: PASS, confirming the renamed public surface still builds the same minimal OVH deploy flake and leaves NixPI bootstrap config out of the generated install target

- [ ] **Step 5: Remove the old public deploy wrapper files once the new tests pass**

Delete these files:

```text
core/scripts/nixpi-deploy-ovh.sh
core/scripts/nixpi-ovh-common.sh
core/os/pkgs/nixpi-deploy-ovh/default.nix
tests/integration/nixpi-deploy-ovh.test.ts
```

- [ ] **Step 6: Commit the public-surface rename**

```bash
git add core/scripts/plain-host-deploy.sh core/scripts/plain-host-ovh-common.sh core/os/pkgs/plain-host-deploy/default.nix flake.nix tests/integration/plain-host-deploy.test.ts core/scripts/nixpi-deploy-ovh.sh core/scripts/nixpi-ovh-common.sh core/os/pkgs/nixpi-deploy-ovh/default.nix tests/integration/nixpi-deploy-ovh.test.ts
git commit -m "Separate plain host deployment from NixPI branding

Expose a neutral plain-host-deploy surface for remote base installs
while keeping the OVH base profile and nixpi-bootstrap-host flow intact.

Constraint: Plain provisioning must stay compatible with existing ovh-base and nixos-anywhere behavior
Rejected: Keep nixpi-deploy-ovh as the public command | preserves the same product confusion
Confidence: high
Scope-risk: moderate
Directive: Keep plain-host-deploy free of NixPI bootstrap parameters and second-stage behavior
Tested: npx vitest run tests/integration/plain-host-deploy.test.ts tests/integration/ovh-base-config.test.ts
Not-tested: Live OVH rescue-mode execution
" 
```

### Task 2: Update Guard Tests and Repo Wiring Around the New Boundary

**Files:**
- Modify: `tests/integration/standards-guard.test.ts`
- Modify: `flake.nix`
- Test: `tests/integration/standards-guard.test.ts`

- [ ] **Step 1: Write the failing standards-guard expectations for the neutral deploy surface**

Update `tests/integration/standards-guard.test.ts` so the repo contract expects `plain-host-deploy` instead of `nixpi-deploy-ovh`:

```ts
it("keeps the example install artifact aligned with the plain-host-first flow", () => {
	const artifact = readUtf8(reinstallCommandPath);

	expect(artifact).toContain("nix run .#plain-host-deploy --");
	expect(artifact).toContain("nix run github:alexradunet/nixpi#nixpi-bootstrap-host --");
	expect(artifact).not.toContain("nixpi-deploy-ovh");
});
```

Add flake assertions for the new package/app:

```ts
expect(flake).toContain("plain-host-deploy = pkgs.callPackage ./core/os/pkgs/plain-host-deploy");
expect(flake).toContain('program = "${self.packages.${system}.plain-host-deploy}/bin/plain-host-deploy";');
expect(flake).not.toContain("nixpi-deploy-ovh = pkgs.callPackage");
```

- [ ] **Step 2: Run the guard test to verify it fails before the guard updates are complete**

Run: `npx vitest run tests/integration/standards-guard.test.ts`

Expected: FAIL on references that still expect `nixpi-deploy-ovh`

- [ ] **Step 3: Finish the guard-test and flake cleanup**

Apply the remaining standards-guard updates:

```ts
const legacyBootstrapTerms = [
	"nixpi-rebuild-pull",
	"nixpi-reinstall-ovh",
	"nixpi-deploy-ovh",
	"/srv/nixpi",
] as const;
```

Update the doc assertions that mention the public install command:

```ts
contains: ["plain host", "run `nixpi-bootstrap-host` on the machine"],
absent: ["nixpi-deploy-ovh", "nixpi-rebuild-pull", "/srv/nixpi"],
```

Keep `flake.nix` free of the old app stanza:

```nix
apps.${system} = {
  nixpi-bootstrap-host = { ... };
  plain-host-deploy = {
    type = "app";
    program = "${self.packages.${system}.plain-host-deploy}/bin/plain-host-deploy";
  };
};
```

- [ ] **Step 4: Run guard tests and the formatter/lint check**

Run: `npx vitest run tests/integration/standards-guard.test.ts`

Expected: PASS

Run: `npm run check`

Expected: PASS with no formatter or lint drift introduced by the rename

- [ ] **Step 5: Commit the contract enforcement updates**

```bash
git add tests/integration/standards-guard.test.ts flake.nix
git commit -m "Lock the repo contract to the plain-host deploy surface

Update standards guards and flake wiring so the public install path is
plain-host first and NixPI bootstrap second.

Constraint: Guard tests must describe the intended product boundary, not the old wrapper name
Rejected: Keep standards guards name-agnostic | weakens the separation we are trying to enforce
Confidence: high
Scope-risk: narrow
Directive: Treat plain-host-deploy as the only public day-0 install command in this repo
Tested: npx vitest run tests/integration/standards-guard.test.ts; npm run check
Not-tested: Full npm test suite
"
```

### Task 3: Rewrite Docs Around “Plain Host First, NixPI Optional Second”

**Files:**
- Create: `docs/install-plain-host.md`
- Modify: `README.md`
- Modify: `docs/install.md`
- Modify: `docs/operations/quick-deploy.md`
- Modify: `docs/operations/ovh-rescue-deploy.md`
- Modify: `docs/reference/infrastructure.md`
- Modify: `reinstall-nixpi-command.txt`
- Test: `tests/integration/standards-guard.test.ts`

- [ ] **Step 1: Write the failing doc guard expectations for the new public story**

Update `tests/integration/standards-guard.test.ts` to require the new plain-host page and neutral command examples:

```ts
const plainHostInstallDocPath = path.join(repoRoot, "docs/install-plain-host.md");

{
	label: relativePath(plainHostInstallDocPath),
	filePath: plainHostInstallDocPath,
	contains: ["Install Plain Host", "plain-host-deploy", "standard NixOS host"],
	absent: ["nixpi-deploy-ovh", "final host configuration directly"],
}
```

Change existing doc expectations so `README.md`, `docs/install.md`, and `docs/operations/quick-deploy.md` point to `plain-host-deploy` for day-0 install.

- [ ] **Step 2: Run the guard test to verify the new doc contract fails before docs are added**

Run: `npx vitest run tests/integration/standards-guard.test.ts`

Expected: FAIL because `docs/install-plain-host.md` does not exist yet and existing docs still mention `nixpi-deploy-ovh`

- [ ] **Step 3: Add the new plain-host install page and rewrite the existing docs**

Create `docs/install-plain-host.md`:

```md
---
title: Install Plain Host
description: Install a standard NixOS host onto a fresh OVH VPS through the repo's plain-host deploy surface.
---

# Install Plain Host

## Canonical install path

1. boot the VPS into provider rescue mode
2. run `nix run .#plain-host-deploy -- --target-host root@SERVER_IP --disk /dev/disk/by-id/...`
3. let `nixos-anywhere` install the plain `ovh-base` system
4. reconnect to the installed host

This flow installs standard NixOS only. NixPI is optional and can be layered later with `nixpi-bootstrap-host`.
```

Update `README.md` example:

```md
nix run .#plain-host-deploy -- \
  --target-host root@SERVER_IP \
  --disk /dev/disk/by-id/PERSISTENT_TARGET_DISK_ID

nix run github:alexradunet/nixpi#nixpi-bootstrap-host -- \
  --primary-user alex \
  --ssh-allowed-cidr YOUR_ADMIN_IP/32
```

Update `docs/install.md` to make it NixPI-specific:

```md
## Prerequisite

Install a plain host first using [Install Plain Host](./install-plain-host) or the provider runbook.

## Bootstrap NixPI on the machine
```

Update `docs/operations/quick-deploy.md` and `docs/operations/ovh-rescue-deploy.md` command examples:

```md
nix run .#plain-host-deploy -- \
  --target-host root@SERVER_IP \
  --disk /dev/disk/by-id/PERSISTENT_TARGET_DISK_ID
```

Update `docs/reference/infrastructure.md` imperative helper table:

```md
| `nix run .#plain-host-deploy -- ...` | Fresh provisioning still needs runtime inputs such as the rescue host, target disk, and optional staged `nixos-anywhere` flags. The plain-host installer keeps that imperative surface at install time instead of pretending rescue-mode inputs are steady-state host configuration. |
```

Update `reinstall-nixpi-command.txt`:

```text
nix run .#plain-host-deploy -- \
  --target-host root@SERVER_IP \
  --disk /dev/disk/by-id/PERSISTENT_TARGET_DISK_ID
```

- [ ] **Step 4: Run doc guard coverage and the targeted integration tests**

Run: `npx vitest run tests/integration/standards-guard.test.ts tests/integration/plain-host-deploy.test.ts`

Expected: PASS

- [ ] **Step 5: Commit the documentation split**

```bash
git add README.md docs/install-plain-host.md docs/install.md docs/operations/quick-deploy.md docs/operations/ovh-rescue-deploy.md docs/reference/infrastructure.md reinstall-nixpi-command.txt tests/integration/standards-guard.test.ts
git commit -m "Document plain-host install as a separate product surface

Add a dedicated plain-host install page and rewrite the day-0 docs so
standard NixOS installation no longer appears as a NixPI-branded flow.

Constraint: Users who only want standard NixOS on OVH should not need to read NixPI-first instructions
Rejected: Keep plain-host guidance buried inside Install NixPI | fails the product-separation goal
Confidence: high
Scope-risk: moderate
Directive: Keep day-0 install docs plain-host branded and reserve NixPI docs for second-stage bootstrap
Tested: npx vitest run tests/integration/standards-guard.test.ts tests/integration/plain-host-deploy.test.ts
Not-tested: Rendered VitePress site in a browser
"
```

### Task 4: Run Final Verification and Capture Remaining Gaps

**Files:**
- Modify: `docs/superpowers/plans/2026-04-09-plain-host-installer-separation.md`
- Verify: `flake.nix`
- Verify: `tests/integration/plain-host-deploy.test.ts`
- Verify: `tests/integration/ovh-base-config.test.ts`
- Verify: `tests/integration/standards-guard.test.ts`

- [ ] **Step 1: Run the targeted unit/integration verification set**

Run: `npx vitest run tests/integration/plain-host-deploy.test.ts tests/integration/ovh-base-config.test.ts tests/integration/standards-guard.test.ts`

Expected: PASS

- [ ] **Step 2: Run the repo-wide JS/TS test suite**

Run: `npm test`

Expected: PASS

- [ ] **Step 3: Run the static checks**

Run: `npm run check`

Expected: PASS

- [ ] **Step 4: Run the Nix evaluations and package build checks**

Run: `nix eval .#nixosConfigurations.ovh-base.config.networking.hostName --json`

Expected: `"nixos"`

Run: `nix build .#packages.x86_64-linux.plain-host-deploy --no-link`

Expected: PASS

- [ ] **Step 5: Commit the verification pass**

```bash
git add flake.nix tests/integration/plain-host-deploy.test.ts tests/integration/ovh-base-config.test.ts tests/integration/standards-guard.test.ts README.md docs/install-plain-host.md docs/install.md docs/operations/quick-deploy.md docs/operations/ovh-rescue-deploy.md docs/reference/infrastructure.md reinstall-nixpi-command.txt
git commit -m "Verify the plain-host and NixPI product split

Run the targeted verification set plus repo-level checks to confirm the
new public boundary is enforced in code, tests, and docs.

Constraint: The separation is only real if package wiring, docs, and tests all agree
Rejected: Stop after wrapper rename and docs edits | leaves the repo contract unenforced
Confidence: medium
Scope-risk: narrow
Directive: Do not reintroduce plain-host install surfaces under nixpi-* names without updating the product design
Tested: npx vitest run tests/integration/plain-host-deploy.test.ts tests/integration/ovh-base-config.test.ts tests/integration/standards-guard.test.ts; npm test; npm run check; nix eval .#nixosConfigurations.ovh-base.config.networking.hostName --json; nix build .#packages.x86_64-linux.plain-host-deploy --no-link
Not-tested: Real OVH rescue deployment after the rename
"
```

## Self-Review

### Spec coverage

- Generic plain-host product surface: covered by Task 1 and Task 3.
- Shared internals with separate public entrypoints: covered by Task 1.
- OVH as first provider preset/runbook: covered by Task 1 and Task 3.
- NixPI as explicit second stage: covered by Task 3.
- Guardrails against regression to `nixpi-*` day-0 naming: covered by Task 2 and Task 4.

No spec gaps found.

### Placeholder scan

- No `TBD`, `TODO`, or “similar to” placeholders remain.
- Every code-changing task includes explicit file paths, commands, and concrete snippets.

### Type consistency

- The plan consistently uses `plain-host-deploy` for the new public day-0 command.
- The OVH preset remains `ovh-base`.
- The second-stage command remains `nixpi-bootstrap-host`.

No naming inconsistencies found.
