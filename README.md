<p align="center">
  <img src="icon.svg" width="128" height="128" alt="TrueShot Logo">
</p>

# TrueShot

A World of Warcraft addon for Retail Midnight that corrects known blind spots in Blizzard's Assisted Combat system.

Blizzard's built-in rotation helper gets you started, but it has gaps: wrong AoE priorities, missing shatter combos, stuck cooldown suggestions, and more. TrueShot identifies these cases and overrides them with cast-event-tracked heuristics, validated against WarcraftLogs data from top-performing players.

## Supported Classes

### Hunter (Primary)

TrueShot is built for Hunters. All three specs are fully validated in-game with WCL-backed rotation analysis and detailed cast-event state machines.

| Spec | Hero Path | Key Overrides |
|------|-----------|---------------|
| **Beast Mastery** | Dark Ranger | Black Arrow during Withering Fire, Wailing Arrow sequencing, AoE hint for Wild Thrash |
| **Beast Mastery** | Pack Leader | Nature's Ally KC weaving, Wild Thrash AoE hint, Bestial Wrath timing |
| **Marksmanship** | Dark Ranger | Trueshot opener sequence, Volley/Trueshot anti-overlap, Withering Fire BA priority |
| **Marksmanship** | Sentinel | Post-Rapid Fire Trueshot gating, Volley anti-overlap, Moonlight Chakram filler timing |
| **Survival** | Pack Leader | Stampede KC sequencing, Boomstick CD tracking, Takedown burst window, Hatchet Toss melee gating |
| **Survival** | Sentinel | WFB charge management, Boomstick CD tracking, Moonlight Chakram timing, Hatchet Toss melee gating |

### Demon Hunter, Druid, Mage (Alpha)

These classes have profile support with burst window tracking and hero path auto-detection. However, we don't play these classes ourselves and rely on community feedback for validation.

**If you play one of these classes and notice something off or want to suggest changes, please [open an issue](https://github.com/itsDNNS/TrueShot/issues).**

| Class | Specs | Profiles | Notes |
|-------|-------|----------|-------|
| **Demon Hunter** | Havoc, Devourer | 4 | Metamorphosis burst tracking. Devourer is heavily AC-reliant. |
| **Druid** | Feral, Balance | 4 | Tiger's Fury/Berserk and Celestial Alignment burst tracking. Resource-dependent (Energy, Astral Power) limits overrides. |
| **Mage** | Fire, Frost, Arcane | 6 | Combustion, Frozen Orb, Arcane Surge burst windows. Frost shatter combo (Flurry > Ice Lance). |

All 20 profiles across 4 classes support automatic hero path detection via `IsPlayerSpell` markers.

## How It Works

TrueShot is not a full rotation engine. It's an overlay:

1. **Blizzard Assisted Combat** provides the base recommendation via `C_AssistedCombat.GetNextCastSpell()`
2. **TrueShot PIN rules** override position 1 when a specific condition is met (e.g. "Black Arrow during Withering Fire")
3. **TrueShot PREFER rules** elevate a spell to position 1 as a softer suggestion
4. **Remaining positions** are filled from `C_AssistedCombat.GetRotationSpells()`

State tracking is purely event-driven via `UNIT_SPELLCAST_SUCCEEDED`. No buff reading, no resource tracking, no hidden state simulation.

## Display Features

- Compact queue overlay with configurable icon count and position
- **AoE hint icon** with bounce animation for AoE abilities (e.g. Wild Thrash)
- **Queue stabilization** prevents icon flicker from AC instability
- **Masque support** for icon skinning (optional, zero-dependency)
- **First-icon scale** (1.0x - 2.0x) for visual hierarchy
- **Queue orientation** (LEFT / RIGHT / UP / DOWN)
- **Override glow** with pulsing animation (cyan for PIN, blue for PREFER)
- **Charge cooldown** edge ring for multi-charge spells
- **Keybind display** with macro and ElvUI action bar support
- Cast success feedback, range indicator, cooldown swipes
- Optional backdrop toggle for clean floating-icons look
- Settings panel via `/ts options` with X/Y position controls
- Tiered update rates (10Hz combat, 2Hz idle, 0Hz hidden)

## Installation

1. Copy the `TrueShot` folder into:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

2. Restart WoW or `/reload`.
3. Log into a supported class (Hunter, Demon Hunter, Druid, or Mage).

## Commands

| Command | Description |
|---------|-------------|
| `/ts options` | Open settings panel |
| `/ts lock` / `unlock` | Lock/unlock overlay position |
| `/ts burst` | Toggle burst mode |
| `/ts hide` / `show` | Toggle visibility |
| `/ts debug` | Show profile state |
| `/ts diagnostics on\|off` | Enable signal probes |
| `/ts probe ...` | Run signal probes (requires diagnostics) |

## Design Philosophy

TrueShot is built around the Midnight API reality:

- Primary combat state (buffs, resources, exact cooldowns) is restricted via secret values
- Assisted Combat remains the most reliable legal baseline
- Cast events (`UNIT_SPELLCAST_SUCCEEDED`) and spell charges (`C_Spell.GetSpellCharges`) are the primary non-secret signals

The addon is:
- **Conservative**: only overrides AC where it's demonstrably wrong
- **Transparent**: shows why it overrode AC (reason labels, phase indicators)
- **Fail-safe**: degrades gracefully to pure AC passthrough if signals are unavailable

## Framework Docs

- [Project Goals](docs/PROJECT_GOALS.md)
- [API Constraints](docs/API_CONSTRAINTS.md)
- [Framework Model](docs/FRAMEWORK.md)
- [Profile Contract](docs/PROFILE_CONTRACT.md)
- [Profile Authoring Guide](docs/PROFILE_AUTHORING.md)
- [Signal Validation](docs/SIGNAL_VALIDATION.md)

## License

Licensed under `GPL-3.0-or-later`. See [LICENSE](LICENSE).
