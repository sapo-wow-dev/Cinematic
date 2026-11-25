-- The bad-weather view distance's once-a-second look (Graphics.lua), every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-atmosphere-idle-cost.md):
--   python -I Tools/offline/run.py Tools/offline/rainviewloopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/rainviewloopmatrix.lua forever --base <ref>
-- Reduce view distance in bad weather (rainViewScale) at 0 or up, CineMode
-- on or off, rain falling or not (the Weather page on: its page off is
-- rainviewpagematrix.lua's); and before that,
-- nothing, the view distance already brought in (a downpour in CineMode), or
-- the page's Preview for a second (ended by the time it's looked at).
-- Each cell, after the state's set and a few looks: whether the look still
-- runs (a game timer each second) and the view distance: "yours" or "in".
-- The rule: it only runs while it can do something: it could bring the view
-- in now, or it's still bringing it back out.
local client = arg and arg[1] or "forever"
local now = 100
local cvars = { horizonStart = "3000", farclip = "3000", Sound_MusicVolume = "1", Sound_EnableMusic = "1" }
local tickers = {}
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	GetCVar = function(name) return cvars[name] end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	C_CVar = C_CVar or {}
	C_CVar.GetCVar = GetCVar
	C_CVar.SetCVar = SetCVar
	InCombatLockdown = function() return false end
	C_Timer.NewTicker = function(every, fn)
		local t = { every = every, fn = fn, src = debug.getinfo(2, "S").source or "" }
		t.Cancel = function(self) self.cancelled = true end
		tickers[#tickers + 1] = t
		return t
	end
	-- luacheck: pop
end)
local db = ns.db

-- Whether the view distance's look runs: the old code's ticker (made in
-- Graphics.lua, never stopped), or a feature loop's on its frame.
local function Ours(t)
	if t.cancelled then return false end
	if t.src:find("Graphics.lua", 1, true) then return true end
	for i = 1, 20 do
		local name, value = debug.getupvalue(t.fn, i)
		if not name then break end
		if name == "loop" and type(value) == "table" and value.frame ~= nil
			and value.frame == rawget(_G, "CinematicRainView") then
			return true
		end
	end
	return false
end
local function Running()
	for _, t in ipairs(tickers) do
		if Ours(t) then return true end
	end
	return false
end
-- Seconds of looks: each live ticker once a second (every one, as the game would).
local function Run(seconds)
	for _ = 1, seconds do
		now = now + 1
		ns.SyncFeatureLoops()
		local live = {}
		for _, t in ipairs(tickers) do if Ours(t) then live[#live + 1] = t end end
		for _, t in ipairs(live) do
			if not t.cancelled then pcall(t.fn, t) end
		end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "rainview-loop",
	fixed = { client = client },
	dims = {
		{ "before", { "none", "in", "preview" } },
		{ "scale", { "zero", "up" } },
		{ "cine", { "on", "off" } },
		{ "rain", { "yes", "no" } },
	},
	cell = function(c)
		db.enabled, db.visualEffects = true, true
		local raining = false
		ns.BadWeatherIntensity = function() return raining and 1 or 0 end
		-- (From yours each cell: out of CineMode, all the way back out.)
		db.rainViewScale, db.weatherPage, ns.lastCinematic = 1, true, false
		Run(12)
		if c.before == "in" then
			raining, ns.lastCinematic = true, true
			Run(12)
		elseif c.before == "preview" then
			ns.PreviewRainView(1) -- (the Weather page's Preview: in at once, out after its second)
		end
		db.rainViewScale = c.scale == "up" and 1 or 0
		ns.lastCinematic = c.cine == "on"
		raining = c.rain == "yes"
		Run(2)
		local loop = Running()
		local view = cvars.horizonStart == "3000" and "yours" or "in"
		-- (Put back for the next cell.)
		db.rainViewScale, db.weatherPage, ns.lastCinematic, raining = 1, true, false, false
		Run(12)
		return ("loop=%s view=%s"):format(loop and "on" or "off", view)
	end,
	pins = {
		-- (Nothing it can do: no look.)
		{ "", "loop=off view=yours" },
		{ "scale=up cine=on rain=yes", "loop=on view=in" },
		-- (Brought in before: still coming back out after 2 seconds, so still looking.)
		{ "before=in", "loop=on view=in" },
	},
})
