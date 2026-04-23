# Midnight Compliance Audit

Stand: 2026-04-23

## Executive Summary

TrueShot already has the right high-level shape for Midnight: it is built around Blizzard Assisted Combat, a shared engine, profile modules, presentation UI, tests, and documented API constraints.

The current implementation is not yet safe enough to position as a faultless Midnight-compliant Hunter replacement for Hekili. The risky part is not the UI or profile organization. The risky part is live reprioritization from local combat heuristics.

Recommended path:

- Keep the current codebase.
- Do not rewrite from scratch.
- Introduce a strict compliance mode where TrueShot acts as an Assisted Combat presentation/training layer.
- Move current live override heuristics behind explicit signal validation and experimental gates.

## Product Boundary

Allowed baseline:

- Present Blizzard Assisted Combat output.
- Render keybinds, icons, reason labels, phase labels, profile names, and educational hints.
- Show manually selected Hunter priority cards, opener cards, and burst checklists.
- Use static versioned Hunter profile data.
- Degrade visibly when required signals are unavailable or restricted.

Not allowed as baseline:

- Optimal next-GCD solving from buffs, debuffs, resources, cooldowns, charges, target state, pet state, target count, or local reconstruction.
- Hidden cooldown simulation that materially changes the primary action recommendation.
- Marketing claims that TrueShot is an optimal Hekili/APL replacement under Midnight.

## Current Risk Inventory

### Engine.lua

Risky reads and decisions:

- `UnitPower("player", powerType)` in `resource` conditions.
- `UnitCastingInfo("target")` and `UnitChannelInfo("target")` in `target_casting`.
- Nameplate enumeration and `UnitCanAttack` in `target_count`.
- `C_Spell.GetSpellCharges` in `spell_charges` and `IsSpellCastable`.
- `C_Spell.GetSpellCooldown` in `IsSpellCastable`.
- `C_Spell.IsSpellUsable` as a castability gate.
- Hybrid candidate scoring that chooses position 1 from AC plus profile spell lists.

Compliance impact:

- These paths are acceptable for diagnostics or explicitly experimental features only after signal validation.
- They should not drive strict-mode primary recommendations.

### State/CDLedger.lua

Risky behavior:

- Tracks cooldowns from `UNIT_SPELLCAST_SUCCEEDED`.
- Uses `GetSpellBaseCooldown` and local timers to infer readiness.
- Reseeds from `C_Spell.GetSpellCooldown` after login/reload if readable.

Compliance impact:

- This is a local hidden-state simulation. It may be technically resilient, but it is too close to the behavior Blizzard is trying to suppress when used to choose the next combat action.
- In strict mode it should not drive primary action ordering.

### Hunter Profiles

Beast Mastery Dark Ranger:

- Uses local state for `Black Arrow`, `Withering Fire`, `Wailing Arrow`, `Bestial Wrath`, `Wild Thrash`.
- Uses `UnitPower` through the `resource` condition to suppress `Cobra Shot`.
- Uses nameplate `target_count` for AoE hint.

Beast Mastery Pack Leader:

- Uses local timers for `Bestial Wrath`, `Barbed Shot`, `Stampede`, `Wild Thrash`.
- Hybrid scoring chooses a primary action.
- Uses `C_Spell.GetSpellCharges` and low-Focus scoring.

Marksmanship Dark Ranger:

- Uses local timers for `Black Arrow`, `Trueshot`, `Withering Fire`, `Wailing Arrow`, and Volley anti-overlap.
- Uses `CDLedger` to pin `Trueshot`.

Marksmanship Sentinel:

- Reads `C_UnitAuras.GetPlayerAuraBySpellID(288613)` for Trueshot.
- Uses `C_Spell.GetSpellCharges` to evaluate `Aimed Shot`.

Survival Pack Leader:

- Uses local Takedown/Boomstick timers.
- Uses `C_Spell.GetSpellCharges` for Wildfire Bomb cap.

Survival Sentinel:

- Uses local Takedown/Boomstick timers.
- Uses `spell_charges` for Wildfire Bomb cap.

Compliance impact:

- These profiles are valuable as source-cited Hunter knowledge.
- Their live PIN/PREFER behavior should be split into strict presentation hints vs experimental overrides.

