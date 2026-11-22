-- /cine debug loadparts (Dev/LoadPartsTest.lua) offline, through its
-- reloads: a load of the dev copy per reload (each a run of its own, the
-- saved settings handed on as the game would), pretend time, the kit picking
-- the run up after each. Started with both loaded (3 loads) and with Visions
-- left out (4: its first step ticks the box). Every step PASS, the log ends
-- DONE with 0 fail, the changed settings put back and both Load boxes on.
--
--   python -I Tools/offline/run.py Tools/offline/loadparts.lua [forever|retail]
-- Exit 1 on any problem.
-- luacheck: ignore 111 112 113 121 122 212 431
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, phase, tmp, start = ...
client = client or "forever"

local function Dump(value)
	if type(value) == "table" then
		local parts = {}
		for k, v in pairs(value) do
			if type(v) ~= "function" then parts[#parts + 1] = "[" .. Dump(k) .. "]=" .. Dump(v) end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif type(value) == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

if not phase then
	local failed = false
	-- (on, off: full runs, every part, Visions left out to start in off; quick:
	-- every part proven but Visions, so just it: one reload, the proven left out.)
	for _, each in ipairs({ { "on", 3 }, { "off", 4 }, { "quick", 2 } }) do
		local file = os.tmpname()
		local f = assert(io.open(file, "w"))
		f:write(each[1] == "off" and "return { loadVisions = false }" or "return nil")
		f:close()
		local done
		for n = 1, 6 do
			local pipe = io.popen(("%s Tools/offline/loadparts.lua %s %d %s %s 2>&1"):format(LUA, client, n, file,
				each[1]))
			local out = pipe:read("*a")
			pipe:close()
			io.write(out)
			if not out:find(("loadparts %s %d: ok"):format(each[1], n), 1, true) then
				failed = true
				break
			end
			if out:find(", done", 1, true) then
				done = n
				break
			end
		end
		if done ~= each[2] then
			failed = true
			print(("loadparts %s: done after %s load(s), not %d"):format(each[1], tostring(done), each[2]))
		end
		os.remove(file)
	end
	print(failed and "loadparts: FAILED" or "loadparts: all ok")
	os.exit(failed and 1 or 0)
end

-- (The first load: nil, or Visions left out to start; then the last load's.)
local db = assert(loadfile(tmp))()
local now = 100
local timers = {}
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	rawset(_G, "CinematicDB", db)
	rawset(_G, "GetTime", function() return now end)
	rawset(_G, "C_Timer", {
		After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end,
		NewTicker = function(every, fn)
			local t = { every = every, at = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
			timers[#timers + 1] = t
			return t
		end,
	})
end)
local function Advance(seconds)
	local stop = now + seconds
	while now < stop do
		now = now + 0.1
		for i = #timers, 1, -1 do
			local t = timers[i]
			if not t.cancelled and t.at <= now then
				if t.every then t.at = now + t.every else table.remove(timers, i) end
				pcall(t.fn, t)
			end
		end
	end
end
-- (The game's own, as the stand-in doesn't have them: memory less with
-- Visions left out, every frame, a screenshot, the Reload box found.)
UpdateAddOnMemoryUsage = function() end
GetAddOnMemoryUsage = function() return ns.ModuleLoaded("visions") and 9000 or 7000 end
EnumerateFrames = function(after)
	local i = 0
	for n, frame in ipairs(wow.frames) do if frame == after then i = n end end
	return wow.frames[i + 1]
end
Screenshot = function() end
local popup = wow.NewObject("Frame", "StaticPopup1")
popup._shown = false
rawset(_G, "StaticPopup1", popup)
-- (Its words as given: the test checks one box names every change.)
popup.text = wow.NewObject("FontString", nil, popup)
StaticPopup_Show = function(_, text) popup._shown = true popup.text:SetText(text) end
StaticPopup_Hide = function() popup._shown = false end
StaticPopup_FindVisible = function() return popup._shown and popup or nil end

local problems = {}
-- (quick: Visions as if new, not proven yet.)
if start == "quick" then ns.loadPartsParts[1].proven = nil end
if phase == "1" then
	ns.HandleSlash(start == "quick" and "debug loadparts" or "debug loadparts full")
	Advance(120)
else
	-- (The kit picks the run up 2 s after the reload's PLAYER_ENTERING_WORLD: isLogin false, isReload true.)
	wow.Fire("PLAYER_ENTERING_WORLD", false, true)
	Advance(120)
end
local log = CinematicDB.loadPartsTestLog or {}
local text = table.concat(log, "\n")
for _, line in ipairs(log) do
	if line:find("FAIL", 1, true) then problems[#problems + 1] = line end
end
local done = text:find("DONE", 1, true) ~= nil
-- (The test's box under the game's Reload box while that's up: run 2 hid it.)
-- (The box's step out of all five, after a reload too: it said "step 4/2".)
local boxText = ns.padTestBox and ns.padTestBox.text and ns.padTestBox.text:GetText()
if not done and not (type(boxText) == "string" and boxText:find("step %d/5:")) then
	problems[#problems + 1] = "the test's box doesn't count out of all 5 steps: " .. tostring(boxText)
end
if not done and not (ns.padTestBox and ns.padTestBox.placedUnder == popup) then
	problems[#problems + 1] = "the test's box isn't under the game's Reload box"
end
if not done then
	if not text:find("reload clicked", 1, true) then problems[#problems + 1] = "the run didn't wait for the reload" end
	local file = assert(io.open(tmp, "w"))
	file:write("return ", Dump(CinematicDB), "\n")
	file:close()
else
	if not text:find("DONE", 1, true) then problems[#problems + 1] = "no DONE line" end
	if not text:find(" 0 fail", 1, true) then problems[#problems + 1] = "the summary isn't 0 fail" end
	if CinematicDB.loadVisions == false or CinematicDB.loadCameras == false or CinematicDB.loadStyle == false then problems[#problems + 1] = "a Load box left off" end
	if CinematicDB.loadPartsTestUndo then problems[#problems + 1] = "the undo wasn't put back" end
	if start == "quick" then
		-- (Just Visions, the proven checks left out: no question, no second reload.)
		if text:find("Cameras not loaded", 1, true) then problems[#problems + 1] = "quick: a proven part was left out too" end
		if not text:find("Visions not loaded after the reload", 1, true) then problems[#problems + 1] = "quick: Visions wasn't checked" end
		if text:find("Do you see the game's box", 1, true) then problems[#problems + 1] = "quick: asked about the Reload box again" end
		if not text:find("proven, left out", 1, true) then problems[#problems + 1] = "quick: the proven step wasn't left out" end
	end
end
if os.getenv("LOADPARTS_LOG") then print(text) end
local tag = ("loadparts %s %s"):format(start or "on", phase)
for _, p in ipairs(problems) do print(tag .. ": " .. p) end
if #problems == 0 then print(tag .. ": ok" .. (done and ", done" or "")) end
