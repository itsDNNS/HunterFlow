-- TrueShot Profile: Frost / Frostfire (Spec 64)
-- Shatter combo enforcement + Frozen Orb burst tracking

local Engine = TrueShot.Engine

local FROZEN_ORB_DURATION = 10

local SPELLS = {
    GlacialSpike  = 199786,
    Flurry        = 44614,
    IceLance      = 30455,
    Blizzard      = 190356,
    FrozenOrb     = 84714,
    Frostbolt     = 116,
    IceNova       = 157997,
    RayOfFrost    = 205021,
    CometStorm    = 153595,
    IcyVeins      = 12472,
    Polymorph     = 118,
    Spellsteal    = 30449,
    ArcaneInt     = 1459,
}

local Profile = {
    id = "Mage.Frost.Frostfire",
    displayName = "Frost Frostfire",
    specID = 64,
    heroTalentSubTreeID = 41,
    -- No markerSpell: fallback when Spellslinger's subtree is unavailable
    version = 1,

    state = {
        frozenOrbActiveUntil = 0,
        lastCastWasFlurry = false,
    },

    rotationalSpells = {
        [SPELLS.GlacialSpike] = true,
        [SPELLS.Flurry]       = true,
        [SPELLS.IceLance]     = true,
        [SPELLS.Blizzard]     = true,
        [SPELLS.FrozenOrb]    = true,
        [SPELLS.Frostbolt]    = true,
        [SPELLS.IceNova]      = true,
        [SPELLS.RayOfFrost]   = true,
        [SPELLS.CometStorm]   = true,
        [SPELLS.IcyVeins]     = true,
    },

    rules = {
        { type = "BLACKLIST", spellID = SPELLS.Polymorph },
        { type = "BLACKLIST", spellID = SPELLS.Spellsteal },
        { type = "BLACKLIST", spellID = SPELLS.ArcaneInt },

        -- Glacial Spike: when the client exposes the proc glow, prefer it
        -- without trying to read hidden Icicle stack state.
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

        -- Shatter combo: Ice Lance after Flurry (WCL: 66% natural, boost remaining 34%)
        {
            type = "PREFER",
            spellID = SPELLS.IceLance,
            reason = "Shatter",
            condition = { type = "last_cast_was_flurry" },
        },

        -- Blizzard: AoE preference when 3+ targets
        {
            type = "PREFER",
            spellID = SPELLS.Blizzard,
            reason = "AoE 3+",
            condition = { type = "target_count", op = ">=", value = 3 },
        },
    },
}

function Profile:ResetState()
    self.state.frozenOrbActiveUntil = 0
    self.state.lastCastWasFlurry = false
end

function Profile:OnSpellCast(spellID)
    local s = self.state

    if spellID == SPELLS.FrozenOrb then
        s.frozenOrbActiveUntil = GetTime() + FROZEN_ORB_DURATION
    end

    s.lastCastWasFlurry = (spellID == SPELLS.Flurry)
end

function Profile:OnCombatEnd()
    self.state.frozenOrbActiveUntil = 0
    self.state.lastCastWasFlurry = false
end

function Profile:EvalCondition(cond)
    if cond.type == "frozen_orb_active" then
        return GetTime() < self.state.frozenOrbActiveUntil
    elseif cond.type == "last_cast_was_flurry" then
        return self.state.lastCastWasFlurry
    end
    return nil
end

function Profile:GetDebugLines()
    local s = self.state
    local orbRemaining = s.frozenOrbActiveUntil - GetTime()
    return {
        "  Frozen Orb: " .. (orbRemaining > 0
            and string.format("%.1fs remaining", orbRemaining)
            or "inactive"),
        "  Last cast Flurry: " .. tostring(s.lastCastWasFlurry),
    }
end

function Profile:GetPhase()
    if not UnitAffectingCombat("player") then return nil end
    if GetTime() < self.state.frozenOrbActiveUntil then return "Burst" end
    return nil
end

Engine:RegisterProfile(Profile)

if TrueShot.CustomProfile then
    TrueShot.CustomProfile.RegisterConditionSchema("Mage.Frost.Frostfire", {
        { id = "frozen_orb_active",    label = "Frozen Orb Active",      params = {} },
        { id = "last_cast_was_flurry", label = "Last Cast Was Flurry",   params = {} },
    })
end
