# Core Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove dead code stubs, stale doc references, and tests that only assert the absence of already-deleted features, so `core/` cleanly reflects the Day-1+ NixPI boundary.

**Architecture:** Four independent change groups applied in sequence: (A) delete dead `core/` files, (B) fix stale `nixpi-deploy-ovh` doc references, (C) remove NixOS VM `fail` assertions for removed commands/services, (D) remove `existsSync(...).toBe(false)` guards and their unused path variables from the standards guard. Each group gets its own commit. No new features introduced.

**Tech Stack:** Nix, Bash, TypeScript/Vitest, Biome formatter

---

## File Structure

- Delete: `core/os/modules/install-finalize.nix`
- Delete: `core/scripts/nixpi-install-finalize.sh`
- Delete: `core/os/pkgs/nixpi-deploy-ovh/` (empty dir)
- Delete: `core/os/pkgs/nixpi-setup-apply/` (empty dir)
- Delete: `core/os/pkgs/plain-host-deploy/` (empty dir stub)
- Modify: `docs/operations/live-testing.md`
- Modify: `docs/operations/first-boot-setup.md`
- Modify: `tests/nixos/nixpi-e2e.nix`
- Modify: `tests/nixos/nixpi-firstboot.nix`
- Modify: `tests/nixos/nixpi-post-setup-lockdown.nix`
- Modify: `tests/nixos/nixpi-security.nix`
- Modify: `tests/nixos/nixpi-system-flake.nix`
- Modify: `tests/integration/standards-guard.test.ts`

---

### Task 1: Delete dead `core/` stubs

**Files:**
- Delete: `core/os/modules/install-finalize.nix`
- Delete: `core/scripts/nixpi-install-finalize.sh`
- Delete: `core/os/pkgs/nixpi-deploy-ovh/` (empty)
- Delete: `core/os/pkgs/nixpi-setup-apply/` (empty)
- Delete: `core/os/pkgs/plain-host-deploy/` (empty)

- [ ] **Step 1: Confirm nothing imports or references the dead files**

Run:
```bash
grep -rn "install-finalize\|nixpi-setup-apply\|nixpi-deploy-ovh" \
  core/ flake.nix \
  --include="*.nix" --include="*.ts" --include="*.sh" | \
  grep -v ".worktrees"
```

Expected: no output (none of these are wired in the active codebase).

- [ ] **Step 2: Delete the files and empty directories**

```bash
rm core/os/modules/install-finalize.nix
rm core/scripts/nixpi-install-finalize.sh
rmdir core/os/pkgs/nixpi-deploy-ovh
rmdir core/os/pkgs/nixpi-setup-apply
rmdir core/os/pkgs/plain-host-deploy
```

- [ ] **Step 3: Run the full test suite and static checks**

```bash
npm run check && npx vitest run tests/integration/standards-guard.test.ts
```

Expected: `Checked N files in Xms. No fixes applied.` and `1 passed (31 tests)`.

No NixOS `nix eval` is needed because none of these files are imported by any module set or wired in `flake.nix`.

- [ ] **Step 4: Commit**

