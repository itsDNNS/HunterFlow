-- TrueShot Engine hero-talent activation tests
-- Covers Engine:ActivateProfile with the heroTalentSubTreeID path alongside
-- the legacy markerSpell path. Regression guard for issue #88: Frost
-- Spellslinger must activate when C_ClassTalents.GetActiveHeroTalentSpec()
-- reports the Spellslinger SubTreeID, even though Spellslinger has no
-- spellbook-learnable marker spell.
--
-- Run from the addon root: lua tests/test_engine_hero_talent.lua

------------------------------------------------------------------------
-- WoW client stubs
------------------------------------------------------------------------

_G.GetTime = function() return 1000.0 end
_G.UnitAffectingCombat = function(_) return false end
_G.UnitExists = function(_) return false end
_G.UnitCanAttack = function(_, _) return false end
_G.UnitPower = function(_, _) return 0 end
_G.UnitCastingInfo = function(_) return nil end
_G.UnitChannelInfo = function(_) return nil end
_G.issecretvalue = function(_) return false end
_G.pcall = pcall
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.GetSpellBaseCooldown = function(_) return 0, 0 end
_G.UnitSpellHaste = function(_) return 0 end

-- IsPlayerSpell is what drives the legacy markerSpell path. Tests flip
-- this per-scenario so Hunter markerSpell regression coverage and Frost
-- markerless fallback both land cleanly.
local _player_spells = {}
_G.IsPlayerSpell = function(spellID)
    return _player_spells[spellID] == true
end

-- The authoritative hero-talent detection API used by the new first-pass
-- in Engine:ActivateProfile. Tests drive the returned SubTreeID directly.
local _active_hero_subtree = nil
_G.C_ClassTalents = _G.C_ClassTalents or {}
_G.C_ClassTalents.GetActiveHeroTalentSpec = function()
    return _active_hero_subtree
end

_G.C_NamePlate = _G.C_NamePlate or { GetNamePlates = function() return {} end }
_G.C_AssistedCombat = _G.C_AssistedCombat or {
    IsAvailable = function() return false end,
    GetNextCastSpell = function() return nil end,
    GetRotationSpells = function() return {} end,
}
_G.C_SpellActivationOverlay = _G.C_SpellActivationOverlay or {
    IsSpellOverlayed = function() return false end,
}
_G.C_Spell = _G.C_Spell or {}
_G.C_Spell.IsSpellUsable = function(_) return true end
_G.C_Spell.GetSpellCharges = function(_) return nil end
_G.C_Spell.GetSpellName = function(id) return "Spell#" .. tostring(id) end
_G.C_UnitAuras = _G.C_UnitAuras or { GetPlayerAuraBySpellID = function(_) return nil end }

_G.CreateFrame = function(_frameType, _name)
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end

TrueShot = { strictCompliance = false }
TrueShot.CustomProfile = { RegisterConditionSchema = function(_, _) end }

dofile("SignalRegistry.lua")
dofile("Engine.lua")
dofile("State/CDLedger.lua")

-- Load real profiles into the Engine so activation is exercised end to end.
dofile("Profiles/Arcane_Spellslinger.lua")
dofile("Profiles/Arcane_Sunfury.lua")
dofile("Profiles/Balance_ElunesChosen.lua")
dofile("Profiles/Balance_KeeperOfTheGrove.lua")
dofile("Profiles/BM_DarkRanger.lua")
dofile("Profiles/BM_PackLeader.lua")
dofile("Profiles/Devourer_Annihilator.lua")
dofile("Profiles/Devourer_VoidScarred.lua")
dofile("Profiles/Fire_Frostfire.lua")
dofile("Profiles/Fire_Sunfury.lua")
dofile("Profiles/Feral_DruidOfTheClaw.lua")
dofile("Profiles/Feral_Wildstalker.lua")
dofile("Profiles/Frost_Frostfire.lua")
dofile("Profiles/Frost_Spellslinger.lua")
dofile("Profiles/Havoc_AldrachiReaver.lua")
dofile("Profiles/Havoc_FelScarred.lua")
dofile("Profiles/MM_DarkRanger.lua")
dofile("Profiles/MM_Sentinel.lua")
dofile("Profiles/SV_PackLeader.lua")
dofile("Profiles/SV_Sentinel.lua")

local Engine = TrueShot.Engine

------------------------------------------------------------------------
-- Test harness
------------------------------------------------------------------------

