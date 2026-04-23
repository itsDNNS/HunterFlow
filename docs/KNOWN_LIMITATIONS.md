# Known Limitations

Stand: 2026-04-23

## Midnight Baseline

TrueShot is not an optimal Hekili/APL-style live solver under Midnight.

The strict baseline is:

- Assisted Combat presentation.
- Hunter-focused labels and training context.
- Keybind and icon overlay.
- Static profile guidance.
- Safe fallback behavior.

## Strict Mode

Strict mode is enabled by default.

In strict mode, TrueShot does not use these signals to choose the primary recommendation:

- player resources such as Focus
- aura scans
- target casts
- target count/nameplates
- spell charge reads
- spell cooldown reads
- local cooldown ledgers
- profile-local timer state
- hybrid profile scoring

## Experimental Mode

`/ts strict off` enables experimental override behavior.

Experimental mode may use existing profile heuristics such as cast-event timers, charge checks, local cooldown models, and profile-specific priority windows. These features are for validation and are not the default product promise.

Return to baseline with:

```text
/ts strict on
```

## Hunter Scope

Hunter is the primary product lane.

BM, MM, and SV are all included, but strict-mode support should be understood as Assisted Combat presentation plus profile guidance until PTR checks close the live-client gate.

## External Gate

The remaining hard release gate is live-client verification on Midnight 12.x:

- no Lua errors
- no taint/protected action errors
- stable Assisted Combat availability
- strict-mode behavior under forced secret restrictions

Local tests cannot prove Blizzard runtime behavior.
