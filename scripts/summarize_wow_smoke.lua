local path = arg and arg[1]
if not path then
    io.stderr:write("usage: summarize_wow_smoke.lua <SavedVariables/TrueShot.lua>\n")
    os.exit(2)
end

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

print("index\ttimestamp\tmode\tprofileID\tprofile\tpassed\tfailed\tstrict\tcombat\tac\tqueue\tsource\treason")
for i, report in ipairs(history) do
    print(table.concat({
        tostring(i),
        tostring(report.timestamp or ""),
        tostring(report.mode or "load"),
        tostring(report.profileID or ""),
        tostring(report.profile or ""),
        tostring(report.passed),
        tostring(report.failed),
        tostring(report.strict),
        tostring(report.inCombat),
        tostring(report.acAvailable),
        tostring(report.queueCount or ""),
        tostring(report.source or ""),
        tostring(report.reasonCode or ""),
    }, "\t"))
end
