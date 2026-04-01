-- HunterFlow M1.1: AssistedCombat queue with cast-tracked Hunter state
-- BM Hunter (Spec 253) proof of concept

------------------------------------------------------------------------
-- Saved variables & defaults
------------------------------------------------------------------------

HunterFlowDB = HunterFlowDB or {}

local DEFAULTS = {
    iconCount = 2,
    iconSize = 40,
    iconSpacing = 4,
    locked = false,
}

local function GetOpt(key)
    if HunterFlowDB[key] ~= nil then return HunterFlowDB[key] end
    return DEFAULTS[key]
end

------------------------------------------------------------------------
-- Override rule engine
------------------------------------------------------------------------

-- Rule types: "BLACKLIST", "PIN", "PREFER"
-- Conditions: { type = "usable", spellID = N }
--             { type = "target_casting" }
--             { type = "target_count", op = ">=", value = N }
--             { type = "burst_mode" }
--             { type = "and", left = cond, right = cond }

local burstModeActive = false
local combatStartTime = nil

------------------------------------------------------------------------
-- Dark Ranger state machine (cast-event-based CD tracking)
------------------------------------------------------------------------

local DR = {
    blackArrowReady = true,       -- BA off CD / Deathblow proc available
    lastBlackArrowCast = 0,       -- timestamp of last BA cast
    lastBWCast = 0,               -- timestamp of last BW cast
    witheringFireUntil = 0,       -- BW cast time + 10s
    wailingArrowAvailable = false, -- WA becomes available after BW
    lastCastWasKC = false,        -- Nature's Ally: don't double KC
}
local BA_COOLDOWN = 10
local BW_COOLDOWN_ESTIMATE = 29  -- base CD 30s, 1s buffer

local function ResetDRState()
    DR.blackArrowReady = true
    DR.lastBlackArrowCast = 0
    DR.lastBWCast = 0
    DR.witheringFireUntil = 0
    DR.wailingArrowAvailable = false
    DR.lastCastWasKC = false
end

local function UpdateDRState(spellID)
    local now = GetTime()

    if spellID == 466930 then -- Black Arrow
        DR.blackArrowReady = false
        DR.lastBlackArrowCast = now
        DR.lastCastWasKC = false

    elseif spellID == 19574 then -- Bestial Wrath
        DR.blackArrowReady = true        -- guaranteed Deathblow
        DR.lastBWCast = now              -- track BW cast time for CD estimate
        DR.witheringFireUntil = now + 10 -- Withering Fire window
        DR.wailingArrowAvailable = true  -- WA unlocks
        DR.lastCastWasKC = false

    elseif spellID == 392060 then -- Wailing Arrow
        DR.blackArrowReady = true        -- guaranteed Deathblow
        DR.wailingArrowAvailable = false
        DR.lastCastWasKC = false

    elseif spellID == 34026 then -- Kill Command
        DR.lastCastWasKC = true
        -- 10% Deathblow chance - can't detect, timer fallback handles it

    else
        DR.lastCastWasKC = false
        -- Barbed Shot (217200) has 50% Deathblow - timer fallback
    end

    -- Timer fallback: if BA CD elapsed, assume ready
    if not DR.blackArrowReady and DR.lastBlackArrowCast > 0 then
        if (now - DR.lastBlackArrowCast) >= BA_COOLDOWN then
            DR.blackArrowReady = true
        end
    end
end

local function IsInWitheringFire()
    return GetTime() < DR.witheringFireUntil
end

local function WitheringFireRemaining()
    local remaining = DR.witheringFireUntil - GetTime()
    return remaining > 0 and remaining or 0
end

