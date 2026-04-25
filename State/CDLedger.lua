-- TrueShot State/CDLedger: central cooldown tracker for Hunter rotational spells
--
-- Replaces scattered per-profile timer constants (BW_COOLDOWN, WT_COOLDOWN,
-- BOOMSTICK_COOLDOWN) with a single data-driven, haste-aware ledger driven by
-- UNIT_SPELLCAST_SUCCEEDED. Exposes engine conditions `cd_ready` and
-- `cd_remaining` so profiles can drop their local `*_on_cd`-shaped conditions.
--
-- PRIMARY SIGNALS
--   UNIT_SPELLCAST_SUCCEEDED (player)  - cast detection, timer start
--   GetSpellBaseCooldown(spellID)      - unmodified base CD in ms (non-secret,
--                                        Patch 4.3.0+, confirmed readable on
--                                        Midnight 12.0.4 per warcraft.wiki.gg)
--   UnitSpellHaste("player")           - haste scaling, guarded by issecretvalue
--                                        (wiki lists SecretArguments flag, so we
--                                        degrade to "no scaling" when secret)
--
-- NOT USED
--   C_Spell.GetSpellCooldown is per-spell gated by
--   C_Secrets.ShouldSpellCooldownBeSecret on Midnight with no published Hunter
--   whitelist. Reading it would tie the ledger to secret-gate drift every patch.
--   The cast-event + base-CD path is deterministic and survives any gate change.
--
-- STRATEGY
--   Cast-event local timer is PRIMARY. Live base-CD + haste are read through
--   pcall+issecretvalue guards and fall back to hardcoded defaults if the API
--   returns 0/nil/secret. This matches the "degrade safely" rule in
--   docs/FRAMEWORK.md and the "heuristic state" model in docs/API_CONSTRAINTS.md.

TrueShot = TrueShot or {}
TrueShot.CDLedger = TrueShot.CDLedger or {}

local CDLedger = TrueShot.CDLedger

local function IsSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function SafeCooldownSnapshot(spellID)
    if not C_Spell or not C_Spell.GetSpellCooldown then return nil end
    local ok, cooldown = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or type(cooldown) ~= "table" then return nil end

    local startTime = cooldown.startTime or 0
    local duration = cooldown.duration or 0
    local modRate = cooldown.modRate or 1

    if IsSecret(startTime) or IsSecret(duration) or IsSecret(modRate) then
        return nil
    end
    if type(startTime) ~= "number" or type(duration) ~= "number" or type(modRate) ~= "number" then
        return nil
    end
    if startTime <= 0 or duration <= 0 or modRate <= 0 then
        return nil
    end

    return {
        startTime = startTime,
        duration = duration,
        modRate = modRate,
    }
end

------------------------------------------------------------------------
-- Spec (data-driven, one entry per tracked spell)
--
-- base_ms       : fallback if GetSpellBaseCooldown returns 0/nil/secret
-- haste_scaled  : apply (1 + haste/100) divisor to the base CD
-- reset_by      : list of spellIDs whose cast fully clears this spell's timer
-- reduce_by     : map of spellID -> seconds subtracted from the remaining CD
--
-- Sources per entry are cited inline (URL + guide date + patch).
------------------------------------------------------------------------

CDLedger.spec = {
    -- Berserk (Feral): 180s flat baseline. Incarnation: Avatar of Ashamane
    -- spellbook-overrides Berserk for talented Feral Druids, but both spells
    -- share the same real cooldown and should block the same queue rule.
    -- Sources: Wowhead spell pages for Berserk (50334, "Cooldown 3 minutes")
    -- and Incarnation: Avatar of Ashamane (102543, "Cooldown 3 minutes"),
    -- both read 2026-04-23.
    [106951]  = { base_ms = 180000, haste_scaled = false, shared_cd = { [102543] = true } },
    [102543]  = { base_ms = 180000, haste_scaled = false, shared_cd = { [106951] = true } },

    -- Bestial Wrath (BM): 30s flat. Source: Azortharion, Icy Veins BM Hunter
    -- Rotation, guide updated 2026-04-10, Patch 12.0.4.
    -- URL: https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-rotation-cooldowns-abilities
    [19574]   = { base_ms = 30000, haste_scaled = false },

    -- Trueshot (MM): 120s flat baseline. Source: Azortharion, Icy Veins MM
    -- Hunter Rotation, guide updated 2026-04-09, Patch 12.0.4. Live
    -- GetSpellBaseCooldown reads still win when talents modify the value.
    -- URL: https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-rotation-cooldowns-abilities
    [288613]  = { base_ms = 120000, haste_scaled = false },

    -- Wild Thrash (BM): 8s flat. Source: Azortharion 2026-04-10 (same URL),
    -- "8s CD = 100% Beast Cleave uptime if used on CD" (BM Rotation Reference).
    [1264359] = { base_ms = 8000,  haste_scaled = false },

    -- Boomstick (SV): 30s flat. Source: Azortharion, Icy Veins SV Hunter
    -- Rotation, guide updated 2026-03-27, Patch 12.0.4.
    -- URL: https://www.icy-veins.com/wow/survival-hunter-pve-dps-rotation-cooldowns-abilities
    [1261193] = { base_ms = 30000, haste_scaled = false },
}

