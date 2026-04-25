local function read_file(path)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return text
end

local function assert_contains(text, needle, msg)
    if not text:find(needle, 1, true) then
        error(msg or ("missing expected text: " .. needle), 2)
    end
end

local function assert_not_contains(text, needle, msg)
    if text:find(needle, 1, true) then
        error(msg or ("unexpected text: " .. needle), 2)
    end
end

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

test("cooldown remaining text is opt-in by default", function()
    local core = read_file("Core.lua")
    assert_contains(core, "showCooldownText = false",
        "Core defaults should expose an opt-in showCooldownText setting")
end)

test("settings panel exposes a cooldown text checkbox", function()
    local settings = read_file("SettingsPanel.lua")
    assert_contains(settings, "showCooldownText",
        "SettingsPanel should wire the showCooldownText option")
    assert_contains(settings, "Show cooldown numbers",
        "SettingsPanel should present a user-facing cooldown numbers label")
    assert_contains(settings, "cooldownTextCheck.sync()",
        "SettingsPanel should keep the cooldown text checkbox synced on show")
end)

test("display creates and clears a per-icon cooldown text overlay", function()
    local display = read_file("Display.lua")
    assert_contains(display, "cooldownText",
        "Display should create a per-icon cooldownText font string")
    assert_contains(display, "ClearCooldownText",
        "Display should have a central helper for hiding cooldown text")
    assert_contains(display, "UpdateCooldownText",
        "Display should update cooldown text separately from swipe rendering")
end)

test("cooldown text hides when its option or swipe rendering is disabled", function()
    local display = read_file("Display.lua")
    assert_contains(display, "showCooldownText",
        "Display should read the showCooldownText option")
    assert_contains(display, "showCooldownSwipe",
        "Display should keep tying text visibility to active cooldown visuals")
    assert_contains(display, "ClearCooldownText(icon)",
        "Display should hide cooldown text on ready/disabled paths")
    assert_contains(display, "self:UpdateCooldownText(icon, spellID)",
        "Display should refresh cooldown text during queue rendering")
end)

test("cooldown text avoids unknown or secret cooldown values", function()
    local display = read_file("Display.lua")
    assert_contains(display, "issecretvalue",
        "Display cooldown text should preserve secret-value guards")
    assert_not_contains(display, "cooldownText:SetText(current)",
        "Cooldown text must not display raw secret passthrough values")
end)

if failed > 0 then
    error(string.format("%d passed, %d failed", passed, failed))
end

print(string.format("%d passed, %d failed", passed, failed))
