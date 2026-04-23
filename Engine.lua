-- TrueShot Engine: generic queue computation and condition evaluation
-- Profile-agnostic - delegates spec-specific conditions to the active profile

TrueShot = TrueShot or {}
TrueShot.Engine = {}

local Engine = TrueShot.Engine

Engine.burstModeActive = false
Engine.combatStartTime = nil
Engine.activeProfile = nil
Engine.lastQueueMeta = {
    source = "ac",
    reason = nil,
    bucket = nil,
    score = nil,
    scoreBreakdown = nil,
    phase = nil,
    aoeHintSpell = nil,
    reasonCode = "AC_PRIMARY",
}

function Engine:ResetQueueMeta()
    local meta = self.lastQueueMeta
    meta.source = "ac"
    meta.reason = nil
    meta.bucket = nil
    meta.score = nil
    meta.scoreBreakdown = nil
    meta.phase = nil
    meta.aoeHintSpell = nil
    meta.reasonCode = "AC_PRIMARY"
end

local function IsSecret(val)
    return issecretvalue and issecretvalue(val) or false
end

local function IsStrictMode()
    return TrueShot.SignalRegistry and TrueShot.SignalRegistry:IsStrictMode()
end

local function IsConditionAllowed(cond)
    if not TrueShot.SignalRegistry then return true end
    return TrueShot.SignalRegistry:IsConditionAllowed(cond)
end

-- Per-tick caches: use a monotonic frame counter instead of GetTime() floats
-- to guarantee exactly one recompute per ComputeQueue call.
local _computeTick = 0

local _hostileCount = 0
local _hostileCountTick = -1

local function IsAttackableUnitToken(unit)
    if type(unit) ~= "string" or unit == "" or IsSecret(unit) then
        return false
    end

    local okExists, exists = pcall(UnitExists, unit)
    if not okExists or not exists or IsSecret(exists) then
        return false
    end

    local okAttack, canAttack = pcall(UnitCanAttack, "player", unit)
    if not okAttack or IsSecret(canAttack) then
        return false
    end

    return canAttack == true
end

local _hostileCountTime = 0

local function GetHostileCount()
    local now = GetTime()
    if _hostileCountTick == _computeTick and _hostileCountTime == now then
        return _hostileCount
    end
    _hostileCountTick = _computeTick
    _hostileCountTime = now
    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        _hostileCount = 0
        return 0
    end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or not plates or IsSecret(plates) then
        _hostileCount = 0
        return 0
    end
    local count = 0
    for _, plate in ipairs(plates) do
        local unit = plate.namePlateUnitToken or plate.unitToken
        if IsAttackableUnitToken(unit) then
            count = count + 1
        end
    end
    _hostileCount = count
    return count
end

------------------------------------------------------------------------
-- Spell overlay glow tracking (proc detection)
------------------------------------------------------------------------

local _glowingSpells = {}

local _glowFrame = CreateFrame("Frame")
_glowFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
_glowFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
_glowFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
_glowFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
_glowFrame:SetScript("OnEvent", function(_, event, spellID)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        -- Clear stale glow state on lifecycle boundaries (guards against missed GLOW_HIDE)
        wipe(_glowingSpells)
        return
    end
    if not spellID or IsSecret(spellID) then return end
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        _glowingSpells[spellID] = true
    else
        _glowingSpells[spellID] = nil
    end
end)

function Engine:IsSpellGlowing(spellID)
    -- Always revalidate via poll (guards against stale cache)
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        local ok, result = pcall(C_SpellActivationOverlay.IsSpellOverlayed, spellID)
        if ok and not IsSecret(result) then
            _glowingSpells[spellID] = result == true or nil
            return result == true
        end
    end
    -- Fallback to cached event state if poll unavailable
    return _glowingSpells[spellID] == true
end

------------------------------------------------------------------------
-- Assisted Combat suggestion cache
------------------------------------------------------------------------

local _acSuggestionTick = -1
local _acPrimarySpell = nil
local _acSuggestedSpells = {}

