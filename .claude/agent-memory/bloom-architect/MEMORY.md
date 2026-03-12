# Bloom Architect Memory

## Architecture Decisions (Settled)

### Extension directory structure (2026-03-08)
- Every extension is a directory: `extensions/bloom-{name}/index.ts + actions.ts + types.ts`
- Always a directory, even for thin extensions -- consistency for AI-driven development
- `index.ts` is registration only, `actions.ts` handles orchestration, lib/ has pure logic
- 4 extensions MISSING types.ts (post-cleanup 2026-03-12): bloom-objects, bloom-repo, bloom-services, bloom-setup
- Tests live in `tests/` at project root (NOT colocated in extension dirs)

### lib/ actual files (2026-03-11, verified)
- `shared.ts` -- generic utilities (createLogger, nowIso, truncate, errorResult, guardBloom, requireConfirmation)
- `exec.ts` -- command execution (run)
- `repo.ts` -- git remote helpers (getRemoteUrl, inferRepoUrl)
- `audit.ts` -- audit utilities (dayStamp, sanitize, summarizeInput, SENSITIVE_KEY)
- `filesystem.ts` -- path helpers (safePath, getBloomDir)
- `frontmatter.ts` -- YAML frontmatter (parseFrontmatter, stringifyFrontmatter, yaml)
- `git.ts` -- parseGithubSlugFromUrl, slugifyBranchPart
- `services-catalog.ts` -- loadServiceCatalog, loadBridgeCatalog, servicePreflightErrors
- `services-install.ts` -- findLocalServicePackage (pure lookup)
- `services-manifest.ts` -- Manifest types, loadManifest, saveManifest
- `services-validation.ts` -- validateServiceName, validatePinnedImage, commandExists
- `matrix.ts` -- extractResponseText, generatePassword, matrixCredentialsPath
- `setup.ts` -- setup wizard state machine: STEP_ORDER, advanceStep, etc.
- `netbird.ts` -- NetBird API client (DNS zones, records, mesh IP, token loading)
- `service-routing.ts` -- orchestration: ensureServiceRouting (calls netbird.ts)
- lib/services.ts barrel and lib/lemonade.ts were removed during migration

### Service template (2026-03-08)
- `services/_template/` EXISTS with: Containerfile, package.json, src/, tests/, quadlet/, tsconfig, vitest.config
- No shared service library -- independence is the point

### OS-level infrastructure (2026-03-11, post-migration)
- Matrix (Continuwuity) native systemd (bloom-matrix.service)
- NetBird system RPM (netbird.service)
- Nginx reverse proxy (nginx.service)
- NOT in catalog.yaml -- they're OS infrastructure
- Element retired, replaced by Cinny Quadlet container
- Unix socket channel bridge retired, replaced by matrix-bot-sdk in-process

## Architecture State (2026-03-12, post-cleanup audit)
- 11 extensions (9 directory-based, bloom-services has no base actions.ts, 4 missing types.ts)
- Container services: dufs, cinny, code-server
- Bridges: whatsapp, telegram, signal
- OS infra: bloom-matrix, netbird, nginx

## Stale Documentation After Migration (2026-03-11)
- README.md: "Element bot", "Unix socket IPC", "channel-protocol.md" link
- services/README.md: lists element service
- .pi/AGENTS.md: references element, 80% threshold
- bloom-live-tester agent: lemonade, channels.sock refs
- Coverage: README says 80%, actual thresholds are lib/55% extensions/15%

## Known Issues (2026-03-12)
- ServiceCatalogEntry misplaced in lib/services-manifest.ts, should be in services-catalog.ts
- loadBridgeCatalog/loadServiceCatalog are near-identical, should be consolidated
- Module-level mutable `let updateChecked` in bloom-os/actions.ts
- bloom-os/actions.ts eagerly evaluates statusFile at import time
- QUADLET_DIR computed in 4 separate places
- netbird.ts and service-routing.ts missing from ARCHITECTURE.md lib/ listing

## Pi SDK Notes
- `StringEnum`, `Type`, `truncateHead` are VALUE exports -- peerDependency runtime imports correct