local EXPECTED_PROFILES = {
    [62] = {
        ["Mage.Arcane.Spellslinger"]     = { subTreeID = 40, markerSpell = nil },
        ["Mage.Arcane.Sunfury"]          = { subTreeID = 39, markerSpell = 1241462 },
    },
    [63] = {
        ["Mage.Fire.Frostfire"]          = { subTreeID = 41, markerSpell = nil },
        ["Mage.Fire.Sunfury"]            = { subTreeID = 39, markerSpell = 1250508 },
    },
    [64] = {
        ["Mage.Frost.Frostfire"]         = { subTreeID = 41, markerSpell = nil },
        ["Mage.Frost.Spellslinger"]      = { subTreeID = 40, markerSpell = nil },
    },
    [102] = {
        ["Druid.Balance.ElunesChosen"]      = { subTreeID = 24, markerSpell = 424058 },
        ["Druid.Balance.KeeperOfTheGrove"]  = { subTreeID = 23, markerSpell = nil },
    },
    [103] = {
        ["Druid.Feral.DruidOfTheClaw"]   = { subTreeID = 21, markerSpell = 441583 },
        ["Druid.Feral.Wildstalker"]      = { subTreeID = 22, markerSpell = nil },
    },
    [253] = {
        ["Hunter.BM.DarkRanger"]         = { subTreeID = 44, markerSpell = 466930 },
        ["Hunter.BM.PackLeader"]         = { subTreeID = 43, markerSpell = nil },
    },
    [254] = {
        ["Hunter.MM.DarkRanger"]         = { subTreeID = 44, markerSpell = 466930 },
        ["Hunter.MM.Sentinel"]           = { subTreeID = 42, markerSpell = nil },
    },
    [255] = {
        ["Hunter.SV.PackLeader"]         = { subTreeID = 43, markerSpell = nil },
        ["Hunter.SV.Sentinel"]           = { subTreeID = 42, markerSpell = 1264902 },
    },
    [577] = {
        ["DemonHunter.Havoc.AldrachiReaver"] = { subTreeID = 35, markerSpell = 442294 },
        ["DemonHunter.Havoc.FelScarred"]     = { subTreeID = 34, markerSpell = nil },
    },
    [1480] = {
        ["DemonHunter.Devourer.Annihilator"] = { subTreeID = 63, markerSpell = 1253304 },
        ["DemonHunter.Devourer.VoidScarred"] = { subTreeID = 34, markerSpell = nil },
    },
}

local passed, failed = 0, 0

local function test(name, fn)
    _active_hero_subtree = nil
    _player_spells = {}
    Engine.activeProfile = nil
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. " -- " .. tostring(err))
    end
end

local function assert_true(v, msg)
    if not v then error((msg or "expected true") .. " got " .. tostring(v)) end
end

local function assert_eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a)) end
end

local function assert_profile(id)
    local active = Engine.activeProfile
    assert_true(active ~= nil, "Engine should have activated a profile")
    assert_eq(active.id, id, "Engine activated the wrong profile")
end

local function assert_profile_metadata(specID, profileID, expected)
    local candidates = TrueShot.Profiles[specID]
    assert_true(candidates ~= nil, "Candidates must exist for specID " .. tostring(specID))
    local found = nil
    for _, p in ipairs(candidates) do
        if p.id == profileID then
            found = p
            break
        end
    end
    assert_true(found ~= nil, "Profile must register: " .. profileID)
    assert_eq(found.heroTalentSubTreeID, expected.subTreeID,
        profileID .. " must declare heroTalentSubTreeID " .. tostring(expected.subTreeID))
    assert_eq(found.markerSpell, expected.markerSpell,
        profileID .. " has the wrong fallback markerSpell declaration")
end

------------------------------------------------------------------------
-- Structural guards: all supported profiles are on the subtree path
------------------------------------------------------------------------

test("All supported hero-path profiles declare subtree IDs and expected fallback markers", function()
    for specID, profiles in pairs(EXPECTED_PROFILES) do
        for profileID, expected in pairs(profiles) do
            assert_profile_metadata(specID, profileID, expected)
        end
    end
end)

------------------------------------------------------------------------
-- Hero-talent-based activation by spec/subtree
------------------------------------------------------------------------

local ACTIVATION_CASES = {
    { specID = 62,   subTreeID = 39, expected = "Mage.Arcane.Sunfury" },
    { specID = 62,   subTreeID = 40, expected = "Mage.Arcane.Spellslinger", conflictMarker = 1241462 },
    { specID = 63,   subTreeID = 39, expected = "Mage.Fire.Sunfury" },
    { specID = 63,   subTreeID = 41, expected = "Mage.Fire.Frostfire", conflictMarker = 1250508 },
    { specID = 64,   subTreeID = 40, expected = "Mage.Frost.Spellslinger" },
    { specID = 64,   subTreeID = 41, expected = "Mage.Frost.Frostfire" },
    { specID = 102,  subTreeID = 23, expected = "Druid.Balance.KeeperOfTheGrove", conflictMarker = 424058 },
    { specID = 102,  subTreeID = 24, expected = "Druid.Balance.ElunesChosen" },
    { specID = 103,  subTreeID = 21, expected = "Druid.Feral.DruidOfTheClaw" },
    { specID = 103,  subTreeID = 22, expected = "Druid.Feral.Wildstalker", conflictMarker = 441583 },
    { specID = 253,  subTreeID = 43, expected = "Hunter.BM.PackLeader", conflictMarker = 466930 },
    { specID = 253,  subTreeID = 44, expected = "Hunter.BM.DarkRanger" },
    { specID = 254,  subTreeID = 42, expected = "Hunter.MM.Sentinel", conflictMarker = 466930 },
    { specID = 254,  subTreeID = 44, expected = "Hunter.MM.DarkRanger" },
    { specID = 255,  subTreeID = 42, expected = "Hunter.SV.Sentinel" },
    { specID = 255,  subTreeID = 43, expected = "Hunter.SV.PackLeader", conflictMarker = 1264902 },
    { specID = 577,  subTreeID = 34, expected = "DemonHunter.Havoc.FelScarred", conflictMarker = 442294 },
    { specID = 577,  subTreeID = 35, expected = "DemonHunter.Havoc.AldrachiReaver" },
    { specID = 1480, subTreeID = 34, expected = "DemonHunter.Devourer.VoidScarred", conflictMarker = 1253304 },
    { specID = 1480, subTreeID = 63, expected = "DemonHunter.Devourer.Annihilator" },
}