local _acSuggestionTime = 0

local function RefreshACSuggestions()
    local now = GetTime()
    if _acSuggestionTick == _computeTick and _acSuggestionTime == now then
        return
    end
    _acSuggestionTick = _computeTick
    _acSuggestionTime = now
    _acPrimarySpell = nil
    wipe(_acSuggestedSpells)

    if not C_AssistedCombat or not C_AssistedCombat.IsAvailable() then
        return
    end

    local baseSpell = C_AssistedCombat.GetNextCastSpell()
    if baseSpell and not IsSecret(baseSpell) then
        _acPrimarySpell = baseSpell
        _acSuggestedSpells[baseSpell] = true
    end

    local rotSpells = C_AssistedCombat.GetRotationSpells()
    if not rotSpells or IsSecret(rotSpells) then
        return
    end

    for _, entry in ipairs(rotSpells) do
        local spellID = entry
        if type(entry) == "table" then
            spellID = entry.spellID or entry[1]
        end
        if spellID and not IsSecret(spellID) then
            _acSuggestedSpells[spellID] = true
        end
    end
end

function Engine:IsSpellSuggestedByAC(spellID)
    if not spellID then return false end
    RefreshACSuggestions()
    return _acSuggestedSpells[spellID] == true
end

------------------------------------------------------------------------
-- Condition evaluator (generic conditions only)
------------------------------------------------------------------------

function Engine:EvalCondition(cond)
    if not cond then return true end
    if not IsConditionAllowed(cond) then return false end

    if cond.type == "usable" then
        if C_Spell and C_Spell.IsSpellUsable then
            local ok, result = pcall(C_Spell.IsSpellUsable, cond.spellID)
            return ok and result == true
        end
        return false

    elseif cond.type == "castable" then
        return self:IsSpellCastable(cond.spellID)

    elseif cond.type == "target_casting" then
        if UnitExists("target") then
            local ok1, casting = pcall(UnitCastingInfo, "target")
            local ok2, channeling = pcall(UnitChannelInfo, "target")
            if not ok1 and not ok2 then return false end
            if IsSecret(casting) or IsSecret(channeling) then return false end
            return (ok1 and casting ~= nil) or (ok2 and channeling ~= nil)
        end
        return false

    elseif cond.type == "in_combat" then
        return UnitAffectingCombat("player")

    elseif cond.type == "spell_glowing" then
        return self:IsSpellGlowing(cond.spellID)

    elseif cond.type == "ac_suggested" then
        return self:IsSpellSuggestedByAC(cond.spellID)

    elseif cond.type == "target_count" then
        local count = GetHostileCount()
        if cond.op == ">=" then return count >= cond.value end
        if cond.op == ">" then return count > cond.value end
        return false

    elseif cond.type == "resource" then
        local powerType = cond.powerType or 0
        local ok, current = pcall(UnitPower, "player", powerType)
        if ok and not IsSecret(current) then
            if cond.op == ">=" then return current >= cond.value end
            if cond.op == ">"  then return current >  cond.value end
            if cond.op == "==" then return current == cond.value end
            if cond.op == "<"  then return current <  cond.value end
            if cond.op == "<=" then return current <= cond.value end
        end
        return false

    elseif cond.type == "spell_charges" then
        if C_Spell and C_Spell.GetSpellCharges then
            local ok, info = pcall(C_Spell.GetSpellCharges, cond.spellID)
            if ok and info then
                local charges = info.currentCharges
                if IsSecret(charges) then return false end
                if cond.op == ">=" then return charges >= cond.value end
                if cond.op == ">"  then return charges >  cond.value end
                if cond.op == "==" then return charges == cond.value end
                if cond.op == "<"  then return charges <  cond.value end
                if cond.op == "<=" then return charges <= cond.value end
            end
        end
        return false

    elseif cond.type == "cd_ready" then
        if TrueShot.CDLedger then
            return TrueShot.CDLedger:IsOnCooldown(cond.spellID) == false
        end
        return false

    elseif cond.type == "cd_remaining" then
        if not TrueShot.CDLedger then return false end
        local remaining = TrueShot.CDLedger:SecondsUntilReady(cond.spellID)
        if cond.op == ">=" then return remaining >= cond.value end
        if cond.op == ">"  then return remaining >  cond.value end
        if cond.op == "==" then return remaining == cond.value end
        if cond.op == "<"  then return remaining <  cond.value end
        if cond.op == "<=" then return remaining <= cond.value end
        return false

    elseif cond.type == "burst_mode" then
        return self.burstModeActive

    elseif cond.type == "combat_opening" then
        if not self.combatStartTime then return false end
        return (GetTime() - self.combatStartTime) <= (cond.duration or 2)

    elseif cond.type == "not" then
        return not self:EvalCondition(cond.inner)

    elseif cond.type == "and" then
        return self:EvalCondition(cond.left) and self:EvalCondition(cond.right)

    elseif cond.type == "or" then
        return self:EvalCondition(cond.left) or self:EvalCondition(cond.right)
    end

    -- Delegate to active profile for profile-specific conditions
    if self.activeProfile and self.activeProfile.EvalCondition then
        local result = self.activeProfile:EvalCondition(cond)
        if result ~= nil then return result end
    end

    return false
