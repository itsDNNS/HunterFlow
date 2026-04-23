# PTR Smoke Matrix

Stand: 2026-04-23

## Purpose

This matrix is the live-client gate for Midnight compliance. Local Lua tests prove deterministic logic. PTR/live testing proves that Blizzard's runtime restrictions, taint behavior, Assisted Combat APIs, and secret-value behavior do not break the addon.

## Setup

- Retail/PTR client: Midnight 12.x.
- Addons: TrueShot only for baseline pass.
- Optional second pass: TrueShot + common bar addon + Masque.
- Enable Lua errors.
- Developer install from this checkout:

```sh
scripts/install_wow_addon.sh
scripts/wow_static_check.sh
```

- Enable taint logging:

```text
/console taintLog 1
/reload
```

Forced restriction CVars to test where available:

```text
/console secretCombatRestrictionsForced 1
/console secretEncounterRestrictionsForced 1
/console secretChallengeModeRestrictionsForced 1
/console secretPvPMatchRestrictionsForced 1
/console secretMapRestrictionsForced 1
/reload
```

## Global Pass Criteria

- No Lua errors.
- No `ADDON_ACTION_FORBIDDEN`.
- No TrueShot-caused taint entries.
- Strict mode remains enabled by default.
- `/ts strict` reports `ON`.
- `/ts smoke` passes out of combat for every Hunter spec/hero path.
- `/ts combat-smoke` passes while in combat for every Hunter spec/hero path.
- `/ts strict off` visibly enters experimental mode and can be returned to strict with `/ts strict on`.
- If Assisted Combat is unavailable, TrueShot disables or degrades instead of inventing recommendations.

## Hunter Matrix

Run each row on target dummies and one dungeon/delve pull where possible.

| Spec | Hero | Strict Checks | Experimental Checks |
| --- | --- | --- | --- |
| BM | Dark Ranger | AC primary remains stable; no local Black Arrow/Withering Fire reprioritization in strict mode. | Black Arrow/Wailing Arrow windows only when `/ts strict off`. |
| BM | Pack Leader | AC primary remains stable; hybrid scoring disabled in strict mode. | Bestial Wrath/Stampede/Kill Command sequencing only when `/ts strict off`. |
| MM | Dark Ranger | AC primary remains stable; Trueshot/Volley/Black Arrow local timers do not replace slot 1. | Trueshot opener and Black Arrow sequence only when `/ts strict off`. |
| MM | Sentinel | AC primary remains stable; Trueshot aura read does not drive strict slot 1. | Moonlight Chakram/Trueshot timing only when `/ts strict off`. |
| SV | Pack Leader | AC primary remains stable; Takedown/Boomstick timers do not replace slot 1. | Stampede/Boomstick/Flamefang timing only when `/ts strict off`. |
| SV | Sentinel | AC primary remains stable; Wildfire Bomb charge cap does not replace slot 1. | WFB/Chakram/Flamefang timing only when `/ts strict off`. |

## Required Scenarios

- Login on each Hunter spec.
- Run `/ts smoke`, then `/reload` or logout so `TrueShotDB.smokeReport` is written.
- Enter combat on a target dummy, run `/ts combat-smoke`, then `/reload` or logout.
- `/reload` while out of combat.
- `/reload` after recently using a major cooldown.
- Switch hero trees out of combat.
- Enter combat on target dummy for 5 minutes.
- Target swap during combat.
- Pet dead/missing at pull start.
- Assisted Combat disabled/unavailable.
- `/ts strict off`, confirm experimental behavior, then `/ts strict on`, confirm AC-only primary behavior.

## Evidence To Capture

- `scripts/read_wow_smoke.sh` output after each spec/hero pass.
- `scripts/release_gate.sh --wow` output after the complete load/combat smoke set.
- Optional live wait: run `scripts/watch_wow_smoke.sh` before logging in, then run `/ts smoke` and `/reload` in game.
- Combat evidence must include `mode=combat` and `combat=true` in `scripts/read_wow_smoke.sh`.
- Screenshot or log excerpt showing `/ts debug` in strict mode.
- Any Lua error stack.
- Taint log excerpt if non-empty.
- WoW build number.
- TrueShot version/commit.
- Spec/hero path.
- Whether forced restriction CVars were active.

## Release Rule

Stable release requires all strict checks to pass for BM, MM, and SV.

Experimental checks do not block strict release unless experimental mode is advertised, enabled by default, or included in release claims.

## Current Evidence

2026-04-23 on WoW `12.0.5.67114`, Interface `120005`:

- `/ts smoke` passed for all six Hunter hero paths.
- `/ts combat-smoke` passed for all six Hunter hero paths while `UnitAffectingCombat("player")` reported combat.
- Every strict run used `source=ac`, `reasonCode=AC_PRIMARY`, `strict=true`, `acAvailable=true`, and `queue=2`.
- `scripts/release_gate.sh --wow` passed against the saved smoke history.
- Log scan under `_retail_/Logs` found no TrueShot-specific Lua, taint, `ADDON_ACTION_FORBIDDEN`, blocked, or forbidden errors.
