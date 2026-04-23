-- TrueShot SignalRegistry tests
-- Run from addon root: lua tests/test_signal_registry.lua

TrueShot = {}
dofile("SignalRegistry.lua")

local SR = TrueShot.SignalRegistry
local passed, failed = 0, 0

local function test(name, fn)
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

local function assert_false(v, msg)
    if v then error((msg or "expected false") .. " got " .. tostring(v)) end
end

test("strict mode defaults on", function()
    TrueShot.strictCompliance = nil
    assert_true(SR:IsStrictMode())
end)

test("AC suggested is allowed in strict mode", function()
    TrueShot.strictCompliance = true
    assert_true(SR:IsConditionAllowed({ type = "ac_suggested", spellID = 1 }))
end)

test("signals carry review metadata", function()
    local ac = SR:GetSignal("ac_suggested")
    assert_true(type(ac.api) == "string" and ac.api ~= "")
    assert_true(type(ac.validatedBuild) == "string" and ac.validatedBuild ~= "")
    assert_true(type(ac.owner) == "string" and ac.owner ~= "")
    assert_true(type(ac.fallback) == "string" and ac.fallback ~= "")
end)

test("unsafe signals fail closed in strict mode", function()
    TrueShot.strictCompliance = true
    assert_false(SR:IsConditionAllowed({ type = "resource", powerType = 2, op = ">=", value = 10 }))
    assert_false(SR:IsConditionAllowed({ type = "spell_charges", spellID = 1, op = ">=", value = 1 }))
    assert_false(SR:IsConditionAllowed({ type = "target_count", op = ">=", value = 2 }))
    assert_false(SR:IsConditionAllowed({ type = "cd_ready", spellID = 1 }))
end)

test("unknown profile conditions fail closed in strict mode", function()
    TrueShot.strictCompliance = true
    assert_false(SR:IsConditionAllowed({ type = "trueshot_active" }))
end)

test("composite condition fails closed when any child is unsafe", function()
    TrueShot.strictCompliance = true
    assert_false(SR:IsConditionAllowed({
        type = "and",
        left = { type = "ac_suggested", spellID = 1 },
        right = { type = "spell_charges", spellID = 1, op = ">=", value = 1 },
    }))
end)

test("experimental mode allows registered and unknown signals", function()
    TrueShot.strictCompliance = false
    assert_true(SR:IsConditionAllowed({ type = "resource", powerType = 2, op = ">=", value = 10 }))
    assert_true(SR:IsConditionAllowed({ type = "trueshot_active" }))
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