```bash
git add -u core/
git commit -m "$(cat <<'EOF'
Remove dead core/ stubs from provisioner migration

Delete install-finalize module and script (deprecated, only printed
warnings/errors), and three empty package directories whose content
was already moved or removed in prior migrations.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Fix stale `nixpi-deploy-ovh` references in docs

**Files:**
- Modify: `docs/operations/live-testing.md`
- Modify: `docs/operations/first-boot-setup.md`
- Modify: `tests/integration/standards-guard.test.ts` (add guard assertions for the fix)

- [ ] **Step 1: Add failing guard assertions for the doc fixes**

In `tests/integration/standards-guard.test.ts`, find the `hostOwnedBootstrapDocCases` entry for `liveTestingDocPath` (currently has `contains: ["base install then bootstrap", ...]`). Add `"plain-host-deploy"` to its `contains` array and `"nixpi-deploy-ovh"` to its `absent` array:

```ts
{
    label: relativePath(liveTestingDocPath),
    filePath: liveTestingDocPath,
    contains: ["base install then bootstrap", "`nixpi-bootstrap-host` on the machine", "plain-host-deploy"],
    absent: ["final `ovh-vps` host configuration directly", "nixpi-rebuild-pull", "/srv/nixpi", "nixpi-deploy-ovh"],
},
```

Find the `hostOwnedBootstrapDocCases` entry for `firstBootDocPath` (currently `absent: ["nixpi-rebuild-pull", "<checkout-path>#ovh-vps", "/srv/nixpi"]`). Add `"nixpi-deploy-ovh"` to the `absent` array:

```ts
{
    label: relativePath(firstBootDocPath),
    filePath: firstBootDocPath,
    contains: ["run `nixpi-bootstrap-host`", "`/etc/nixos#nixos`"],
    absent: ["nixpi-rebuild-pull", "<checkout-path>#ovh-vps", "/srv/nixpi", "nixpi-deploy-ovh"],
},
```

- [ ] **Step 2: Run the guard test to confirm it fails**

```bash
npx vitest run tests/integration/standards-guard.test.ts
```

Expected: FAIL — the two doc cases fail because the docs still contain `nixpi-deploy-ovh` and don't yet contain `plain-host-deploy`.

- [ ] **Step 3: Fix `docs/operations/live-testing.md`**

Replace line 16:
```
2. Run `nix run .#nixpi-deploy-ovh -- ...`.
```
With:
```
2. Run `nix run .#plain-host-deploy -- ...`.
```

Replace line 52:
```
- The `nixpi-deploy-ovh` install completes on a clean headless VPS.
```
With:
```
- The `plain-host-deploy` install completes on a clean headless VPS.
```

- [ ] **Step 4: Fix `docs/operations/first-boot-setup.md`**

Replace line 13:
```
1. a completed plain-base install such as `nixpi-deploy-ovh`
```
With:
```
1. a completed plain-base install via `plain-host-deploy`
```

- [ ] **Step 5: Run the guard test to confirm it passes**

```bash
npx vitest run tests/integration/standards-guard.test.ts
```

Expected: `1 passed (31 tests)`.

- [ ] **Step 6: Run static checks**

```bash
npm run check
```

Expected: `No fixes applied.`

- [ ] **Step 7: Commit**

```bash
git add docs/operations/live-testing.md docs/operations/first-boot-setup.md tests/integration/standards-guard.test.ts
git commit -m "$(cat <<'EOF'
Replace stale nixpi-deploy-ovh references with plain-host-deploy

Update live-testing and first-boot-setup docs to use the current
provisioner command name and add guard assertions to keep them aligned.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Remove NixOS VM `fail` assertions for deleted features

**Files:**
- Modify: `tests/nixos/nixpi-e2e.nix`
- Modify: `tests/nixos/nixpi-firstboot.nix`
- Modify: `tests/nixos/nixpi-post-setup-lockdown.nix`
- Modify: `tests/nixos/nixpi-security.nix`
- Modify: `tests/nixos/nixpi-system-flake.nix`

- [ ] **Step 1: Remove 5 lines from `tests/nixos/nixpi-e2e.nix`**

Remove these exact lines (they appear together in the "after first-boot steady-state" block):
```nix
    nixpi.fail("command -v nixpi-setup-apply")
```
```nix
    nixpi.fail("systemctl cat nixpi-install-finalize.service >/dev/null")
    nixpi.fail("command -v nixpi-bootstrap-ensure-repo-target")
    nixpi.fail("command -v nixpi-bootstrap-prepare-repo")
    nixpi.fail("command -v nixpi-bootstrap-nixos-rebuild-switch")
```

The block currently reads (context for finding the right location):
```nix
    nixpi.fail("sudo -u pi -- sudo -n true")
    nixpi.fail("command -v nixpi-setup-apply")   # ← remove this line

    client.succeed("nc -z -w 2 pi 22")
```
And:
```nix
    nixpi.fail("test -e /etc/nixos/nixpi-integration.nix")
    nixpi.fail("systemctl cat nixpi-install-finalize.service >/dev/null")   # ← remove
    nixpi.fail("command -v nixpi-bootstrap-ensure-repo-target")              # ← remove
    nixpi.fail("command -v nixpi-bootstrap-prepare-repo")                    # ← remove
    nixpi.fail("command -v nixpi-bootstrap-nixos-rebuild-switch")            # ← remove

    groups = nixpi.succeed("groups " + username).strip()
```

