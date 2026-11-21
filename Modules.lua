-- Parts of the addon that can be left out, so their code never runs (no
-- frames, events, hooks or update loops): Visions, from its General page's
-- Load Visions switch (2026-11-21). One addon in the game's AddOns list, not
-- one per part.
--
-- A part's files load as every file does, but only their settings and data
-- run then (ns.DEFAULTS and the like: profiles, sharing and Reset keep them
-- with the part left out). The rest of each file is a function handed to
-- ns.Module. The saved settings arrive only once every file has run
-- (ADDON_LOADED), so those functions wait till then: ns.RunModules runs them
-- in .toc order as the first thing at ADDON_LOADED (Locales.lua calls it
-- before it sets the language, so they see what the files saw as they
-- loaded), each part's unless it's switched off.
--
-- The choice is CinematicDB.load<Part> (loadVisions = false: left out),
-- outside the profiles: a profile can't take a part away, and it needs a
-- /reload either way. Tools/offline/modules.lua checks both ways.
local _, ns = ...

-- name -> the CinematicDB key that leaves it out (false)
local PARTS = { visions = "loadVisions" }
ns.MODULE_KEYS = PARTS

-- What the rest of the addon asks a part as it plays, with that part left
-- out: "no", nothing done. (Every nameplate asks Quest Vision about its unit;
-- the panels tell Quest Talk where the game's window was.) Only ones called
-- without a check first: a check (if ns.X then) is left to find nothing.
local function No() return false end
local function Nothing() end
ns.MODULE_STAND_INS = {
	visions = { IsQuestMob = No, SoftPlateHidden = No, CardOn = No, SetQuestMark = Nothing, NoteTalkSpot = Nothing },
}

local queue = {}
local ran = false
local loaded = {} -- name -> true: its code ran (false: left out)

-- (ns.Guard isn't loaded yet: the error goes to the game's handler, as a
-- file's error as it loads would, and the other parts still run.)
local function Run(fn)
	xpcall(fn, function(err)
		local handler = geterrorhandler and geterrorhandler()
		if handler then handler(err) end
		return err
	end)
end

-- Whether the saved settings want this part (true before they arrive).
function ns.ModuleWanted(name)
	local key = PARTS[name]
	local db = _G.CinematicDB
	return not (key and type(db) == "table" and db[key] == false)
end

-- Whether this part's code is running (false: left out, or not yet started).
function ns.ModuleLoaded(name)
	return loaded[name] == true
end

-- fn: the rest of a part's file. (Handed in after the start, it runs now.)
function ns.Module(name, fn)
	assert(PARTS[name], "unknown module " .. tostring(name))
	if ran then
		if loaded[name] then Run(fn) end
		return
	end
	queue[#queue + 1] = { name = name, fn = fn }
end

-- fn: what another file does when this part is left out (takes away its
-- wheel slots, say), as the parts start. (Handed in after: runs now.)
local leftOut = {}
function ns.ModuleLeftOut(name, fn)
	assert(PARTS[name], "unknown module " .. tostring(name))
	if ran then
		if not loaded[name] then Run(fn) end
		return
	end
	leftOut[#leftOut + 1] = { name = name, fn = fn }
end

-- A part's settings: most of its files' DEFAULTS are set in the code that
-- waits, some deep in it (after frames and hooks). So the defaults a part
-- added are noted as it runs, written into the saved settings as it's
-- switched off (ns.SetModuleWanted: CinematicDB.moduleDefaults[name],
-- copies), and put back into ns.DEFAULTS while it's left out: the profiles
-- carry, save and reset every key in DEFAULTS, and would drop the part's
-- settings without them.
local function Copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = Copy(v) end
	return out
end
local added = {} -- name -> { key = default } this load, from its code

function ns.RunModules()
	if ran then return end
	ran = true
	-- (How things stood as they started, for /cine debug loadvisions: before
	-- Core.lua's ns.db and the language, as the files saw it when loading.)
	ns.moduleStart = { db = ns.db ~= nil, locale = ns.locale, combat = InCombatLockdown and InCombatLockdown() or false,
		saved = type(_G.CinematicDB) == "table" }
	for name in pairs(PARTS) do loaded[name] = ns.ModuleWanted(name) end
	local list = queue
	queue = nil
	local DEFAULTS = ns.DEFAULTS
	for _, each in ipairs(list) do
		if loaded[each.name] then
			local before = {}
			for k in pairs(DEFAULTS) do before[k] = true end
			Run(each.fn)
			local mine = added[each.name] or {}
			added[each.name] = mine
			for k, v in pairs(DEFAULTS) do
				if not before[k] and type(v) ~= "function" then mine[k] = Copy(v) end
			end
		end
	end
	local db = _G.CinematicDB
	local kept = type(db) == "table" and type(db.moduleDefaults) == "table" and db.moduleDefaults or {}
	for name in pairs(PARTS) do
		if not loaded[name] and type(kept[name]) == "table" then
			for k, v in pairs(kept[name]) do
				if DEFAULTS[k] == nil then DEFAULTS[k] = Copy(v) end
			end
		end
	end
	for _, each in ipairs(leftOut) do
		if not loaded[each.name] then Run(each.fn) end
	end
	leftOut = nil
	for name, list in pairs(ns.MODULE_STAND_INS) do
		if not loaded[name] then
			for key, fn in pairs(list) do
				if ns[key] == nil then ns[key] = fn end
			end
		end
	end
end

-- The settings pages each part has (their tabs' switches, tabOn:<page>:<n>,
-- are made as Options.lua builds them: kept with the part's own).
local PAGES = {
	visions = { "Heal Vision", "Damage Vision", "Quest Vision", "Roll Vision", "Duel Vision", "Emote Vision",
		"Card Vision", "Card Styles", "Damage Vision Look", "Quest Talk Style", "Quest Item Style", "Roll Style",
		"Visions Style" },
}

-- Leaves a part out from the next /reload (wanted false), or brings it back.
-- Its defaults are written down only now, while its code has run (2,000
-- and more for Visions: not kept in every player's saved settings), and
-- taken out again once it's loaded (below).
function ns.SetModuleWanted(name, wanted)
	local key = PARTS[name]
	local db = _G.CinematicDB
	if not key or type(db) ~= "table" then return end
	db[key] = wanted and true or false
	-- (Ticked again before a reload, still loaded: its code has its defaults, no copy.)
	if wanted and loaded[name] and type(db.moduleDefaults) == "table" then
		db.moduleDefaults[name] = nil
		if next(db.moduleDefaults) == nil then db.moduleDefaults = nil end
	end
	if wanted or not loaded[name] or not added[name] then return end
	local kept = {}
	for k, v in pairs(added[name]) do kept[k] = v end
	local page = {}
	for _, each in ipairs(PAGES[name] or {}) do page[each] = true end
	for k, v in pairs(ns.DEFAULTS) do
		local of = type(k) == "string" and k:match("^tabOn:(.-):[^:]*$")
		if of and page[of] and kept[k] == nil then kept[k] = Copy(v) end
	end
	if type(db.moduleDefaults) ~= "table" then db.moduleDefaults = {} end
	db.moduleDefaults[name] = kept
end

-- (Loaded again: its code has its defaults, the copy goes. At login:
-- CinematicDB is made at ADDON_LOADED, after the parts ran.)
local cleaner = CreateFrame("Frame")
cleaner:RegisterEvent("PLAYER_LOGIN")
cleaner:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	local db = _G.CinematicDB
	if type(db) ~= "table" or type(db.moduleDefaults) ~= "table" then return end
	for name in pairs(PARTS) do
		if loaded[name] then db.moduleDefaults[name] = nil end
	end
	if next(db.moduleDefaults) == nil then db.moduleDefaults = nil end
end)