test("Hero subtree activation works across all supported spec pairs", function()
    for _, tc in ipairs(ACTIVATION_CASES) do
        _active_hero_subtree = tc.subTreeID
        _player_spells = {}
        if tc.conflictMarker then
            _player_spells[tc.conflictMarker] = true
        end
        Engine:ActivateProfile(tc.specID)
        assert_profile(tc.expected)
    end
end)

------------------------------------------------------------------------
-- Fallback / degradation behavior
------------------------------------------------------------------------

test("Marker path still works when the hero API is unavailable", function()
    local saved = _G.C_ClassTalents.GetActiveHeroTalentSpec
    _G.C_ClassTalents.GetActiveHeroTalentSpec = nil
    _player_spells[466930] = true -- Hunter BM Dark Ranger marker
    Engine:ActivateProfile(253)
    _G.C_ClassTalents.GetActiveHeroTalentSpec = saved
    assert_profile("Hunter.BM.DarkRanger")
end)

test("Subtree-only fallback profile still activates when the hero API is unavailable", function()
    local saved = _G.C_ClassTalents.GetActiveHeroTalentSpec
    _G.C_ClassTalents.GetActiveHeroTalentSpec = nil
    Engine:ActivateProfile(253)
    _G.C_ClassTalents.GetActiveHeroTalentSpec = saved
    assert_profile("Hunter.BM.PackLeader")
end)

test("Balance fallback profile still activates when the hero API is unavailable and the marker does not match", function()
    local saved = _G.C_ClassTalents.GetActiveHeroTalentSpec
    _G.C_ClassTalents.GetActiveHeroTalentSpec = nil
    Engine:ActivateProfile(102)
    _G.C_ClassTalents.GetActiveHeroTalentSpec = saved
    assert_profile("Druid.Balance.KeeperOfTheGrove")
end)

test("Havoc fallback profile still activates when the hero API is unavailable and the marker does not match", function()
    local saved = _G.C_ClassTalents.GetActiveHeroTalentSpec
    _G.C_ClassTalents.GetActiveHeroTalentSpec = nil
    Engine:ActivateProfile(577)
    _G.C_ClassTalents.GetActiveHeroTalentSpec = saved
    assert_profile("DemonHunter.Havoc.FelScarred")
end)

test("Devourer fallback profile still activates when the hero API is unavailable and the marker does not match", function()
    local saved = _G.C_ClassTalents.GetActiveHeroTalentSpec
    _G.C_ClassTalents.GetActiveHeroTalentSpec = nil
    Engine:ActivateProfile(1480)
    _G.C_ClassTalents.GetActiveHeroTalentSpec = saved
    assert_profile("DemonHunter.Devourer.VoidScarred")
end)

test("C_ClassTalents API returns a secret value -> engine ignores it", function()
    _active_hero_subtree = 40
    local saved_secret = _G.issecretvalue
    _G.issecretvalue = function(v) return v == 40 end
    Engine:ActivateProfile(64)
    _G.issecretvalue = saved_secret
    -- Secret subTreeID must not pick Spellslinger. Fallback to markerless.
    assert_profile("Mage.Frost.Frostfire")
end)

test("C_ClassTalents API pcall error -> engine degrades cleanly", function()
    _G.C_ClassTalents.GetActiveHeroTalentSpec = function()
        error("simulated runtime error from the WoW client")
    end
    Engine:ActivateProfile(64)
    -- Must not crash. Fallback activates Frostfire.
    assert_profile("Mage.Frost.Frostfire")
    _G.C_ClassTalents.GetActiveHeroTalentSpec = function() return _active_hero_subtree end
end)

test("C_ClassTalents API returns a non-number value -> engine ignores it", function()
    local saved = _G.C_ClassTalents.GetActiveHeroTalentSpec
    _G.C_ClassTalents.GetActiveHeroTalentSpec = function()
        return "not-a-number"
    end
    Engine:ActivateProfile(64)
    _G.C_ClassTalents.GetActiveHeroTalentSpec = saved
    -- Must reject the value and fall through to the markerless profile.
    assert_profile("Mage.Frost.Frostfire")
end)

------------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
