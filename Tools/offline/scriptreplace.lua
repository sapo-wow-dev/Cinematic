-- A camera script played while another plays (offline, Lua 5.1 via Tools/offline/run.py):
--   python -I Tools/offline/run.py Tools/offline/scriptreplace.lua < /dev/null
-- Audit 2026-11-22: Play on a script's page (or /cine script play) while
-- one ran only stopped the old one's moves (Start's StopAll): its Finish
-- never ran, so a zoom step's Past max left cameraDistanceMaxZoomFactor
-- raised for the session. On a stand-in CVar store: script A zooms past
-- your max, B is played over it: A ends (logged), the max back to yours,
-- and B plays. PASS or FAIL per check.

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local cvars = { cameraDistanceMaxZoomFactor = "1.9" }
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	GetCameraZoom = function() return 10 end
	UnitAffectingCombat = function() return false end
	IsIndoors = function() return false end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", Install)
ns.db.enabled = true

-- (Only CameraScripts.lua's own update loop: its function found through the
-- protecting wrapper's upvalues. Every frame's ran too long.)
local function From(fn, file, depth)
	if type(fn) ~= "function" or depth > 3 then return false end
	local info = debug.getinfo(fn, "S")
	if info and info.source and info.source:find(file, 1, true) then return true end
	for i = 1, 20 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		if From(value, file, depth + 1) then return true end
	end
	return false
end
local function Tick(times)
	for _ = 1, times do
		for _, frame in ipairs(wow.frames) do
			local update = frame._scripts and frame._scripts.OnUpdate
			if update and From(update, "CameraScripts.lua", 0) then
				local ok, err = pcall(update, frame, 0.05)
				if not ok then print("tick: " .. tostring(err)) end
			end
		end
	end
end
local function Logged(text)
	for _, line in ipairs(ns.db.log or {}) do
		if tostring(line):find(text, 1, true) then return true end
	end
	return false
end

local zoom = ns.NewCameraScriptStep("zoom")
zoom.to, zoom.secs, zoom.past = 30, 20, "yes"
local A = { id = "replaceA", name = "Replace A", steps = { zoom }, ending = {}, rules = {} }
local B = { id = "replaceB", name = "Replace B", steps = { ns.NewCameraScriptStep("zoom") }, ending = {}, rules = {} }

Check("A plays", ns.PlayCameraScript(A) == true)
Tick(3)
Check("A's Past max raised the max", cvars.cameraDistanceMaxZoomFactor == "2.6", cvars.cameraDistanceMaxZoomFactor)
Check("B plays over it", ns.PlayCameraScript(B) == true)
Check("A ended first", Logged("camera script Replace A ended (replaced)"))
Tick(3)
local playing = ns.PlayingCameraScript and ns.PlayingCameraScript()
Check("B is the one playing", type(playing) == "table" and playing.name == "Replace B" or playing == "Replace B",
	tostring(type(playing) == "table" and playing.name or playing))
Check("the max back to yours", cvars.cameraDistanceMaxZoomFactor == "1.9", cvars.cameraDistanceMaxZoomFactor)

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
if fails > 0 then os.exit(1) end