local function EvalCondition(cond)
    if not cond then return true end

    if cond.type == "usable" then
        if C_Spell and C_Spell.IsSpellUsable then
            local ok, result = pcall(C_Spell.IsSpellUsable, cond.spellID)
            return ok and result == true
        end
        return false

    elseif cond.type == "target_casting" then
        if UnitExists("target") then
            local casting = UnitCastingInfo("target")
            local channeling = UnitChannelInfo("target")
            return (casting ~= nil) or (channeling ~= nil)
        end
        return false

    elseif cond.type == "target_count" then
        local plates = C_NamePlate.GetNamePlates() or {}
        local count = 0
        for _, plate in ipairs(plates) do
            local unit = plate.namePlateUnitToken
            if unit and UnitExists(unit) and UnitCanAttack("player", unit) then
                count = count + 1
            end
        end
        if cond.op == ">=" then return count >= cond.value end
        if cond.op == ">" then return count > cond.value end
        return false

    elseif cond.type == "burst_mode" then
        return burstModeActive

    elseif cond.type == "combat_opening" then
        if not combatStartTime then return false end
        return (GetTime() - combatStartTime) <= (cond.duration or 2)

    elseif cond.type == "ba_ready" then
        -- Timer fallback check before evaluating
        if not DR.blackArrowReady and DR.lastBlackArrowCast > 0 then
            if (GetTime() - DR.lastBlackArrowCast) >= BA_COOLDOWN then
                DR.blackArrowReady = true
            end
        end
        return DR.blackArrowReady

    elseif cond.type == "in_withering_fire" then
        return IsInWitheringFire()

    elseif cond.type == "wf_ending" then
        -- Withering Fire has less than N seconds remaining
        local threshold = cond.seconds or 4
        return IsInWitheringFire() and WitheringFireRemaining() <= threshold

    elseif cond.type == "wa_available" then
        return DR.wailingArrowAvailable

    elseif cond.type == "last_cast_was_kc" then
        return DR.lastCastWasKC

    elseif cond.type == "bw_on_cd" then
        if DR.lastBWCast == 0 then return false end
        return (GetTime() - DR.lastBWCast) < BW_COOLDOWN_ESTIMATE

    elseif cond.type == "not" then
        return not EvalCondition(cond.inner)

    elseif cond.type == "and" then
        return EvalCondition(cond.left) and EvalCondition(cond.right)

    elseif cond.type == "or" then
        return EvalCondition(cond.left) or EvalCondition(cond.right)
    end

    return false
end

local function IsSpellCastable(spellID)
    if not spellID then return false end
    -- Gate: spell must be both known AND usable
    -- Probe showed Multi-Shot as known=false, usable=true - must reject that
    local known = IsPlayerSpell(spellID)
    if not known then return false end
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, result = pcall(C_Spell.IsSpellUsable, spellID)
        return ok and result == true
    end
    return false
end

------------------------------------------------------------------------
-- BM Hunter default profile (Spec 253)
------------------------------------------------------------------------

local BM_PROFILE = {
    specID = 253,
    rules = {
        -- Filter utility spells from rotation queue
        { type = "BLACKLIST", spellID = 883 },   -- Call Pet 1
        { type = "BLACKLIST", spellID = 982 },   -- Revive Pet

        -- Counter Shot: blacklisted per user preference
        { type = "BLACKLIST", spellID = 147362 }, -- Counter Shot

        -- Bestial Wrath: suppress from queue when recently cast (CD estimate)
        {
            type = "BLACKLIST_CONDITIONAL",
            spellID = 19574, -- Bestial Wrath
            condition = { type = "bw_on_cd" },
        },

        -- During Withering Fire: Black Arrow is highest DPS priority
        -- (fires 2 extra arrows at nearby targets)
        {
            type = "PIN",
            spellID = 466930, -- Black Arrow
            condition = {
                type = "and",
                left  = { type = "ba_ready" },
                right = { type = "in_withering_fire" },
            },
        },

        -- Wailing Arrow: cast near end of Withering Fire (<4s remaining)
        -- Grants another Deathblow for one more BA in the window
        {
            type = "PREFER",
            spellID = 392060, -- Wailing Arrow
            condition = {
                type = "and",
                left  = { type = "wa_available" },
                right = { type = "wf_ending", seconds = 4 },
            },
        },

        -- Outside Withering Fire: prefer Black Arrow when ready (on CD)
        {
            type = "PREFER",
            spellID = 466930, -- Black Arrow
            condition = {
                type = "and",
                left  = { type = "ba_ready" },
                right = { type = "not", inner = { type = "in_withering_fire" } },
            },
        },

        -- Nature's Ally: never recommend Kill Command twice in a row
        -- If last cast was KC, defer it (let AC suggest something else)
        {
            type = "BLACKLIST_CONDITIONAL",
            spellID = 34026, -- Kill Command
            condition = { type = "last_cast_was_kc" },
        },
    },
}

