# Hunter Validation Matrix

This document is the release-readiness baseline for Hunter support in `TrueShot`.

Its purpose is simple:

- make the current Hunter promise explicit
- separate static confidence from live combat proof
- give each Hunter profile a repeatable checklist before `1.0`

**Last source review: 2026-04-18** against the primary sources listed in each spec's rotation reference. Patch: 12.0.4 (Midnight Season 1). Primary author: Azortharion (Icy Veins).

**Last client smoke:** 2026-04-23 on WoW `12.0.5.67114`, Interface `120005`.

Use this together with:

- [Project Goals](PROJECT_GOALS.md)
- [API Constraints](API_CONSTRAINTS.md)
- [Signal Validation](SIGNAL_VALIDATION.md)
- [BM Rotation Reference](BM_ROTATION_REFERENCE.md)
- [MM Rotation Reference](MM_ROTATION_REFERENCE.md)
- [SV Rotation Reference](SV_ROTATION_REFERENCE.md)

## Readiness Model

Each Hunter profile should be judged on two axes:

1. **Static readiness**
   - code path is reviewed
   - rule logic matches the intended legal signal model
   - known unsafe API use is removed
   - profile-specific conditions / custom rules / import paths are structurally sound
2. **Live readiness**
   - profile loads in the client without Lua/runtime issues
   - key override cases trigger in real combat
   - fallback to Blizzard Assisted Combat remains sane when signals disappear or become uncertain

`1.0` should require both.

## Current Overall Status

Hunter is the primary shipping target and the quality bar for the addon.

Current honest status:

- **Strict Hunter baseline:** load-smoke and combat-smoke passed for all six Hunter hero paths
- **Experimental Hunter heuristics:** strong but not release-baseline
- **Live Hunter proof for 1.0:** strict AC-primary smoke gates passed; longer dungeon/delve and experimental checks still pending

That means Hunter is currently the only class family that should be treated as productized support, but it is not yet fully proven to a `1.0` standard until the strict-mode and pending live checks are closed.

## Shared Hunter Baseline

These checks apply to all six Hunter profiles.

| Check | Strict | Experimental | Notes |
| --- | --- | --- | --- |
| No cooldown-sensitive priority logic on raw `C_Spell.IsSpellUsable()` | PASS | REVIEW | Strict mode must not use usability as a primary recommendation gate. Experimental behavior remains signal-gated. |
| Shared engine conditions follow documented API constraints | IN PROGRESS | REVIEW | `ac_suggested` is strict-safe. `spell_charges`, `target_count`, `target_casting`, `resource`, `cd_ready`, and `cd_remaining` are experimental unless validated. |
| Shipped Hunter override rules use explicit experimental types | PASS | PASS | All six Hunter profiles use `EXPERIMENTAL_PIN` / `EXPERIMENTAL_PREFER`; a unit test blocks regression to legacy `PIN` / `PREFER`. |
| Condition registry / custom profile schema isolation | PASS | PASS | Duplicate condition IDs across profiles no longer overwrite each other. |
| Import / export hardening for custom profile data | PASS | PASS | Invalid Base64 and schema conflicts are now rejected more cleanly. |
| Per-tick engine caches are robust under repeated combat evaluation | PASS | PASS | Float-time equality path was replaced by explicit compute-tick invalidation. |
| Live load-smoke on current patch | PASS | N/A | All six Hunter hero paths passed `/ts smoke` on `12.0.5.67114` with strict source `ac` and `reasonCode=AC_PRIMARY`. |
| Live combat-smoke on current patch | PASS | N/A | All six Hunter hero paths passed `/ts combat-smoke` on `12.0.5.67114` with `combat=true`, strict source `ac`, and `reasonCode=AC_PRIMARY`. |

## Profile Matrix

### Beast Mastery

| Profile | Strict Baseline | Experimental Heuristics | Live | Notes |
| --- | --- | --- | --- | --- |
| `Hunter.BM.DarkRanger` | PASS | PASS | LOAD PASS / COMBAT PASS | Strict load/combat smoke passed with AC source. Current live Withering Fire / Black Arrow logic must remain hint or signal-gated override. |
| `Hunter.BM.PackLeader` | PASS | PASS | LOAD PASS / COMBAT PASS | Strict load/combat smoke passed with AC source. Hybrid scoring and local BW/Stampede timing are useful but experimental under strict mode. |

### Marksmanship