- [ ] **Step 2: Remove 2 lines from `tests/nixos/nixpi-firstboot.nix`**

```nix
    nixpi.fail("command -v nixpi-setup-apply")   # ← remove (near top of test block)
```
Context:
```nix
    nixpi.succeed("ss -ltn '( sport = :22 )' | grep -q LISTEN")
    nixpi.fail("command -v nixpi-setup-apply")   # ← remove
```

```nix
    nixpi.fail("systemctl cat nixpi-install-finalize.service >/dev/null")   # ← remove
```
Context:
```nix
    nixpi.fail("test -f /etc/nixos/flake.nix")
    nixpi.fail("systemctl cat nixpi-install-finalize.service >/dev/null")   # ← remove
    nixpi.fail("command -v codex")
```

- [ ] **Step 3: Remove 1 line from `tests/nixos/nixpi-post-setup-lockdown.nix`**

```nix
    nixpi.fail("command -v nixpi-setup-apply")   # ← remove
```
Context:
```nix
    nixpi.succeed("command -v pi")
    nixpi.fail("command -v nixpi-setup-apply")   # ← remove

    client.start()
```

- [ ] **Step 4: Remove 1 line from `tests/nixos/nixpi-security.nix`**

```nix
    steady.fail("command -v nixpi-setup-apply")   # ← remove
```
Context:
```nix
    steady.succeed("command -v pi")
    steady.fail("command -v nixpi-setup-apply")   # ← remove

    client.start()
```

- [ ] **Step 5: Remove 1 line from `tests/nixos/nixpi-system-flake.nix`**

```nix
    machine.fail("systemctl cat nixpi-install-finalize.service >/dev/null")   # ← remove
```
Context:
```nix
    machine.fail("test -f /etc/nixos/flake.nix")
    machine.fail("systemctl cat nixpi-install-finalize.service >/dev/null")   # ← remove

    print("nixpi-system-flake test passed!")
```

- [ ] **Step 6: Verify Nix syntax on all 5 changed files**

```bash
nix-instantiate --parse tests/nixos/nixpi-e2e.nix > /dev/null && \
nix-instantiate --parse tests/nixos/nixpi-firstboot.nix > /dev/null && \
nix-instantiate --parse tests/nixos/nixpi-post-setup-lockdown.nix > /dev/null && \
nix-instantiate --parse tests/nixos/nixpi-security.nix > /dev/null && \
nix-instantiate --parse tests/nixos/nixpi-system-flake.nix > /dev/null && \
echo "all ok"
```

Expected: `all ok`

- [ ] **Step 7: Run static checks**

```bash
npm run check
```

Expected: `No fixes applied.`

- [ ] **Step 8: Commit**

