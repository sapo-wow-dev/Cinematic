-- Vitals Vision's low mana: its check loop (Atmosphere/ManaVision.lua), every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-mana-vision-loop.md):
--   python -I Tools/offline/run.py Tools/offline/manavisionloopmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/manavisionloopmatrix.lua --base <ref>
-- The Mana tab's setting on or off, the Vitals Vision page on or off, a
-- character with mana or none (a warrior), the page's Test running or not,
-- CineMode on or off, and the vision's "Allow outside CineMode" tick on or off.
-- Each cell: whether the check loop runs (an update loop on its frame) and
-- whether the overlay shows (mana at 10%).
-- The rule (release review 2026-11-23): the loop runs only while it can
-- show: the Test running, or the Mana tab on (with the page, and CineMode or
-- the Allow outside tick) for a character with mana. It ran every frame for
-- everyone. What shows doesn't change.
local client = arg and arg[1] or "forever"
local now = 100
local MAX, mana = 1000, 100
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	UnitPower = function() return mana end
	UnitPowerMax = function() return MAX end
	UnitIsDeadOrGhost = function() return false end
	UnitAffectingCombat = function() return false end
	InCombatLockdown = function() return false end
	-- (No curve API: the plain sums, the same on both clients.)
	C_CurveUtil = nil
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local TAB = ns.VITALS_MANA_TAB

-- The check loop: a frame's update loop made in ManaVision.lua that calls its
-- Update (its upvalues lead there: ns.SetOnUpdate's and ns.FeatureLoop's
-- wrappers both). (The pages' Test buttons and preview have loops of their
-- own there, which don't.)
local function CallsUpdate(f)
	for i = 1, 60 do
		local name = debug.getupvalue(f, i)
		if not name then return false end
		if name == "Update" then return true end
	end
	return false
end
local fromFile = {}
local function FromManaVision(fn)
	if fromFile[fn] ~= nil then return fromFile[fn] end
	local seen = {}
	local function Walk(f, depth)
		if depth > 8 or seen[f] or type(f) ~= "function" then return false end
		seen[f] = true
		local info = debug.getinfo(f, "S")
		if info and info.source and info.source:find("ManaVision.lua", 1, true) and CallsUpdate(f) then return true end
		for i = 1, 60 do
			local name, value = debug.getupvalue(f, i)
			if not name then break end
			if Walk(value, depth + 1) then return true end
		end
		return false
	end
	fromFile[fn] = Walk(fn, 0)
	return fromFile[fn]
end
local function Loops()
	local found = {}
	for _, frame in ipairs(wow.frames) do
		local update = frame._scripts and frame._scripts.OnUpdate
		if update and FromManaVision(update) then found[#found + 1] = { frame, update } end
	end
	return found
end
local function Run(seconds)
	local t = 0
	while t < seconds do
		t = t + 0.1
		now = now + 0.1
		for _, each in ipairs(Loops()) do pcall(each[2], each[1], 0.1) end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "manavision-loop",
	fixed = { client = client },
	dims = {
		{ "setting", { "on", "off" } },
		{ "page", { "on", "off" } },
		{ "mana", { "has", "none" } },
		{ "test", { "running", "no" } },
		{ "cine", { "on", "off" } },
		{ "outside", { "on", "off" } },
	},
	cell = function(c)
		-- (Nothing left over from the cell before: a quiet pass with it all off.)
		ns.StopManaVisionTest()
		db[TAB], db.lowHealth = false, true
		ns.lastCinematic = true
		ns.RefreshManaVision()
		ns.SyncFeatureLoops()
		Run(0.5)
		ns.SyncFeatureLoops()

		db.lowManaAlways = true
		db.lowHealth = c.page == "on"
		db[TAB] = c.setting == "on"
		db.outsideCineVitals = c.outside == "on"
		ns.lastCinematic = c.cine == "on" or nil
		ns.IsCineModeOn = function() return c.cine == "on" end
		MAX = c.mana == "has" and 1000 or 0
		mana = c.mana == "has" and 100 or 0
		if c.test == "running" then ns.TestManaVision() else ns.RefreshManaVision() end
		ns.SyncFeatureLoops() -- (the once-a-second gate)
		Run(1)
		local loop = #Loops() > 0
		local shown = ns.ManaVisionState().shown
		ns.StopManaVisionTest()
		return ("loop=%s shown=%s"):format(loop and "yes" or "no", shown and "yes" or "no")
	end,
	pins = {
		{ "", "loop=no shown=no" },
		{ "setting=on page=on mana=has cine=on", "loop=yes shown=yes" },
		{ "setting=on page=on mana=has outside=on", "loop=yes shown=yes" },
		{ "test=running", "loop=yes shown=yes" },
	},
})
