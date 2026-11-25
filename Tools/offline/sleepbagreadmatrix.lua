-- The Sleeping bag line's aura reads (Visions/SleepingBag.lua, Forever), every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-sleep-bag-reads.md):
--   python -I Tools/offline/run.py Tools/offline/sleepbagreadmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/sleepbagreadmatrix.lua forever --base <ref>
-- The Cards page's Sleeping bag row on or off, Emote Vision's camp timer on
-- or off; then an aura change on you, or (both off at an aura change first)
-- the row or timer coming on with no aura change after. Each cell: whether
-- the bag's auras were read. The rule: read only while one of them can show
-- it, and once as one comes on. Retail: no bag, never read.
local client = arg and arg[1] or "forever"
local reads = 0
local tickers = {}
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	UnitAffectingCombat = function() return false end
	C_UnitAuras = { GetPlayerAuraBySpellID = function() reads = reads + 1 return nil end }
	C_Timer.NewTicker = function(_, fn)
		local handle = { fn = fn }
		function handle.Cancel() handle.cancelled = true end
		tickers[#tickers + 1] = handle
		return handle
	end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

local function FromFile(fn)
	local seen = {}
	local function Walk(f, depth)
		if depth > 6 or seen[f] or type(f) ~= "function" then return false end
		seen[f] = true
		local info = debug.getinfo(f, "S")
		if info and info.source and info.source:find("SleepingBag.lua", 1, true) then return true end
		for i = 1, 60 do
			local name, value = debug.getupvalue(f, i)
			if not name then break end
			if Walk(value, depth + 1) then return true end
			if type(value) == "table" and Walk(rawget(value, "run"), depth + 1) then return true end
		end
		return false
	end
	return Walk(fn, 0)
end
local watcher
for _, frame in ipairs(wow.frames) do
	if frame._events.UNIT_AURA and frame._events.UNIT_SPELLCAST_SUCCEEDED and frame._scripts.OnEvent
		and FromFile(frame._scripts.OnEvent) then
		watcher = frame
	end
end
assert(watcher, "no sleeping bag watcher")
local function Aura() pcall(watcher._scripts.OnEvent, watcher, "UNIT_AURA", "player") end
local function Tick()
	ns.SyncFeatureLoops()
	for _, handle in ipairs(tickers) do
		if not handle.cancelled and FromFile(handle.fn) then pcall(handle.fn) end
	end
	ns.SyncFeatureLoops()
end

local camp = false
ns.CampTimerOn = function() return camp end
local function Set(row, timer)
	db.enabled, db.visions, db.cards = true, true, true
	db.cardSleepBagOn = row
	camp = timer
end

local Matrix = dofile("Tools/offline/matrix.lua")
local pins = { { "", "read=yes" }, { "row=off camp=off", "read=no" } }
if client == "retail" then pins = { { "", "read=no" } } end
Matrix.Run({
	name = "sleep-bag-reads",
	fixed = { client = client },
	dims = {
		{ "row", { "on", "off" } },
		{ "camp", { "on", "off" } },
		{ "next", { "aura", "turnedOn" } },
	},
	cell = function(c)
		Set(false, false)
		Aura()
		Tick()
		Set(c.row == "on", c.camp == "on")
		reads = 0
		if c.next == "aura" then Aura() else Tick() end
		return "read=" .. (reads > 0 and "yes" or "no")
	end,
	pins = pins,
})