### Display.lua

Risky but mostly presentational:

- Reads `C_ActionBar.*Cooldown*`, `C_Spell.GetSpellCooldown*`, `C_Spell.GetSpellCharges`, `C_Spell.IsSpellInRange`.
- Uses DurationObject APIs when available.

Compliance impact:

- Display-only cooldown/range rendering can be acceptable if opaque values are never converted into decision logic.
- Keep this layer isolated from rule decisions.

## Required Refactor

### 1. Add Signal Registry

Each signal gets metadata:

- `id`
- `api`
- `category = public|displayOnly|opaque|unavailable|forbidden`
- `validatedBuild`
- `allowedInStrict`
- `fallback`

Initial strict disallow list:

- `resource`
- `target_casting`
- `target_count`
- `spell_charges`
- `cd_ready`
- `cd_remaining`
- direct profile aura reads
- hybrid scoring

Implementation status:

- `SignalRegistry.lua` now defines the initial engine-signal metadata.
- Strict mode defaults on through `TrueShotDB.strictCompliance`.
- Unknown profile-specific conditions fail closed in strict mode.
- Hybrid scoring is disabled in strict mode.
- Hunter live overrides have been reclassified as `EXPERIMENTAL_PIN` / `EXPERIMENTAL_PREFER`.
- Any remaining non-Hunter `PIN`/`PREFER` rules are disabled in strict mode and remain legacy/experimental until those alpha profiles are reviewed.

### 2. Split Rule Modes

Legacy:

- `PIN`
- `PREFER`
- `BLACKLIST`
- `BLACKLIST_CONDITIONAL`

Current Hunter override model:

- `EXPERIMENTAL_PIN`
- `EXPERIMENTAL_PREFER`
- `BLACKLIST`
- `BLACKLIST_CONDITIONAL`

Target:

- `AC_PRESENTATION`
- `PROFILE_HINT`
- `STATIC_CARD`
- `SUPPRESS_DUPLICATE`
- `SAFE_FALLBACK`
- `EXPERIMENTAL_PIN`
- `EXPERIMENTAL_PREFER`

Strict mode only permits safe presentation types.

### 3. Introduce Reason Codes

Every rendered slot should carry one reason code:

- `AC_PRIMARY`
- `AC_ROTATION`
- `PROFILE_HINT`
- `STATIC_PROFILE_CARD`
- `USER_CONFIG`
- `SAFE_FALLBACK`
- `SIGNAL_DISABLED`
- `EXPERIMENTAL_OVERRIDE`

### 4. Gate Current Overrides

All primary-action changes from legacy `PIN`, legacy `PREFER`, and hybrid scoring need one of:

- Reclassified as `PROFILE_HINT`.
- Reclassified as `EXPERIMENTAL_*` with a required signal gate.
- Removed from strict-mode behavior.

Hunter status: reclassified as `EXPERIMENTAL_*`; strict mode remains AC-primary.

### 5. Update Product Copy

README and project docs should avoid:

- “corrects Assisted Combat”
- “overrides with validated heuristics”
- “Hekili replacement” without qualification
- “perfect rotation”

Preferred:

- “Hunter-focused Assisted Combat overlay/trainer”
- “Midnight-compliant presentation layer”
- “safe-by-design profile hints”
- “experimental signal-gated overrides”

## Release Blocking Checklist

- [x] Strict mode can run without `UnitPower`, `C_UnitAuras`, `C_Spell.GetSpellCooldown`, nameplate enumeration, combat log, or target cast parsing.
- [x] Strict mode does not use `CDLedger` to change position 1.
- [x] Strict mode never chooses position 1 from `rotationalSpells` when AC did not provide that spell.
- [ ] Every direct WoW API read has signal metadata.
- [ ] Every UI output has a reason code.
- [ ] Every experimental override has a visible diagnostics label.
- [ ] README and docs no longer overclaim.

## Decision

Use the current codebase as foundation. Do not start a clean rewrite.

Start with a compliance refactor. The priority is to create a strict, shippable baseline first. Once that baseline is safe, reintroduce individual Hunter overrides only when their signals are validated and review-gated.
