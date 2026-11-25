-- Unit Frames Style's and Action Bar Style's watchers with their pages off
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-style-page-watchers.md):
--   python -I Tools/offline/run.py Tools/offline/stylehooksmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/stylehooksmatrix.lua forever --base <ref>
-- Each cell a login of its own (its page saved on or off), on the settings of
-- a first login (its once-only updates done).
-- unit-style-watch: Unit Frames Style on, off from the login, or on then off
-- (and settled: put back twice, as its refresh does); then the game says your
-- target changed (the watcher's refresh). Each cell: whether the frames were
-- dressed again (the refresh's work).
-- action-bar-watch: Action Bar Style's page on or off at login, its Shape
-- Round or Square, then switched off or not; an action button and a Cooldown
-- Manager viewer stand in. Each cell: whether your casts are watched (the
-- round glow's events) and whether the viewer's layout got hooked.
-- The rule (page off = no cost): work only while the page is on, or once to
-- put back what it had on.
local client = arg and arg[1] or "forever"
local saved -- (the first login's settings)
local tableHooks

local function Up(fn, wanted)
	for i = 1, 120 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		if name == wanted then return value, i end
	end
end

local function Login(settings)
	tableHooks = {}
	local function Install()
		-- luacheck: push ignore 111 112 113 121 122
		hooksecurefunc = function(a, b)
			if type(a) == "table" and type(b) == "string" then tableHooks[a] = (tableHooks[a] or 0) + 1 end
		end
		local viewer = CreateFrame("Frame", "EssentialCooldownViewer", UIParent)
		viewer.RefreshLayout = function() end
		_G.EssentialCooldownViewer = viewer
		CreateFrame("CheckButton", "ActionButton1", UIParent)
		if settings then
			CinematicDB = {}
			for key, value in pairs(saved) do CinematicDB[key] = value end
			for key, value in pairs(settings) do CinematicDB[key] = value end
		end
		-- luacheck: pop
	end
	local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
	return ns, wow
end
saved = Login().db

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "unit-style-watch",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "offFromStart", "onThenOff" } },
	},
	cell = function(c)
		local ns = Login({ styleGeneral = true, ufStyle = c.page ~= "offFromStart" })
		local db = ns.db
		-- (The refresh's work, counted where each frame's own game frames are listed.)
		local DressFrame = Up(ns.RefreshUnitStyle, "DressFrame")
		if not DressFrame then return "no stand-in" end
		local GameFrames, at = Up(DressFrame, "GameFrames")
		if not at then return "no stand-in" end
		local work = 0
		debug.setupvalue(DressFrame, at, function(...)
			work = work + 1
			return GameFrames(...)
		end)
		if c.page == "onThenOff" then
			ns.RefreshUnitStyle()
			db.ufStyle = false
			ns.RefreshUnitStyle()
			ns.RefreshUnitStyle(true) -- (its settling pass, a moment later)
		end
		work = 0
		ns.RefreshUnitStyle() -- (PLAYER_TARGET_CHANGED's)
		return work > 0 and "dressed" or "none"
	end,
	pins = {
		{ "", "none" },
		{ "page=on", "dressed" },
	},
})

Matrix.Run({
	name = "action-bar-watch",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "shape", { "round", "square" } },
		{ "after", { "kept", "pageOff" } },
	},
	cell = function(c)
		local ns, wow = Login({ styleGeneral = true, abStyle = c.page == "on", abShape = c.shape })
		local db = ns.db
		local castWatch
		for _, frame in ipairs(wow.frames) do
			local script = frame.GetScript and frame:GetScript("OnEvent")
			if script and Up(script, "SyncAllGlows") then castWatch = frame end
		end
		if not castWatch then return "no cast watcher" end
		ns.RefreshActionBarStyle()
		if c.after == "pageOff" then
			db.abStyle = false
			ns.RefreshActionBarStyle()
		end
		local casts = castWatch:IsEventRegistered("UNIT_SPELLCAST_START") and "watched" or "none"
		local hooked = (tableHooks[_G.EssentialCooldownViewer] or 0) > 0 and "hooked" or "none"
		return ("casts=%s viewer=%s"):format(casts, hooked)
	end,
	pins = {
		{ "", "casts=none viewer=none" },
		-- (Round once: the viewer hooked for good, a hook can't be taken off; it rests.)
		{ "page=on shape=round", "casts=none viewer=hooked" },
		{ "page=on shape=round after=kept", "casts=watched viewer=hooked" },
	},
})
