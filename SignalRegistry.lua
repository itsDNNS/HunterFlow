-- TrueShot SignalRegistry: central compliance metadata for runtime signals.
--
-- Strict mode defaults to ON. In strict mode, only signals explicitly marked
-- allowed may influence rule decisions. Unknown signals fail closed.

TrueShot = TrueShot or {}
TrueShot.SignalRegistry = TrueShot.SignalRegistry or {}

local SignalRegistry = TrueShot.SignalRegistry

SignalRegistry.signals = {
    ac_suggested = {
        api = "C_AssistedCombat.GetNextCastSpell/GetRotationSpells",
        category = "public",
        validatedBuild = "120005",
        allowedInStrict = true,
        owner = "Engine",
        fallback = "ignore rule",
    },
    in_combat = {
        api = "UnitAffectingCombat",
        category = "public",
        validatedBuild = "legacy",
        allowedInStrict = true,
        owner = "Engine",
        fallback = "ignore rule",
    },

    spell_glowing = {
        api = "C_SpellActivationOverlay.IsSpellOverlayed",
        category = "displayOnly",
        validatedBuild = "needs-ptr-review",
        allowedInStrict = false,
        owner = "Engine",
        fallback = "profile hint only",
    },
    target_count = {
        api = "C_NamePlate.GetNamePlates/UnitCanAttack",
        category = "unavailable",
        validatedBuild = "needs-ptr-review",
        allowedInStrict = false,
        owner = "Engine",
        fallback = "manual AoE profile",
    },
    spell_charges = {
        api = "C_Spell.GetSpellCharges",
        category = "opaque",
        validatedBuild = "needs-ptr-review",
        allowedInStrict = false,
        owner = "Engine",
        fallback = "AC only",
    },
    usable = {
        api = "C_Spell.IsSpellUsable",
        category = "opaque",
        validatedBuild = "needs-ptr-review",
        allowedInStrict = false,
        owner = "Engine",
        fallback = "AC only",
    },
    castable = {
        api = "IsPlayerSpell/C_Spell.GetSpellCharges/C_Spell.GetSpellCooldown/C_Spell.IsSpellUsable",
        category = "opaque",
        validatedBuild = "needs-ptr-review",
        allowedInStrict = false,
        owner = "Engine",
        fallback = "AC only",
    },
    target_casting = {
        api = "UnitCastingInfo/UnitChannelInfo",
        category = "unavailable",
        validatedBuild = "needs-ptr-review",
        allowedInStrict = false,
        owner = "Engine",
        fallback = "no interrupt pin",
    },
    resource = {
        api = "UnitPower",
        category = "forbidden",
        validatedBuild = "120005-secret-risk",
        allowedInStrict = false,
        owner = "Engine",
        fallback = "AC only",
    },
    cd_ready = {
        api = "State/CDLedger local timer",
        category = "forbidden",
        validatedBuild = "not-strict-safe",
        allowedInStrict = false,
        owner = "CDLedger",
        fallback = "AC only",
    },
    cd_remaining = {
        api = "State/CDLedger local timer",
        category = "forbidden",
        validatedBuild = "not-strict-safe",
        allowedInStrict = false,
        owner = "CDLedger",
        fallback = "AC only",
    },
    combat_opening = {
        api = "PLAYER_REGEN_DISABLED/GetTime",
        category = "public",
        validatedBuild = "not-strict-safe",
        allowedInStrict = false,
        owner = "Engine",
        fallback = "static opener card",
    },
    burst_mode = {
        api = "User setting",
        category = "userConfig",
        validatedBuild = "not-strict-safe",
        allowedInStrict = false,
        owner = "Engine",
        fallback = "manual checklist",
    },
}

function SignalRegistry:IsStrictMode()
    if TrueShot.GetOpt then
        return TrueShot.GetOpt("strictCompliance") ~= false
    end
    return TrueShot.strictCompliance ~= false
end

function SignalRegistry:GetSignal(id)
    return self.signals[id]
end

function SignalRegistry:IsSignalAllowed(id)
    if not self:IsStrictMode() then return true end
    local signal = self:GetSignal(id)
    return signal and signal.allowedInStrict == true
end

function SignalRegistry:IsConditionAllowed(cond)
    if not self:IsStrictMode() then return true end
    if not cond then return true end

    local t = cond.type
    if t == "and" or t == "or" then
        return self:IsConditionAllowed(cond.left) and self:IsConditionAllowed(cond.right)
    end
    if t == "not" then
        return self:IsConditionAllowed(cond.inner)
    end

    return self:IsSignalAllowed(t)
end