-- Per-spell ledger state. Keyed by spellID; cleared entry means "not on CD".
-- cast_time      : GetTime() at OnSpellCastSucceeded
-- expected_ready : GetTime() + effective CD seconds
CDLedger.state = {}

------------------------------------------------------------------------
-- Base CD resolution
--
-- Prefer the live GetSpellBaseCooldown read (it already reflects talent CD
-- reductions for the player) with graceful fallback to the hardcoded base_ms.
------------------------------------------------------------------------

local function ResolveBaseSeconds(spellID)
    local entry = CDLedger.spec[spellID]
    if not entry then return nil end

    local liveMs = nil
    if GetSpellBaseCooldown then
        local ok, cdMs, _gcdMs = pcall(GetSpellBaseCooldown, spellID)
        if ok and type(cdMs) == "number" and cdMs > 0 and not IsSecret(cdMs) then
            liveMs = cdMs
        end
    end

    local baseMs = liveMs or entry.base_ms
    local seconds = baseMs / 1000

    if entry.haste_scaled and UnitSpellHaste then
        local ok, hastePct = pcall(UnitSpellHaste, "player")
        if ok and type(hastePct) == "number" and not IsSecret(hastePct) then
            seconds = seconds / (1 + hastePct / 100)
        end
        -- else: degrade silently to "no haste scaling" rather than lie
    end

    return seconds
end

------------------------------------------------------------------------
-- Cast-event dispatch
--
-- Called from Core.lua's UNIT_SPELLCAST_SUCCEEDED handler for the local player.
-- Same input as Engine:OnSpellCast, so the two calls run alongside each other.
------------------------------------------------------------------------

function CDLedger:OnSpellCastSucceeded(spellID)
    if not spellID or IsSecret(spellID) then return end

    local now = GetTime()

    -- Start this spell's CD if we track it.
    local entry = self.spec[spellID]
    if entry then
        local cdSeconds = ResolveBaseSeconds(spellID)
        if cdSeconds and cdSeconds > 0 then
            local cooldownState = {
                cast_time = now,
                expected_ready = now + cdSeconds,
            }
            self.state[spellID] = cooldownState
            if entry.shared_cd then
                for sharedSpellID in pairs(entry.shared_cd) do
                    self.state[sharedSpellID] = {
                        cast_time = cooldownState.cast_time,
                        expected_ready = cooldownState.expected_ready,
                    }
                end
            end
        end
    end

    -- Apply resets/reductions keyed by the spell we just observed.
    for targetID, targetSpec in pairs(self.spec) do
        if targetSpec.reset_by and targetSpec.reset_by[spellID] then
            self.state[targetID] = nil
        end
        if targetSpec.reduce_by and targetSpec.reduce_by[spellID] then
            local st = self.state[targetID]
            if st then
                st.expected_ready = st.expected_ready - targetSpec.reduce_by[spellID]
                if st.expected_ready <= now then
                    self.state[targetID] = nil
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- Query surface (used by Engine conditions cd_ready / cd_remaining)
------------------------------------------------------------------------

function CDLedger:IsOnCooldown(spellID)
    local st = self.state[spellID]
    if not st then return false end
    return GetTime() < st.expected_ready
end

function CDLedger:SecondsUntilReady(spellID)
    local st = self.state[spellID]
    if not st then return 0 end
    local remaining = st.expected_ready - GetTime()
    if remaining > 0 then return remaining end
    return 0
end

-- Seconds since the most recent observed cast of `spellID`, or nil if the
-- ledger has never seen a cast of that spell. Used by profiles that need the
-- cast-timestamp semantic (e.g. a "Burst" phase that outlasts the CD window).
function CDLedger:SecondsSinceCast(spellID)
    local st = self.state[spellID]
    if not st then return nil end
    return GetTime() - st.cast_time
