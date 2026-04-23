# Field Validation Plan for 0.27.1

Date: 2026-04-23
Base release: `v0.27.0-alpha.1`

## Goal

Validate the strict AC-primary Hunter baseline outside target-dummy smoke tests.

This plan does not validate experimental overrides as a release promise. Experimental behavior remains research-only unless explicitly enabled and separately reviewed.

## Required Runs

Run with `strictCompliance=true`.

| Scenario | Required Evidence |
| --- | --- |
| 10-minute target dummy session on one Hunter spec | No Lua errors, no taint, overlay remains stable |
| One dungeon or delve pull sequence on any Hunter spec | No Lua errors, no taint, overlay does not disappear or stick |
| Pet missing/dead at pull start on BM or SV | Addon does not error; AC-primary baseline remains intact |
| Target swap during combat | No queue crash or stale local override source |
| `/reload` after recent major cooldown | Addon reloads cleanly and remains strict AC-primary |

## Commands

Before testing:

```text
/console scriptErrors 1
/console taintLog 1
/ts strict on
```

After a representative pull:

```text
/ts combat-smoke
/reload
```

After logout or reload:

```sh
scripts/read_wow_smoke.sh
scripts/release_gate.sh --wow
```

## Pass Criteria

- No TrueShot-specific Lua errors.
- No TrueShot-specific taint entries.
- No `ADDON_ACTION_FORBIDDEN`.
- `/ts combat-smoke` passes.
- Smoke report uses `source=ac`, `reasonCode=AC_PRIMARY`, `strict=true`.
- User does not observe stuck icons, disappearing overlay, or persistent wrong profile.

## 0.27.1 Candidate Fix Areas

- Any artifact-install issue.
- Any strict-mode runtime error.
- Any profile activation mismatch.
- Any packaging/metadata issue reported by GitHub/Curse/Wago.

## Non-Goals

- Proving optimal DPS.
- Advertising Hekili-equivalent next-GCD solving.
- Enabling experimental override mode by default.
