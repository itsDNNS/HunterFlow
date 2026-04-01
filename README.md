# HunterFlow

`HunterFlow` is a World of Warcraft addon for Retail `Midnight` that layers a hunter-focused recommendation UI on top of Blizzard's `Assisted Combat` system.

The addon does not try to recreate old full-state rotation engines. Instead, it uses Blizzard-provided rotation signals plus lightweight cast-event heuristics where that is still legal and reliable.

## Status

`HunterFlow` is currently an `alpha`.

Current implementation focus:

- Beast Mastery Hunter
- Dark Ranger hero talent path

Planned direction:

- broader hunter support over time
- more configurable overlays and profiles
- additional spec-aware heuristics where the available API makes them defensible

## What It Does

- Shows a compact hunter rotation queue on screen
- Uses Blizzard `C_AssistedCombat` as the base recommendation source
- Filters obvious utility noise such as `Call Pet` and `Revive Pet`
- Supports BM / Dark Ranger-specific cast-tracked state for:
  - `Black Arrow`
  - `Bestial Wrath`
  - `Wailing Arrow`
  - `Nature's Ally`-style `Kill Command` weaving
- Can pin `Counter Shot` when the target is casting
- Supports click-through while locked

## Design Constraints

`HunterFlow` is intentionally built around the current Retail API reality:

- primary combat state is heavily restricted in `Midnight`
- cooldown values are not broadly safe to depend on
- `Assisted Combat` remains the most reliable legal baseline

That means this addon aims to be:

- practical
- conservative
- transparent about what is heuristic vs. guaranteed

It does **not** claim to be a full replacement for legacy Hekili-style simulation.

## Commands

- `/hf lock`
- `/hf unlock`
- `/hf burst`
- `/hf hide`
- `/hf show`
- `/hf debug`
- `/hunterflow`

## Installation

1. Copy the `HunterFlow` folder into:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

2. Restart WoW or run `/reload`.
3. Log into a hunter.

## Current Scope Notes

The current alpha is honest but narrow:

- branding is hunter-wide
- the initial shipped profile is BM Hunter / Dark Ranger

If you use another hunter spec today, the addon will stay inactive instead of pretending to support behavior it does not yet model.

## License

Licensed under `GPL-3.0-or-later`. See [LICENSE](LICENSE).
