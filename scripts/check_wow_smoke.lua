local path = arg and arg[1]
if not path then
    io.stderr:write("usage: check_wow_smoke.lua <SavedVariables/TrueShot.lua>\n")
    os.exit(2)
end

local requiredProfiles = {
    ["Hunter.BM.PackLeader"] = true,
    ["Hunter.BM.DarkRanger"] = true,
    ["Hunter.MM.DarkRanger"] = true,
    ["Hunter.MM.Sentinel"] = true,
    ["Hunter.SV.PackLeader"] = true,
    ["Hunter.SV.Sentinel"] = true,
}

local env = {}
local chunk, err = loadfile(path, "t", env)
if not chunk then
    io.stderr:write(err .. "\n")
    os.exit(1)
end

local ok, runErr = pcall(chunk)
if not ok then
    io.stderr:write(runErr .. "\n")
    os.exit(1)
end

local db = env.TrueShotDB or {}
local history = db.smokeHistory or {}
if #history == 0 and db.smokeReport then
    history = { db.smokeReport }
end

local seenLoad = {}
local seenCombat = {}
local failures = {}

local function fail(message)
    failures[#failures + 1] = message
end

local function isRequired(profileID)
    return profileID and requiredProfiles[profileID] == true
end

for _, report in ipairs(history) do
    local profileID = report.profileID
    if isRequired(profileID) then
        local mode = report.mode or "load"
        if report.passed ~= true then
            fail(profileID .. " " .. mode .. " did not pass")
        end
        if report.failed ~= 0 then
            fail(profileID .. " " .. mode .. " has failed=" .. tostring(report.failed))
        end
        if report.strict ~= true then
            fail(profileID .. " " .. mode .. " strict is not true")
        end
        if report.acAvailable ~= true then
            fail(profileID .. " " .. mode .. " Assisted Combat unavailable")
        end

        if mode == "combat" then
            seenCombat[profileID] = true
            if report.inCombat ~= true then
                fail(profileID .. " combat report was not captured in combat")
            end
            if report.source ~= "ac" then
                fail(profileID .. " combat source is " .. tostring(report.source))
            end
            if report.reasonCode ~= "AC_PRIMARY" then
                fail(profileID .. " combat reasonCode is " .. tostring(report.reasonCode))
            end
            if type(report.queueCount) ~= "number" or report.queueCount < 1 then
                fail(profileID .. " combat queueCount is " .. tostring(report.queueCount))
            end
        else
            seenLoad[profileID] = true
            if report.source and report.source ~= "ac" then
                fail(profileID .. " load source is " .. tostring(report.source))
            end
            if report.reasonCode and report.reasonCode ~= "AC_PRIMARY" then
                fail(profileID .. " load reasonCode is " .. tostring(report.reasonCode))
            end
        end
    end
end

for profileID in pairs(requiredProfiles) do
    if not seenLoad[profileID] then
        fail("missing load smoke for " .. profileID)
    end
    if not seenCombat[profileID] then
        fail("missing combat smoke for " .. profileID)
    end
end

if #failures > 0 then
    for _, message in ipairs(failures) do
        io.stderr:write("FAIL: " .. message .. "\n")
    end
    os.exit(1)
end

print("WoW smoke gate passed for all Hunter hero profiles.")