end

------------------------------------------------------------------------
-- Spell legality gate
------------------------------------------------------------------------

function Engine:IsSpellCastable(spellID)
    if not spellID then return false end
    local known = IsPlayerSpell(spellID)
    if not known then return false end
    if IsStrictMode() then return true end

    -- Charge-bearing spells are directly readable enough for shipped use.
    -- If at least one charge is available, treat the spell as castable even
    -- while recharge timing is ticking in the background.
    if C_Spell and C_Spell.GetSpellCharges then
        local okCharges, info = pcall(C_Spell.GetSpellCharges, spellID)
        if okCharges and info and not IsSecret(info) then
            local charges = info.currentCharges
            if type(charges) == "number" and not IsSecret(charges) then
                if charges <= 0 then
                    return false
                end
                return true
            end
        end
    end

    -- Non-charge spells: if cooldown data is readable and shows an active CD,
    -- the spell is not castable now. This avoids stale AC primaries such as
    -- Kill Command sitting in slot 1 while still cooling down.
    if C_Spell and C_Spell.GetSpellCooldown then
        local okCd, cooldown = pcall(C_Spell.GetSpellCooldown, spellID)
        if okCd and type(cooldown) == "table" then
            local startTime = cooldown.startTime or 0
            local duration = cooldown.duration or 0
            local modRate = cooldown.modRate or 1
            if not IsSecret(startTime) and not IsSecret(duration) and not IsSecret(modRate)
                and type(startTime) == "number" and type(duration) == "number" and type(modRate) == "number"
                and startTime > 0 and duration > 0 and modRate > 0 then
                if (startTime + duration) > GetTime() then
                    return false
                end
            end
        end
    end

    if C_Spell and C_Spell.IsSpellUsable then
        local ok, result = pcall(C_Spell.IsSpellUsable, spellID)
        return ok and result == true
    end
    return false
end

------------------------------------------------------------------------
-- Queue computation
------------------------------------------------------------------------

local blacklistedSpells = {}

function Engine:RebuildBlacklist()
    wipe(blacklistedSpells)
    if not self.activeProfile then return end
    for _, rule in ipairs(self.activeProfile.rules) do
        if rule.type == "BLACKLIST" then
            blacklistedSpells[rule.spellID] = true
        end
    end
end

function Engine:InvalidatePerTickCaches()
    _computeTick = _computeTick + 1
end

-- Reusable tables to reduce GC churn in OnUpdate
local _queue = {}
local _condBlacklist = {}
local _seen = {}
local _hybridCandidates = {}
local _aoeCondition = { type = "target_count", op = ">=", value = 3 }