local activeProfile = BM_PROFILE

------------------------------------------------------------------------
-- Queue computation
------------------------------------------------------------------------

local blacklistedSpells = {}

local function RebuildBlacklist()
    wipe(blacklistedSpells)
    for _, rule in ipairs(activeProfile.rules) do
        if rule.type == "BLACKLIST" then
            blacklistedSpells[rule.spellID] = true
        end
    end
end

local function ComputeQueue()
    local queue = {}

    -- 1. Get base recommendation from Blizzard
    if not C_AssistedCombat or not C_AssistedCombat.IsAvailable() then
        return queue
    end

    local baseSpell = C_AssistedCombat.GetNextCastSpell()

    -- 2. Build conditional blacklist for this frame
    local condBlacklist = {}
    for _, rule in ipairs(activeProfile.rules) do
        if rule.type == "BLACKLIST_CONDITIONAL" and EvalCondition(rule.condition) then
            condBlacklist[rule.spellID] = true
        end
    end

    local function IsBlocked(spellID)
        return blacklistedSpells[spellID] or condBlacklist[spellID]
    end

    -- 3. Evaluate PIN rules (highest priority, first match wins)
    local pinnedSpell = nil
    for _, rule in ipairs(activeProfile.rules) do
        if rule.type == "PIN" and EvalCondition(rule.condition) then
            if IsSpellCastable(rule.spellID) and not IsBlocked(rule.spellID) then
                pinnedSpell = rule.spellID
                break
            end
        end
    end

    -- 4. Evaluate PREFER rules (only if no PIN fired)
    local preferredSpell = nil
    if not pinnedSpell then
        for _, rule in ipairs(activeProfile.rules) do
            if rule.type == "PREFER" and EvalCondition(rule.condition) then
                if IsSpellCastable(rule.spellID) and not IsBlocked(rule.spellID) then
                    preferredSpell = rule.spellID
                    break
                end
            end
        end
    end

    -- 5. Determine position 1
    -- If base spell is conditionally blacklisted, skip it
    if baseSpell and IsBlocked(baseSpell) then baseSpell = nil end
    local pos1 = pinnedSpell or preferredSpell or baseSpell
    if pos1 and not IsBlocked(pos1) then
        queue[#queue + 1] = pos1
    end

    -- 5. Fill positions 2+ from GetRotationSpells()
    local rotSpells = C_AssistedCombat.GetRotationSpells()
    if rotSpells then
        local seen = {}
        if pos1 then seen[pos1] = true end

        for _, entry in ipairs(rotSpells) do
            if #queue >= GetOpt("iconCount") then break end

            local spellID = entry
            -- GetRotationSpells might return tables or raw IDs
            if type(entry) == "table" then
                spellID = entry.spellID or entry[1]
            end

            if spellID
                and not seen[spellID]
                and not IsBlocked(spellID)
                and IsSpellCastable(spellID)
            then
                queue[#queue + 1] = spellID
                seen[spellID] = true
            end
        end
    end

    return queue
end

------------------------------------------------------------------------
-- Display
------------------------------------------------------------------------

local container = CreateFrame("Frame", "HunterFlowFrame", UIParent,
    "BackdropTemplate")
container:SetSize(200, 50)
container:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
container:SetMovable(true)
container:EnableMouse(true)
container:SetClampedToScreen(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self)
    if not GetOpt("locked") then self:StartMoving() end
end)
container:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

local icons = {}

local function GetKeybindForSpell(spellID)
    -- Scan action bars for the spell and return its keybind
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and id == spellID then
            local key = GetBindingKey("ACTIONBUTTON" .. ((slot - 1) % 12 + 1))
            if not key then
                local bar = math.ceil(slot / 12)
                local btn = (slot - 1) % 12 + 1
                if bar == 1 then
                    key = GetBindingKey("ACTIONBUTTON" .. btn)
                elseif bar <= 6 then
                    key = GetBindingKey("MULTIACTIONBAR" .. (bar - 1) .. "BUTTON" .. btn)
                end
            end
            if key then return key end
        end
    end
    return nil
end

local function CreateIcon(index)
    local size = GetOpt("iconSize")
    local spacing = GetOpt("iconSpacing")

    local frame = CreateFrame("Frame", "HunterFlowIcon" .. index,
        container, "BackdropTemplate")
    frame:SetSize(size, size)
    frame:SetPoint("LEFT", container, "LEFT",
        (index - 1) * (size + spacing), 0)

    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetAllPoints()
    frame.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    frame.keybind = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    frame.keybind:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    frame.keybind:SetJustifyH("RIGHT")

    frame.cooldown = CreateFrame("Cooldown", "HunterFlowCD" .. index,
        frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()
    frame.cooldown:SetDrawSwipe(true)
    frame.cooldown:SetDrawEdge(true)
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.6)

    frame.border = frame:CreateTexture(nil, "OVERLAY")
    frame.border:SetAllPoints()
    frame.border:SetAtlas("UI-HUD-ActionBar-IconFrame")

    -- Dim icons after position 1
    if index > 1 then
        frame:SetAlpha(0.7)
    end

    frame:Hide()
    return frame
end

local function EnsureIcons()
    local count = GetOpt("iconCount")
    while #icons < count do
        icons[#icons + 1] = CreateIcon(#icons + 1)
    end
end

local function UpdateContainerSize()
    local count = GetOpt("iconCount")
    local size = GetOpt("iconSize")
    local spacing = GetOpt("iconSpacing")
    container:SetSize(count * size + (count - 1) * spacing, size)
end

local function UpdateDisplay(queue)
    EnsureIcons()
    local count = GetOpt("iconCount")

    for i = 1, count do
        local icon = icons[i]
        local spellID = queue[i]

        if spellID then
            local texture = C_Spell.GetSpellTexture(spellID)
            if texture then
                icon.texture:SetTexture(texture)
                local key = GetKeybindForSpell(spellID)
                icon.keybind:SetText(key or "")

                -- Cooldown sweep: pass secret cooldown object directly to
                -- Blizzard's renderer without reading/comparing the values
                if icon.cooldown and C_Spell.GetSpellCooldown then
                    local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, spellID)
                    if ok and cdInfo then
                        local setOk = pcall(icon.cooldown.SetCooldownFromDurationObject,
                            icon.cooldown, cdInfo)
                        if not setOk then
                            icon.cooldown:Clear()
                        end
                    else
                        icon.cooldown:Clear()
                    end
                end

                icon:Show()
            else
                icon:Hide()
            end
        else
            icon:Hide()
            if icon.cooldown then icon.cooldown:Clear() end
        end
    end
end

------------------------------------------------------------------------
-- Update throttle
------------------------------------------------------------------------

local UPDATE_INTERVAL = 0.1
local timeSinceUpdate = 0

local function OnUpdate(self, elapsed)
    timeSinceUpdate = timeSinceUpdate + elapsed
    if timeSinceUpdate < UPDATE_INTERVAL then return end
    timeSinceUpdate = 0

    local queue = ComputeQueue()
    UpdateDisplay(queue)
end

------------------------------------------------------------------------
-- Events & lifecycle
------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

local function Enable()
    RebuildBlacklist()
    UpdateContainerSize()
    EnsureIcons()
    container:EnableMouse(not GetOpt("locked"))
    container:Show()
    container:SetScript("OnUpdate", OnUpdate)
end

local function Disable()
    container:SetScript("OnUpdate", nil)
    container:Hide()
end

local BM_HUNTER_SPEC_ID = 253

local function IsBMHunter()
    local specIndex = GetSpecialization()
    if not specIndex then return false end
    local specID = GetSpecializationInfo(specIndex)
    return specID == BM_HUNTER_SPEC_ID
end

local function CheckSpecAndToggle()
    if not IsBMHunter() then
        Disable()
        return false
    end
    if not C_AssistedCombat or not C_AssistedCombat.IsAvailable() then
        Disable()
        return false
    end
    return true
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        ResetDRState()
        if CheckSpecAndToggle() then
            Enable()
            print("|cff00ff00[HunterFlow]|r loaded. Initial profile: BM Hunter.")
            print("|cffaaaaaa  /hf lock|unlock|burst|help|r")
        elseif not IsBMHunter() then
            print("|cffaaaaaa[HunterFlow]|r Not BM Hunter. Addon inactive.")
        else
            print("|cffff0000[HunterFlow]|r Assisted Combat not available.")
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and spellID then
            UpdateDRState(spellID)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        combatStartTime = GetTime()
        if IsBMHunter() and not container:IsShown() then Enable() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        combatStartTime = nil
        DR.lastCastWasKC = false
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        ResetDRState()
        if CheckSpecAndToggle() then
            RebuildBlacklist()
            Enable()
        end
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

SLASH_HUNTERFLOW1 = "/hf"
SLASH_HUNTERFLOW2 = "/hunterflow"
SlashCmdList["HUNTERFLOW"] = function(msg)
    msg = msg:lower():trim()

    if msg == "lock" then
        HunterFlowDB.locked = true
        container:EnableMouse(false)
        print("|cff00ff00[HF]|r Frame locked (click-through).")

    elseif msg == "unlock" then
        HunterFlowDB.locked = false
        container:EnableMouse(true)
        print("|cff00ff00[HF]|r Frame unlocked. Drag to reposition.")

    elseif msg == "burst" then
        burstModeActive = not burstModeActive
        if burstModeActive then
            print("|cff00ff00[HF]|r Burst mode ON")
        else
            print("|cff00ff00[HF]|r Burst mode OFF")
        end

    elseif msg == "hide" then
        Disable()
        print("|cff00ff00[HF]|r Hidden. /hf show to restore.")

    elseif msg == "show" then
        Enable()

    elseif msg == "debug" then
        local queue = ComputeQueue()
        print("|cff00ff00[HF] Queue:|r")
        for i, id in ipairs(queue) do
            local name = C_Spell.GetSpellName(id) or "?"
            local usable = IsSpellCastable(id) and "usable" or "not usable"
            print("  " .. i .. ": " .. name .. " (" .. id .. ") [" .. usable .. "]")
        end
        print("|cff00ff00[HF] Dark Ranger State:|r")
        print("  BA ready: " .. tostring(DR.blackArrowReady))
        print("  Withering Fire: " .. (IsInWitheringFire()
            and string.format("%.1fs remaining", WitheringFireRemaining())
            or "inactive"))
        print("  Wailing Arrow: " .. (DR.wailingArrowAvailable and "available" or "not available"))
        print("  Last cast was KC: " .. tostring(DR.lastCastWasKC))
        print("  Burst mode: " .. tostring(burstModeActive))

    elseif msg == "help" then
        print("|cff00ff00[HunterFlow]|r Commands:")
        print("  /hf lock    - Lock frame position")
        print("  /hf unlock  - Unlock frame for dragging")
        print("  /hf burst   - Toggle burst mode")
        print("  /hf hide    - Hide the display")
        print("  /hf show    - Show the display")
        print("  /hf debug   - Print current queue")

    else
        print("|cff00ff00[HunterFlow]|r Use /hf help for commands.")
    end
end