| Profile | Strict Baseline | Experimental Heuristics | Live | Notes |
| --- | --- | --- | --- | --- |
| `Hunter.MM.DarkRanger` | PASS | PASS | LOAD PASS / COMBAT PASS | Strict load/combat smoke passed with AC source. Trueshot / Black Arrow timing should be strict-mode checklist first, live override only after validation. |
| `Hunter.MM.Sentinel` | PASS | REVIEW | LOAD PASS / COMBAT PASS | Strict load/combat smoke passed with AC source. Direct Trueshot aura read is not allowed to drive strict behavior. |

### Survival

| Profile | Strict Baseline | Experimental Heuristics | Live | Notes |
| --- | --- | --- | --- | --- |
| `Hunter.SV.PackLeader` | PASS | PASS | LOAD PASS / COMBAT PASS | Strict load/combat smoke passed with AC source. Takedown/Boomstick/WFB logic must be signal-gated outside strict baseline. |
| `Hunter.SV.Sentinel` | PASS | PASS | LOAD PASS / COMBAT PASS | Strict load/combat smoke passed with AC source. WFB charge path is experimental unless charge signal is validated for strict use. |

## Blocking Live Checks For `1.0`

These are the minimum live checks still needed before Hunter can honestly be called `1.0`-ready. Strict baseline checks must pass first; experimental override checks only block release if the experimental lane is advertised or enabled by default.

### All Hunter Profiles

- Profile loads cleanly on login, `/reload`, and spec/profile switches
- No stuck icon / stale override / disappearing queue regression in routine combat
- If a profile-specific heuristic becomes uncertain, the queue falls back cleanly to Blizzard Assisted Combat

### BM Dark Ranger

- Strict: profile loads and displays AC recommendations without local Withering Fire reprioritization.
- Experimental: `Black Arrow` pins during the expected `Withering Fire` window.
- Experimental: `Wailing Arrow` sequencing behaves as intended near the tail of the burst window.

### BM Pack Leader

- Strict: profile loads and displays AC recommendations without hybrid scoring.
- Experimental: `Nature's Ally` / `Kill Command` weaving still behaves correctly in combat.
- Experimental: `Bestial Wrath` timing and debug output align with the shipped profile behavior.
- Experimental: first `Kill Command` after `Bestial Wrath` is surfaced as `reason = "Stampede"` in the queue; `stampedeAvailable` clears on that KC and re-arms on the next `Bestial Wrath` cast.

### MM Dark Ranger

- Strict: profile loads and displays AC recommendations without Trueshot/Black Arrow local timer reprioritization.
- Experimental: `Trueshot` opener sequencing is correct in live combat.
- Experimental: `Black Arrow` priority behavior during burst windows matches expectation.

### MM Sentinel

- Strict: profile loads and displays AC recommendations without aura-based Trueshot reprioritization.
- Experimental: `Trueshot` / `Volley` anti-overlap logic is correct in live play.
- Experimental: `Moonlight Chakram` filler timing does not stick or pre-empt stronger actions.

### SV Pack Leader

- Strict: profile loads and displays AC recommendations without Takedown/Boomstick timer reprioritization.
- Experimental: `Stampede` / `Kill Command` sequencing behaves correctly after the blacklist fix.
- Experimental: `Flamefang` timing still adds value without wrong priority spikes.

### SV Sentinel

- Strict: profile loads and displays AC recommendations without Wildfire Bomb charge-cap reprioritization.
- Experimental: `Wildfire Bomb` charge-cap spend behaves correctly in practice.
- Experimental: `Moonlight Chakram` / `Flamefang` timing behaves correctly.

## Non-Hunter Isolation

Non-Hunter profiles (Demon Hunter, Druid, Mage - foundation/alpha) ship in the same addon and register themselves alongside Hunter profiles, but they cannot affect Hunter loading or runtime. The isolation is mechanical, not advisory:

1. `Engine:RegisterProfile(profile)` stores each profile under its own `specID` in `TrueShot.Profiles[specID]`.
2. `Engine:ActivateProfile(specID)` only considers `TrueShot.Profiles[specID]` for the current spec.
3. A Hunter on `253/254/255` therefore never sees Havoc (`577`), Feral (`103`), Fire (`63`), etc. as activation candidates.

Profile files contain no top-level API calls beyond registration, so a non-Hunter profile failing cannot break the load chain for Hunter profiles. `luac -p` is run on every profile in `Profiles/` as a static syntax gate before release.

If a non-Hunter profile ever needs to be shipped-but-disabled for a Hunter-only release, the surgical path is to remove its line from `TrueShot.toc` - not to edit the profile file.

## Release Rule

Until the pending live checks above are closed, the honest release posture is:

- Hunter is the primary, productized support lane
- Hunter is also the only class family being pushed toward `1.0`
- but `TrueShot` should still avoid claiming fully proven `1.0` Hunter support yet
