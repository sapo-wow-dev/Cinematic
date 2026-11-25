-- /cine debug gating (Dev/GatingTest.lua) offline, through its one reload: a
-- load of the dev copy per reload (each a run of its own, the saved settings
-- handed on as the game would), pretend time, the kit picking the run up
-- after the reload. The run must reach DONE with no Lua error in the test, the
-- parts left out after the reload, the Load boxes ticked back and the
-- settings put back. (Game-only reads may SKIP or FAIL here: the stand-in has
-- no loops' labels, plates, real CVars or tooltips; their FAIL lines are
-- printed, not counted, apart from a Lua error.)
--
--   python -I Tools/offline/run.py Tools/offline/gatingtest.lua [forever|retail]
-- Exit 1 on any problem.
-- luacheck: ignore 111 112 113 121 122 212 431
local LUA = os.getenv("CINE_LUA") or "lua5.1"
local client, phase, tmp = ...
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
	local file = os.tmpname()
	local f = assert(io.open(file, "w"))
	f:write("return nil")
	f:close()
	local done, failed
	for n = 1, 3 do
		local pipe = io.popen(("%s Tools/offline/gatingtest.lua %s %d %s 2>&1"):format(LUA, client, n, file))
		local out = pipe:read("*a")
		pipe:close()
		io.write(out)
		if not out:find(("gating %d: ok"):format(n), 1, true) then failed = true break end
		if out:find(", done", 1, true) then done = n break end
	end
	os.remove(file)
	if done ~= 2 then
		failed = true
		print(("gating: done after %s load(s), not 2"):format(tostring(done)))
	end
	print(failed and "gating: FAILED" or "gating: all ok")
	os.exit(failed and 1 or 0)
end

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
		NewTimer = function(delay, fn)
			local t = { at = now + delay, fn = fn, Cancel = function(self) self.cancelled = true end }
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
			if t and not t.cancelled and t.at <= now then
				if t.every then t.at = now + t.every else table.remove(timers, i) end
				pcall(t.fn, t)
			end
		end
	end
end
Screenshot = function() end
ns.noRealLayout = true
local cine = false
ns.IsCineModeOn = function() return cine end
Cinematic_ToggleCineMode = function() cine = not cine end

if phase == "1" then
	ns.HandleSlash("debug gating full")
	Advance(400)
else
	wow.Fire("PLAYER_ENTERING_WORLD", false, true)
	Advance(200)
end
local log = CinematicDB.gatingTestLog or {}
local text = table.concat(log, "\n")
local problems, fails = {}, {}
for _, line in ipairs(log) do
	if line:find("Lua error", 1, true) or line:find("own put back failed", 1, true) then problems[#problems + 1] = line end
	if line:find("verdict FAIL", 1, true) then fails[#fails + 1] = line end
end
local done = text:find("DONE", 1, true) ~= nil
if not done then
	if not text:find("reload clicked", 1, true) and not text:find("step 10 out", 1, true) then
		problems[#problems + 1] = "the run didn't reach the reload step"
	end
	if CinematicDB.loadStyle ~= false or CinematicDB.loadCameras ~= false then
		problems[#problems + 1] = "the Load boxes weren't unticked for the reload"
	end
	-- (The kit's Reload button, clicked: its preClick saves where to pick up.)
	local run = ns.TestKit.Running()
	if run and not CinematicDB.gatingTestResume then run:SaveResume() end
	local file = assert(io.open(tmp, "w"))
	file:write("return ", Dump(CinematicDB), "\n")
	file:close()
else
	if not text:find("step 11 leftout", 1, true) then problems[#problems + 1] = "the run didn't pick up after the reload" end
	if not text:find("not loaded", 1, true) and ns.ModuleLoaded("style") then
		problems[#problems + 1] = "the parts were loaded after the reload"
	end
	if CinematicDB.loadVisions == false or CinematicDB.loadCameras == false or CinematicDB.loadStyle == false
		or CinematicDB.loadAtmosphere == false then
		problems[#problems + 1] = "a Load box left off at the end"
	end
	if CinematicDB.gatingTestUndo then problems[#problems + 1] = "the undo wasn't put back" end
	if CinematicDB.gatingTestData then problems[#problems + 1] = "the test's data wasn't cleared" end
	local summary = text:match("DONE: [^\n]*")
	print("gating summary: " .. tostring(summary))
end
if os.getenv("GATING_LOG") then print(text) end
for _, line in ipairs(fails) do print(("gating %s (stand-in): %s"):format(phase, line)) end
local tag = ("gating %s"):format(phase)
for _, p in ipairs(problems) do print(tag .. ": " .. p) end
if #problems == 0 then print(tag .. ": ok" .. (done and ", done" or "")) end
