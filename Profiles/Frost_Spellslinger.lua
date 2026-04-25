-- TrueShot Profile: Frost / Spellslinger (Spec 64)
-- Fallback profile -- not meta, minimal rules

local Engine = TrueShot.Engine

local SPELLS = {
    GlacialSpike  = 199786,
    Flurry        = 44614,
    IceLance      = 30455,
    FrozenOrb     = 84714,
    Frostbolt     = 116,
    Blizzard      = 190356,
    IceNova       = 157997,
    RayOfFrost    = 205021,
    CometStorm    = 153595,
    IcyVeins      = 12472,
    Polymorph     = 118,
    Spellsteal    = 30449,
    ArcaneInt     = 1459,
}

local Profile = {
    id = "Mage.Frost.Spellslinger",
    displayName = "Frost Spellslinger",
    specID = 64,
    -- Hero-tree detection: Spellslinger's signature talents are all passives
    -- or proc auras that never land in the player spellbook, so the legacy
    -- IsPlayerSpell(markerSpell) pattern cannot identify this hero tree.
    -- Use Blizzard's hero-talent SubTree API instead via
    -- C_ClassTalents.GetActiveHeroTalentSpec(). SubTreeID 40 identifies
    -- Spellslinger for both Arcane and Frost Mage (sourced from Blizzard's
    -- TraitSubTree DB2). Reported as issue #88.
    --
    -- Inverted from Fire/Arcane pattern: Frostfire is the unmarked fallback
    -- because it covers the bulk of top parses. This marker ensures
    -- Spellslinger only activates for players who actually pick the tree.
    heroTalentSubTreeID = 40,
    version = 1,

    state = {},

    rotationalSpells = {
        [SPELLS.GlacialSpike] = true,
        [SPELLS.Flurry]       = true,
        [SPELLS.IceLance]     = true,
        [SPELLS.FrozenOrb]    = true,
        [SPELLS.Frostbolt]    = true,
        [SPELLS.Blizzard]     = true,
        [SPELLS.IceNova]      = true,
        [SPELLS.RayOfFrost]   = true,
        [SPELLS.CometStorm]   = true,
        [SPELLS.IcyVeins]     = true,
    },

    rules = {
        { type = "BLACKLIST", spellID = SPELLS.Polymorph },
        { type = "BLACKLIST", spellID = SPELLS.Spellsteal },
        { type = "BLACKLIST", spellID = SPELLS.ArcaneInt },

        -- Glacial Spike: prefer the proc when the client exposes the glow.
        {
            type = "PREFER",
            spellID = SPELLS.GlacialSpike,
            reason = "Glacial Spike",
            condition = { type = "spell_glowing", spellID = SPELLS.GlacialSpike },
        },

        -- Brain Freeze: PREFER Flurry when proc is active (glow detection)
        {
            type = "PREFER",
            spellID = SPELLS.Flurry,
            reason = "Brain Freeze",
            condition = { type = "spell_glowing", spellID = SPELLS.Flurry },
        },
    },
}

function Profile:ResetState() end
function Profile:OnSpellCast(_spellID) end
function Profile:OnCombatEnd() end
function Profile:EvalCondition(_cond) return nil end
function Profile:GetDebugLines() return { "  (Spellslinger: AC-reliant)" } end

function Profile:GetPhase()
    return nil
end

Engine:RegisterProfile(Profile)

if TrueShot.CustomProfile then
    TrueShot.CustomProfile.RegisterConditionSchema("Mage.Frost.Spellslinger", {
    })
end
