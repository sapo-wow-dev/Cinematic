-- Keep the shoulder when selecting yourself: its button in front of your
-- player frame (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/selffront.lua <forever|retail> < /dev/null
-- Your player frame is toplevel: a click on it with the option off brings it
-- in front of our button till a /reload (user 2026-11-20). So the button is
-- made toplevel and raised as it's placed (the option ticked, no reload), and
-- raised again when the mouse finds your frame through it; held off by
-- ns.shoulderSelfHoldFront (the selffront game test), and never in a fight.
-- Says PASS or FAIL per check.
-- luacheck: push ignore 111 112 113 121 122 212
local client = ... or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. client .. ": " .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local caught = {}
local report = ns.ReportError
ns.ReportError = function(err, ...)
	caught[#caught + 1] = tostring(err)
	if report then return report(err, ...) end
end
local fight = false
InCombatLockdown = function() return fight end
GetCVar = function(name) if name == "autoSelfCast" then return "1" end end
UnitExists = function(unit) return unit == "player" end
ns.ShoulderCamUnlocked = function() return true end
local setting = ns.Setting
ns.Setting = function(key, ...) if key == "shoulderCam" then return true end return setting(key, ...) end
local focus
GetMouseFoci = function() return { focus } end
-- luacheck: pop

local frame = CreateFrame("Button", "PlayerFrame", UIParent)
frame:SetSize(232, 100)
frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 901, 295)
frame:Show()
local part = CreateFrame("Frame", nil, frame)
-- (No target frame: the stand-in's menu button has no spot to read, and
-- the stub's answers aren't numbers. That button isn't tested here.)
rawset(_G, "TargetFrame", false)

local db = ns.db
db.shoulderCam, db.shoulderCamFakeSelf = true, false
wow.Fire("PLAYER_REGEN_ENABLED")
local state = ns.ShoulderFakeSelfState()
local button = state.button
if ns.isRetail then
	Check("the option's off on retail", not state.want, state.why)
	Check("no errors", #caught == 0, caught[1])
	print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
	if fails > 0 then os.exit(1) end
	return
end
-- (Counted: the stand-ins' frames answer Raise and SetToplevel as stubs.)
local raised, top = 0, false
button.Raise = function() raised = raised + 1 end
button.SetToplevel = function(_, on) top = on and true or false end
button.IsToplevel = function() return top end
local function Tick() wow.Fire("PLAYER_REGEN_ENABLED") end

-- 1 Ticked with no reload: placed, toplevel, raised.
db.shoulderCamFakeSelf = true
Tick()
state = ns.ShoulderFakeSelfState()
Check("ticked: the frame covered", state.covered, state.rect)
Check("ticked: ours toplevel", top)
Check("ticked: ours raised as it's placed", raised == 1, raised)

-- 2 The mouse on our button: nothing more.
focus = button
Tick()
Check("mouse on ours: not raised again", raised == 1, raised)

-- 3 The mouse finds your frame (or a part of it) through ours: raised again.
focus = frame
Tick()
Check("mouse on your frame: ours raised again", raised == 2, raised)
focus = part
Tick()
Check("mouse on a part of your frame: ours raised again", raised == 3, raised)

-- 4 In a fight: nothing (Sync waits for the fight's end).
fight = true
Tick()
Check("in a fight: not raised", raised == 3, raised)
fight = false

-- 5 Held (the game test's cause step): placed again not toplevel, not raised.
db.shoulderCamFakeSelf = false
focus = nil
Tick()
ns.shoulderSelfHoldFront = true
db.shoulderCamFakeSelf = true
local before = raised
Tick()
focus = frame
Tick()
Check("held: not toplevel", not top)
Check("held: not raised", raised == before, raised - before)
ns.shoulderSelfHoldFront = nil
Tick()
Check("let go: raised", raised == before + 1, raised - before)
Check("let go: toplevel", top)

Check("no errors", #caught == 0, caught[1])
print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
