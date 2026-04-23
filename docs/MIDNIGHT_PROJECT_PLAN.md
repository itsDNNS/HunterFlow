# Midnight Project Plan

Stand: 2026-04-23
Owner: Codex PM

## Decision

Keep the current codebase. Do not rewrite from scratch.

TrueShot already has useful foundations:

- shared `Engine`
- `Display` layer
- profile modules
- Hunter source references
- tests
- Assisted Combat integration

The needed work is a compliance pivot, not a clean-room replacement. The current live override approach must be split into a safe strict baseline and experimental signal-gated behavior.

## Product Line

Strict baseline:

- Assisted Combat presentation layer
- Hunter-focused training and profile hints
- static priority cards
- opener and burst checklists
- keybind and icon presentation
- degraded states when signals are unavailable

Experimental lane:

- existing PIN/PREFER/hybrid overrides
- local cast-event state
- cooldown/charge/nameplate/resource based heuristics
- only enabled after explicit signal validation

Not a baseline promise:

- optimal Hekili/APL-style live next-GCD solving under Midnight
- hidden-state simulation
- combat-log reconstruction
- secret-value workarounds

## Phase 0 - Hygiene

- [x] Clone repo locally.
- [x] Audit architecture and Hunter profile risk.
- [x] Add compliance audit.
- [x] Update README and API/project goal language.
- [x] Establish local Lua runtime or documented CI-only verification.
- [x] Split Hunter Validation Matrix into strict vs experimental.

Exit gate:

- README and docs no longer overclaim.
- Compliance audit is linked from framework docs.
- Test strategy is explicit.

## Phase 1 - Signal Registry

- [x] Add signal metadata for every external API read used by engine-level conditions.
- [x] Categories: `public`, `displayOnly`, `opaque`, `unavailable`, `forbidden`.
- [x] Fields: `id`, `api`, `category`, `validatedBuild`, `allowedInStrict`, `fallback`, `owner`.
- [x] Initial strict disallow list: `resource`, `target_casting`, `target_count`, `spell_charges`, `cd_ready`, `cd_remaining`, direct aura reads, hybrid scoring.
- [ ] Replace `needs-ptr-review` metadata after PTR probing.

Exit gate:

- Every Rule/Engine/Profile signal has a registry entry.
- Unknown signals fail closed.

## Phase 2 - Rule Model

- [x] Split current runtime behavior so strict mode disables legacy `PIN`/`PREFER` and hybrid override selection.
- [x] Split Hunter `PIN`/`PREFER` data model into strict-safe presentation and experimental override semantics.
- [x] Add strict-safe rule types: `LABEL`, `HINT`, `SUPPRESS_DUPLICATE`, `PROFILE_CARD`, `FALLBACK`.
- [x] Add experimental types: `EXPERIMENTAL_PIN`, `EXPERIMENTAL_PREFER`.
- [x] Add `reasonCode` to queue metadata for AC vs experimental output.

Exit gate:

- Strict mode does not choose position 1 from local timers, charges, resources, nameplates, auras, target casts, or cooldown ledgers.
- Legacy override mode is clearly marked experimental.

## Phase 3 - Hunter Strict Packs

- [x] Enforce global strict-mode AC passthrough for all Hunter profiles.
- [x] BM Dark Ranger: move Black Arrow/Withering Fire/Wailing Arrow timing into hints or experimental gates.
- [x] BM Pack Leader: disable hybrid scoring in strict mode; remove low-Focus and charge scoring from strict behavior.
- [x] MM Dark Ranger: Trueshot/Volley/Black Arrow as burst checklist, not live timer solver.
- [x] MM Sentinel: remove direct aura read from strict behavior.
- [x] SV Pack Leader/Sentinel: Takedown/Boomstick/WFB charge rules become experimental unless validated.

Exit gate:

- BM, MM, SV all have strict-mode views that render without live combat reprioritization.

## Phase 4 - QA

- [x] Install local Lua 5.4 runtime and add a repo-local test runner.
- [x] Add tests proving strict mode renders without `UnitPower`, `C_UnitAuras`, `C_Spell.GetSpellCooldown`, nameplates, combat log, or target cast parsing.
- [x] Add forbidden API scan to CI.
- [x] Add forced restriction CVar PTR smoke plan.
- [x] Document Hunter PTR matrix.
- [x] Add WoW install/link script for local client validation.
- [x] Add in-client `/ts smoke` command with SavedVariables report.
- [x] Add smoke-report reader for post-login verification.

Local test command:

```sh
scripts/run_tests.sh
```

Local WoW client commands:

```sh
scripts/install_wow_addon.sh
scripts/wow_static_check.sh
scripts/read_wow_smoke.sh
```

Exit gate:

- Lua tests pass.
- `git diff --check` passes.
- PTR smoke has no Lua, taint, or protected-action errors.

## Release Gates

API gate:

- No strict-mode rule decisions from unsafe or unvalidated APIs.

Solver gate:

- No strict-mode best-next-action solver from live combat data.

Secret gate:

- No arithmetic, comparison, sorting, thresholding, or persistence on potential secrets.

Taint gate:

- No protected frame attributes, macro/binding changes, anchors, or combat show/hide logic.

Product gate:

- No claim that TrueShot is an optimal legacy Hekili replacement under Midnight.

## Current Completion Boundary

Local implementation gates are complete for the strict-mode foundation:

- strict mode defaults on
- legacy live overrides are disabled in strict mode
- experimental mode is explicit
- signal metadata exists for engine-level runtime signals
- local tests, syntax, and compliance scan pass

Remaining release gate:

- PTR/live-client validation from [PTR Smoke Matrix](PTR_SMOKE_MATRIX.md)
