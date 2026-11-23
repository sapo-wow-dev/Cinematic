-- A feature's update loop and its breaker (5 errors in 3 s turn it off),
-- every state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-22-diagnostics-feature-loop-restart.md):
--   python -I Tools/offline/run.py Tools/offline/featureloopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/featureloopmatrix.lua --base <ref>
-- A loop run every frame or every second on a timer (ns.FeatureLoop's
-- every); turned off by its breaker or healthy; then its feature switched
-- off and on again, left on, or switched off; and what it runs fixed by then
-- or still failing. Each cell: how many of 8 frames (or ticks) it ran after.
-- The rule: a loop the breaker turned off stays off while its feature stays
-- on (no error spam), and starts again when the feature is switched off and
-- on; one still failing trips the breaker again after 5. (7c3e0c1: the
-- wrapper was made once, dead for the session whatever the feature did.)

local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
-- (Errors counted here, not reported: the addon's own repeat check would
-- stop it for the session and spoil the next cells.)
ns.ReportError = function() end
-- (Timers kept, to tick by hand.)
local tickers = {}
C_Timer.NewTicker = function(_, fn) -- luacheck: ignore 122
	local t = { fn = fn }
	function t.Cancel() t.cancelled = true end
	tickers[#tickers + 1] = t
	return t
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "featureloop-breaker",
	fixed = { client = client },
	dims = {
		{ "loop", { "frame", "timer" } },
		{ "broke", { "tripped", "no" } },
		{ "then", { "offon", "stayon", "off" } },
		{ "fixed", { "yes", "no" } },
	},
	cell = function(c)
		local frame = wow.CreateFrame("Frame")
		local on, broken, runs = true, true, 0
		local first = #tickers + 1
		ns.FeatureLoop(frame, function()
			runs = runs + 1
			if broken then error("matrix: a loop that keeps failing") end
		end, function() return on end, c.loop == "timer" and 1 or nil)
		local function Drive(times)
			for _ = 1, times do
				if c.loop == "frame" then
					local update = frame._scripts.OnUpdate
					if update then update(frame, 0.1) end
				else
					for i = first, #tickers do
						if not tickers[i].cancelled then tickers[i].fn() end
					end
				end
			end
		end
		if c.broke == "tripped" then
			Drive(8)
			if runs ~= 5 then return "breaker didn't trip: " .. runs end
		end
		broken = c.fixed == "no"
		if c["then"] == "offon" then
			on = false
			ns.SyncFeatureLoops()
			on = true
		elseif c["then"] == "off" then
			on = false
		end
		ns.SyncFeatureLoops()
		runs = 0
		Drive(8)
		local out = "runs=" .. runs
		on = false
		ns.SyncFeatureLoops()
		return out
	end,
	pins = {
		-- (Running: all 8 when fixed; 5 and the breaker again when not.)
		{ "fixed=yes", "runs=8" },
		{ "fixed=no", "runs=5" },
		-- (Switched off: no loop.)
		{ "then=off", "runs=0" },
		-- (Tripped and the feature left on: stays off.)
		{ "broke=tripped then=stayon", "runs=0" },
	},
})