end

------------------------------------------------------------------------
-- Lifecycle
--
-- Intentionally NO reset on combat end: a Bestial Wrath cast near the end of a
-- pull is still on cooldown when the next pull starts. OnCombatEnd is kept for
-- future per-spec reset flags.
------------------------------------------------------------------------

function CDLedger:Reset()
    self.state = {}
end

function CDLedger:OnCombatEnd()
    -- no-op by design
end

------------------------------------------------------------------------
-- Display snapshot (tier-3 cooldown rendering fallback)
--
-- Display.lua's preferred path is DurationObject (action slot, then spell),
-- followed by direct readable C_Spell.GetSpellCooldown values. When BOTH are
-- unavailable (DurationObject helpers missing on this build) and the direct
-- read is secret-gated, the swipe would otherwise blank.
--
-- This snapshot is a visual-only last-resort: shape matches Cooldown:SetCooldown
-- (startTime, duration, modRate). It is NOT a strict-mode rotation truth source
-- - the engine still consults IsOnCooldown / SecondsUntilReady through their
-- existing seams, which carry the same caveats.
--
-- Returns nil for:
--   * secret spellIDs
--   * spells outside the tracked spec
--   * timers that have already expired
------------------------------------------------------------------------

function CDLedger:GetDisplaySnapshot(spellID)
    if not spellID or IsSecret(spellID) then return nil end
    if not self.spec[spellID] then return nil end
    local st = self.state[spellID]
    if not st then return nil end
    local now = GetTime()
    if st.expected_ready <= now then return nil end
    local duration = st.expected_ready - st.cast_time
    if duration <= 0 then return nil end
    return {
        startTime = st.cast_time,
        duration = duration,
        modRate = 1,
    }
end

------------------------------------------------------------------------
-- Reconcile against C_Spell.GetSpellCooldown
--
-- Hook for SPELL_UPDATE_COOLDOWN. Best-effort, secret-guarded: only prunes a
-- ledger entry when the API returns NON-SECRET values that authoritatively
-- mean "not on cooldown" (zero startTime or zero duration). Secret/unreadable
-- responses leave the local timer untouched, so the tier-3 display fallback
-- stays accurate when the player just cast a gated spell.
--
-- Never seeds new entries: that is ReseedFromCooldownAPI's job, and we do not
-- want a SPELL_UPDATE_COOLDOWN flood to clobber the cast-event ledger.
------------------------------------------------------------------------

function CDLedger:ReconcileFromCooldownAPI()
    if not C_Spell or not C_Spell.GetSpellCooldown then return end
    for spellID in pairs(self.state) do
        local ok, cooldown = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and type(cooldown) == "table" then
            local startTime = cooldown.startTime
            local duration = cooldown.duration
            local readable = type(startTime) == "number"
                and type(duration) == "number"
                and not IsSecret(startTime)
                and not IsSecret(duration)
            if readable and (startTime <= 0 or duration <= 0) then
                self.state[spellID] = nil
            end
        end
    end
end

function CDLedger:ReseedFromCooldownAPI()
    local now = GetTime()
    self.state = {}
    for spellID in pairs(self.spec) do
        local snapshot = SafeCooldownSnapshot(spellID)
        if snapshot then
            -- C_Spell.GetSpellCooldown duration is treated as wall-clock time;
            -- modRate is carried for UI animation but does not shorten the
            -- actual cooldown lifetime we need to reseed here.
            local elapsed = now - snapshot.startTime
            local remaining = (snapshot.startTime + snapshot.duration) - now
            if remaining > 0 then
                local cooldownState = {
                    cast_time = now - elapsed,
                    expected_ready = now + remaining,
                }
                self.state[spellID] = cooldownState
                local entry = self.spec[spellID]
                if entry and entry.shared_cd then
                    for sharedSpellID in pairs(entry.shared_cd) do
                        self.state[sharedSpellID] = {
                            cast_time = cooldownState.cast_time,
                            expected_ready = cooldownState.expected_ready,
                        }
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- Debug surface
------------------------------------------------------------------------

function CDLedger:GetDebugLines()
    local lines = {}
    for spellID, st in pairs(self.state) do
        local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or tostring(spellID)
        local remaining = st.expected_ready - GetTime()
        if remaining > 0 then
            lines[#lines + 1] = string.format("  %s (%d): %.1fs remaining", name, spellID, remaining)
        end
    end
    return lines
end

return CDLedger
