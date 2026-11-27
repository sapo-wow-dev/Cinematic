-- An update loop its breaker turned off (5 errors in 3 s): what it drew put
-- away, and when it starts again, every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-dead-loop-clear.md):
--   python -I Tools/offline/run.py Tools/offline/deadloopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/deadloopmatrix.lua --base <ref>
-- A feature loop (ns.FeatureLoop, every frame or on a 1 s timer) or a set
-- loop (ns.SetOnUpdate), given a clean-up; tripped; then left on, /cine
-- resume, or its feature switched off and on (a set loop: set again); what
-- it runs fixed by then or still failing. Each cell: how often its clean-up
-- ran, and how many of 8 frames (or ticks) it ran after.
-- The rule (a player 2026-11-25, Teleport Vision frozen on screen till
-- Alt+F4): a loop turned off puts away what it drew, at once; it stays off
-- while left alone (no error stream), and /cine resume or starting the
-- feature over brings it back (off again after 5 more if still failing).

local client = arg and arg[1] or "forever"
local now = 100
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function(stand)
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	-- (The frames Teleport Vision's file makes, to run only their loops.)
	local Create = CreateFrame
	CreateFrame = function(...)
		local frame = Create(...)
		local source = debug and debug.getinfo and debug.getinfo(2, "S")
		if source and tostring(source.source):find("TeleportVision", 1, true) then
			stand.teleFrames = stand.teleFrames or {}
			stand.teleFrames[#stand.teleFrames + 1] = frame
		end
		return frame
	end
	-- luacheck: pop
end)
-- (Errors counted here, not reported: the addon's own repeat check would
-- stop it for the session and spoil the next cells.)
ns.ReportError = function() end
local tickers = {}
C_Timer.NewTicker = function(_, fn) -- luacheck: ignore 122
	local t = { fn = fn }
	function t.Cancel() t.cancelled = true end
	tickers[#tickers + 1] = t
	return t
end
ns.suspendQuiet = true

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "dead-loop-clear",
	fixed = { client = client },
	dims = {
		{ "loop", { "feature", "timer", "set" } },
		{ "then", { "stayon", "resume", "offon" } },
		{ "fixed", { "yes", "no" } },
	},
	cell = function(c)
		local frame = wow.CreateFrame("Frame")
		local on, broken, runs, cleared = true, true, 0, 0
		local first = #tickers + 1
		local function Run()
			runs = runs + 1
			if broken then error("matrix: a loop that keeps failing") end
		end
		local function Clear() cleared = cleared + 1 end
		local function Set()
			if c.loop == "set" then
				ns.SetOnUpdate(frame, Run, Clear)
			else
				ns.FeatureLoop(frame, Run, function() return on end, c.loop == "timer" and 1 or nil, Clear)
			end
		end
		Set()
		local function Drive(times)
			for _ = 1, times do
				if c.loop == "timer" then
					for i = first, #tickers do
						if not tickers[i].cancelled then tickers[i].fn() end
					end
				else
					local update = frame._scripts.OnUpdate
					if update then update(frame, 0.1) end
				end
			end
		end
		Drive(8)
		if runs ~= 5 then return "breaker didn't trip: " .. runs end
		broken = c.fixed == "no"
		if c["then"] == "resume" then
			ns.Suspend("matrix")
			ns.Resume()
		elseif c["then"] == "offon" then
			if c.loop == "set" then
				Set()
			else
				on = false
				ns.SyncFeatureLoops()
				on = true
			end
		end
		ns.SyncFeatureLoops()
		runs = 0
		Drive(8)
		local out = ("cleared=%d runs=%d"):format(cleared, runs)
		on = false
		ns.SyncFeatureLoops()
		if c.loop == "set" then ns.SetOnUpdate(frame, nil) end
		return out
	end,
	pins = {
		-- (Left on: off, put away once.)
		{ "then=stayon", "cleared=1 runs=0" },
		-- (Resumed or started over: all 8 when fixed; 5 and put away again when not.
		-- The matrix resumes through ns.Suspend, a safety stop: since 177dde2 that
		-- puts every loop's things away once more, so one clean-up more. OK'd by
		-- the user 2026-11-26.)
		{ "fixed=yes", "cleared=1 runs=8" },
		{ "fixed=no", "cleared=2 runs=5" },
		{ "then=resume fixed=yes", "cleared=2 runs=8" },
		{ "then=resume fixed=no", "cleared=3 runs=5" },
		{ "then=stayon", "cleared=1 runs=0" }, -- (later pins win)
	},
})

-- A real one: Teleport Vision's page test playing, its loop failing every
-- frame (the edges' drawing broken). The portal put away as it trips, not
-- left on screen frozen; /cine resume (fixed by then) plays the test again.
local SetVignette = ns.SetVignette
local function Tele(seconds)
	ns.SyncFeatureLoops()
	for _ = 1, math.floor(seconds * 10 + 0.5) do
		now = now + 0.1
		for _, frame in ipairs(wow.teleFrames or {}) do
			local update = frame._scripts and frame._scripts.OnUpdate
			if update then update(frame, 0.1) end
		end
	end
end
ns.db.teleportVision, ns.db.teleportVisionEdges = true, true
Matrix.Run({
	name = "dead-loop-teleport",
	fixed = { client = client },
	dims = {
		{ "then", { "stayon", "resume" } },
	},
	cell = function(c)
		now = now + 100
		-- (Its loop as new: the cell before may have left it off. The old code
		-- can't bring it back: there, "test never shown".)
		ns.Suspend("matrix")
		ns.Resume()
		Tele(3)
		ns.TestTeleportVision(2, true)
		Tele(1)
		if not ns.TeleportVisionShown() then return "test never shown" end
		ns.SetVignette = function() error("matrix: the edges' drawing broken") end
		Tele(1)
		local tripped = ns.TeleportVisionShown() and "shown" or "hidden"
		ns.SetVignette = SetVignette
		if c["then"] == "resume" then
			ns.Suspend("matrix")
			ns.Resume()
			ns.TestTeleportVision(2, true)
			Tele(1)
		else
			Tele(1)
		end
		local out = ("tripped=%s after=%s"):format(tripped, ns.TeleportVisionShown() and "shown" or "hidden")
		if ns.TeleportVisionTesting() then ns.TestTeleportVision() end
		Tele(3)
		return out
	end,
	pins = {
		{ "then=stayon", "tripped=hidden after=hidden" },
		{ "then=resume", "tripped=hidden after=shown" },
	},
})