local function IsBlocked(spellID)
    return blacklistedSpells[spellID] or _condBlacklist[spellID]
end

local function AddCandidate(candidates, seen, spellID)
    if type(spellID) ~= "number" or IsSecret(spellID) or seen[spellID] then
        return
    end
    candidates[#candidates + 1] = spellID
    seen[spellID] = true
end

function Engine:CollectHybridCandidates(profile, baseSpell, rotSpells)
    if not profile or not profile.hybrid or profile.hybrid.enabled ~= true then
        return nil
    end

    wipe(_hybridCandidates)
    wipe(_seen)
    local candidates = _hybridCandidates
    local seen = _seen

    AddCandidate(candidates, seen, baseSpell)

    if rotSpells then
        for _, entry in ipairs(rotSpells) do
            local spellID = entry
            if type(entry) == "table" then
                spellID = entry.spellID or entry[1]
            end
            AddCandidate(candidates, seen, spellID)
        end
    end

    if profile.rotationalSpells then
        for spellID in pairs(profile.rotationalSpells) do
            AddCandidate(candidates, seen, spellID)
        end
    end

    if profile.GetHybridCandidates then
        local extra = profile:GetHybridCandidates({
            baseSpell = baseSpell,
            rotationSpells = rotSpells,
            candidates = candidates,
        })
        if type(extra) == "table" then
            for _, spellID in ipairs(extra) do
                AddCandidate(candidates, seen, spellID)
            end
        end
    end

    return candidates
end

function Engine:SelectHybridDecision(profile, baseSpell, rotSpells)
    if IsStrictMode() then
        return nil
    end
    if not profile or not profile.hybrid or profile.hybrid.enabled ~= true then
        return nil
    end
    if not profile.hybrid.bucketOrder or not profile.GetHybridBucket then
        return nil
    end

    local candidates = self:CollectHybridCandidates(profile, baseSpell, rotSpells)
    if not candidates or #candidates == 0 then
        return nil
    end

    local bucketRanks = {}
    for i, bucketName in ipairs(profile.hybrid.bucketOrder) do
        bucketRanks[bucketName] = i
    end

    local context = {
        baseSpell = baseSpell,
        rotationSpells = rotSpells,
        candidates = candidates,
    }

    local best = nil
    local bestBucketRank = math.huge
    local bestScore = -math.huge

    for _, spellID in ipairs(candidates) do
        if not IsBlocked(spellID) and self:IsSpellCastable(spellID) then
            local bucketName = profile:GetHybridBucket(spellID, context)
            local bucketRank = bucketRanks[bucketName]
            if bucketRank then
                local score, reason, breakdown = 0, nil, nil
                if profile.GetHybridScore then
                    score, reason, breakdown = profile:GetHybridScore(spellID, bucketName, context)
                    if type(score) ~= "number" then
                        score = 0
                    end
                end

                local beatsCurrent = false
                if bucketRank < bestBucketRank then
                    beatsCurrent = true
                elseif bucketRank == bestBucketRank then
                    if score > bestScore then
                        beatsCurrent = true
                    elseif score == bestScore and spellID == baseSpell and (not best or best.spellID ~= baseSpell) then
                        beatsCurrent = true
                    end
                end

                if beatsCurrent then
                    best = {
                        spellID = spellID,
                        bucket = bucketName,
                        score = score,
                        reason = reason,
                        scoreBreakdown = breakdown,
                    }
                    bestBucketRank = bucketRank
                    bestScore = score
                end
            end
        end
    end

    return best
end

function Engine:ComputeQueue(iconCount)
    _computeTick = _computeTick + 1
    wipe(_queue)
    local queue = _queue
    local profile = self.activeProfile
    if not profile then
        self:ResetQueueMeta()
        return queue
    end

    if not C_AssistedCombat or not C_AssistedCombat.IsAvailable() then
        self:ResetQueueMeta()
        return queue
    end

    RefreshACSuggestions()
    local baseSpell = _acPrimarySpell
    local rotSpells = C_AssistedCombat.GetRotationSpells()

    -- Build conditional blacklist for this frame
    wipe(_condBlacklist)
    local condBlacklist = _condBlacklist
    for _, rule in ipairs(profile.rules) do
        if rule.type == "BLACKLIST_CONDITIONAL" and self:EvalCondition(rule.condition) then
            condBlacklist[rule.spellID] = true
        end
    end

    -- IsBlocked uses module-level tables (blacklistedSpells + _condBlacklist)

    if baseSpell and IsBlocked(baseSpell) then baseSpell = nil end
    if baseSpell and not self:IsSpellCastable(baseSpell) then baseSpell = nil end

    local pos1 = nil
    local source = "ac"
    local reason = nil
    local bucket = nil
    local score = nil
    local scoreBreakdown = nil

    local hybridDecision = self:SelectHybridDecision(profile, baseSpell, rotSpells)
    if hybridDecision then
        pos1 = hybridDecision.spellID
        source = "hybrid"
        reason = hybridDecision.reason or hybridDecision.bucket
        bucket = hybridDecision.bucket
        score = hybridDecision.score
        scoreBreakdown = hybridDecision.scoreBreakdown
    else
        -- PIN rules (highest priority, first match wins). EXPERIMENTAL_PIN is
        -- only reachable when strict mode is disabled. Existing PIN/PREFER
        -- rules are treated as experimental until strict-safe presentation
        -- rule types exist.
        local pinnedSpell = nil
        local firedRule = nil
        if not IsStrictMode() then
            for _, rule in ipairs(profile.rules) do
                if (rule.type == "PIN" or rule.type == "EXPERIMENTAL_PIN")
                    and self:EvalCondition(rule.condition) then
                    if self:IsSpellCastable(rule.spellID) and not IsBlocked(rule.spellID) then
                        pinnedSpell = rule.spellID
                        firedRule = rule
                        break
                    end
                end
            end
        end

        -- PREFER rules (only if no PIN fired). EXPERIMENTAL_PREFER is only
        -- reachable when strict mode is disabled.
        local preferredSpell = nil
        if not pinnedSpell and not IsStrictMode() then
            for _, rule in ipairs(profile.rules) do
                if (rule.type == "PREFER" or rule.type == "EXPERIMENTAL_PREFER")
                    and self:EvalCondition(rule.condition) then
                    if self:IsSpellCastable(rule.spellID) and not IsBlocked(rule.spellID) then
                        preferredSpell = rule.spellID
                        firedRule = rule
                        break
                    end
                end
            end
        end

        pos1 = pinnedSpell or preferredSpell or baseSpell
        if firedRule then
            source = (firedRule.type == "PIN" or firedRule.type == "EXPERIMENTAL_PIN") and "pin" or "prefer"
            reason = firedRule.reason
        end
    end

    if pos1 and not IsBlocked(pos1) then
        queue[#queue + 1] = pos1
    end

    -- Phase detection: profile-specific first, then engine-level AoE
    local phase = nil
    if not IsStrictMode() and profile.GetPhase then
        phase = profile:GetPhase()
    end
    if not phase then
        if self:EvalCondition(_aoeCondition) then phase = "AoE" end
    end

    -- AoE hint: profile declares a spell to show in secondary icon when AoE detected
    local aoeHintSpell = nil
    if profile.aoeHint and self:EvalCondition(profile.aoeHint.condition) then
        local hintID = profile.aoeHint.spellID
        if hintID and self:IsSpellCastable(hintID) and not IsBlocked(hintID) then
            aoeHintSpell = hintID
        end
    end

    self.lastQueueMeta.source = source
    self.lastQueueMeta.reason = reason
    self.lastQueueMeta.bucket = bucket
    self.lastQueueMeta.score = score
    self.lastQueueMeta.scoreBreakdown = scoreBreakdown
    self.lastQueueMeta.phase = phase
    self.lastQueueMeta.aoeHintSpell = aoeHintSpell
    if source == "ac" then
        self.lastQueueMeta.reasonCode = "AC_PRIMARY"
    elseif source == "hybrid" then
        self.lastQueueMeta.reasonCode = "EXPERIMENTAL_OVERRIDE"
    else
        self.lastQueueMeta.reasonCode = "EXPERIMENTAL_OVERRIDE"
    end

    -- Positions 2+ from GetRotationSpells()
    if rotSpells then
        wipe(_seen)
        local seen = _seen
        if pos1 then seen[pos1] = true end

        for _, entry in ipairs(rotSpells) do
            if #queue >= iconCount then break end

            local spellID = entry
            if type(entry) == "table" then
                spellID = entry.spellID or entry[1]
            end

            if spellID
                and not seen[spellID]
                and not IsBlocked(spellID)
                and self:IsSpellCastable(spellID)
            then
                queue[#queue + 1] = spellID
                seen[spellID] = true
            end
        end
    end

    return queue
end

------------------------------------------------------------------------
-- Profile management
------------------------------------------------------------------------

TrueShot.Profiles = {}

function Engine:RegisterProfile(profile)
    local specID = profile.specID
    if not TrueShot.Profiles[specID] then
        TrueShot.Profiles[specID] = {}
    end
    table.insert(TrueShot.Profiles[specID], profile)
end

-- Resolve the player's active hero talent tree via Blizzard's authoritative
-- API. Returns a numeric SubTreeID or nil. The call is guarded with pcall
-- and issecretvalue so profile activation stays safe when the API is
-- unavailable or returns a secret value.
local function GetActiveHeroTalentSubTreeID()
    if not C_ClassTalents or not C_ClassTalents.GetActiveHeroTalentSpec then
        return nil
    end
    local ok, subTreeID = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
    if not ok then return nil end
    if IsSecret(subTreeID) then return nil end
    if type(subTreeID) ~= "number" then return nil end
    return subTreeID
end

function Engine:ActivateProfile(specID)
    local candidates = TrueShot.Profiles[specID]
    if not candidates or #candidates == 0 then
        self.activeProfile = nil
        return false
    end

    local prev = self.activeProfile

    local function adopt(profile)
        self.activeProfile = profile
        if profile ~= prev then
            if profile.ResetState then profile:ResetState() end
        end
        self:RebuildBlacklist()
        return true
    end

    -- First pass: match by heroTalentSubTreeID via C_ClassTalents. Hero trees
    -- whose signature talents are passives or procs (for example Spellslinger)
    -- cannot be identified via IsPlayerSpell, because those spells never land
    -- in the player spellbook. The SubTreeID check short-circuits that case.
    local activeSubTreeID = GetActiveHeroTalentSubTreeID()
    if activeSubTreeID then
        for _, profile in ipairs(candidates) do
            if profile.heroTalentSubTreeID == activeSubTreeID then
                return adopt(profile)
            end
        end
    end

    -- Second pass: match by markerSpell (legacy spellbook-based detection).
    for _, profile in ipairs(candidates) do
        if profile.markerSpell and IsPlayerSpell(profile.markerSpell) then
            return adopt(profile)
        end
    end

    -- Fallback: first profile without markerSpell. Profiles that already
    -- declare heroTalentSubTreeID but intentionally omit markerSpell still
    -- need a deterministic fallback path when C_ClassTalents is unavailable.
    for _, profile in ipairs(candidates) do
        if not profile.markerSpell then
            return adopt(profile)
        end
    end

    -- No marker matched and no markerless fallback: stay inactive
    self.activeProfile = nil
    return false
end

function Engine:OnSpellCast(spellID)
    if self.activeProfile and self.activeProfile.OnSpellCast then
        self.activeProfile:OnSpellCast(spellID)
    end
end

function Engine:OnCombatEnd()
    if self.activeProfile and self.activeProfile.OnCombatEnd then
        self.activeProfile:OnCombatEnd()
    end
end