```bash
git add tests/nixos/nixpi-e2e.nix tests/nixos/nixpi-firstboot.nix tests/nixos/nixpi-post-setup-lockdown.nix tests/nixos/nixpi-security.nix tests/nixos/nixpi-system-flake.nix
git commit -m "$(cat <<'EOF'
Remove NixOS VM absence assertions for deleted features

Drop fail assertions for nixpi-setup-apply, nixpi-install-finalize
service, and old bootstrap commands. These features are gone and have
no code path to return; the assertions add no contract value.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Remove standards-guard `existsSync` negatives for deleted file paths

**Files:**
- Modify: `tests/integration/standards-guard.test.ts`

The nine path variables declared at the top of the file are only used in the nine `existsSync(...).toBe(false)` assertions. Remove both the declarations and the assertions together.

- [ ] **Step 1: Remove the nine path variable declarations (lines 10–14, 21–25)**

Remove these declarations from the top of `tests/integration/standards-guard.test.ts`:

```ts
const rebuildPullScriptPath = path.join(repoRoot, "core/scripts/nixpi-rebuild-pull.sh");
const rebuildPullPackagePath = path.join(repoRoot, "core/os/pkgs/nixpi-rebuild-pull/default.nix");
const reinstallOvhScriptPath = path.join(repoRoot, "core/scripts/nixpi-reinstall-ovh.sh");
const reinstallOvhPackagePath = path.join(repoRoot, "core/os/pkgs/nixpi-reinstall-ovh/default.nix");
const ovhBaseHostPath = path.join(repoRoot, "core/os/hosts/ovh-base.nix");
```
```ts
const ovhVpsHostPath = path.join(repoRoot, "core/os/hosts/ovh-vps.nix");
const ovhBaseConfigTestPath = path.join(repoRoot, "tests/integration/ovh-base-config.test.ts");
```
```ts
const ovhVpsConfigTestPath = path.join(repoRoot, "tests/integration/ovh-vps-config.test.ts");
const reinstallOvhTestPath = path.join(repoRoot, "tests/integration/nixpi-reinstall-ovh.test.ts");
```

- [ ] **Step 2: Remove the nine `existsSync(...).toBe(false)` assertions**

Inside `"keeps only the host-owned bootstrap lane wired into the repo"`, remove:

```ts
expect(existsSync(rebuildPullScriptPath)).toBe(false);
expect(existsSync(rebuildPullPackagePath)).toBe(false);
expect(existsSync(reinstallOvhScriptPath)).toBe(false);
expect(existsSync(reinstallOvhPackagePath)).toBe(false);
expect(existsSync(ovhBaseHostPath)).toBe(false);
expect(existsSync(ovhVpsHostPath)).toBe(false);
expect(existsSync(reinstallOvhTestPath)).toBe(false);
expect(existsSync(ovhVpsConfigTestPath)).toBe(false);
expect(existsSync(ovhBaseConfigTestPath)).toBe(false);
```

- [ ] **Step 3: Run static checks (catches unused variable errors)**

```bash
npm run check
```

Expected: `No fixes applied.` Biome will error if any removed variable is still referenced.

- [ ] **Step 4: Run the guard test**

```bash
npx vitest run tests/integration/standards-guard.test.ts
```

Expected: `1 passed (31 tests)`.

- [ ] **Step 5: Commit**

```bash
git add tests/integration/standards-guard.test.ts
git commit -m "$(cat <<'EOF'
Remove existsSync negatives for permanently deleted file paths

These assertions checked that files removed in prior migrations do not
exist. The files are gone and have no Nix wiring to return; the checks
add no contract value. Remove the assertions and their path variables.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Final verification

**Files:**
- Verify: all changed files above

- [ ] **Step 1: Run the full Vitest suite**

```bash
npm test
```

Expected: all test files pass. Count should be ≥ 22 files, ≥ 399 tests. If a test count drops significantly below that, investigate before continuing.

- [ ] **Step 2: Run static checks**

```bash
npm run check
```

Expected: `No fixes applied.`

- [ ] **Step 3: Verify flake still evaluates**

```bash
nix eval .#nixosConfigurations.ovh-vps-base.config.networking.hostName --json && \
nix eval .#nixosConfigurations.vps.config.networking.hostName --json
```

Expected:
```
"ovh-vps-base"
"nixos"
```

- [ ] **Step 4: Push to origin**

```bash
git push origin main
```

---

## Self-Review

### Spec coverage

- **A (dead core/ stubs)**: covered by Task 1.
- **B (stale doc references)**: covered by Task 2, including a guard-first step.
- **C (NixOS VM fail assertions)**: covered by Task 3 with exact line context for all 5 files.
- **D (existsSync negatives + path vars)**: covered by Task 4.
- **Retain list**: No task removes `legacyBootstrapTerms`, `absent` arrays, `flake.not.toContain` assertions, or security/architecture `fail` assertions. These are explicitly left untouched.

No spec gaps found.

### Placeholder scan

No TBD, TODO, "similar to Task N", or incomplete code blocks remain.

### Type consistency

No new types or functions introduced. All file paths referenced are literal strings matching the actual repo layout confirmed via `find core/ -type f`.
