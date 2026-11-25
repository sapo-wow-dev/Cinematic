-- The Nameplates and Names icons' tabs switched off (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-plates-names-tabs.md):
--   python -I Tools/offline/run.py Tools/offline/platetabsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/platetabsmatrix.lua forever --base <ref>
-- Each tab (tabOn:Nameplates:<key>, a right-click on it) on or off, a
-- representative row of it ticked (Always) or not, in a fight or not, in
-- CineMode with both pages on. Each cell: what the tab's rows decide now,
-- through the readers the plates and names go by: a kind's or a unit row's
-- plate (up/down), a part (shown/hidden), your target's plate kept up or held
-- down, friendly plates switched off in dungeons and raids, a names row kept
-- (yes/no) and its names over heads held off by CineMode or the game's own.
-- The rule (audit 2026-11-25, C1): a tab off = none of its rows hides or adds
-- anything: its units are the game's, as with the page's own switch off. A
-- kind's plates as the game's own settings show them (here: shown), a part
-- shown, a unit row (your pet, your target, the raid marker row) adding
-- nothing and holding nothing down, names left to the game's own settings and
-- none kept on plates by those rows. The other tabs' rows as before.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
local now, locked = 1000, false
local cvars = {}
local function Install()
	GetTime = function() return now end
	InCombatLockdown = function() return locked end
	UnitAffectingCombat = function() return locked end
	GetCVar = function(name) return cvars[name] or "1" end
	SetCVar = function(name, value) cvars[name] = tostring(value) end
	C_CVar = C_CVar or {}
	C_CVar.GetCVar, C_CVar.SetCVar = GetCVar, SetCVar
end
-- luacheck: pop
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.enabled, db.handlePlates, db.handleNames = true, true, true
db.frameRules = db.frameRules or {}
local suffix = nil
ns.PlateSuffix = function() return suffix end
ns.IsPvPFlagged = function() return false end
ns.InGroup = function() return false end
ns.HasTarget = function() return true end

-- A local function of Effects.lua by name, through the upvalues of the
-- functions it hands out (the same on the old code and the new).
local function Find(name, from)
	local seen, queue = {}, {}
	for _, fn in ipairs(from) do queue[#queue + 1] = fn end
	while #queue > 0 do
		local fn = table.remove(queue, 1)
		if type(fn) == "function" and not seen[fn] then
			seen[fn] = true
			for i = 1, 255 do
				local n, v = debug.getupvalue(fn, i)
				if not n then break end
				if n == name then return v, fn, i end
				if type(v) == "function" then queue[#queue + 1] = v end
			end
		end
	end
end
local ROOTS = { ns.UpdatePlates, ns.UpdateCVars, ns.PlateItemsWhy, ns.PlatesWhy, ns.DescribePlateNameKept }
local function SetUp(name, value)
	local seen, queue = {}, {}
	for _, fn in ipairs(ROOTS) do queue[#queue + 1] = fn end
	while #queue > 0 do
		local fn = table.remove(queue, 1)
		if type(fn) == "function" and not seen[fn] then
			seen[fn] = true
			for i = 1, 255 do
				local n, v = debug.getupvalue(fn, i)
				if not n then break end
				if n == name then debug.setupvalue(fn, i, value) end
				if type(v) == "function" then queue[#queue + 1] = v end
			end
		end
	end
end
local NameKeptHere = Find("NameKeptHere", ROOTS)
local CVAR_SETS = Find("CVAR_SETS", ROOTS)
local TargetHeldDown = Find("TargetHeldDown", ROOTS)
local UpdateLockedPlates = Find("UpdateLockedPlates", ROOTS)
assert(NameKeptHere and CVAR_SETS and TargetHeldDown and UpdateLockedPlates, "a reader not found")
SetUp("platesActive", true)
SetUp("TargetRow", function() return "MyEnemyNPCTarget" end)
local function NameSet(key)
	for _, set in ipairs(CVAR_SETS) do
		if set.key == key then return set end
	end
end

local TABS = { "Enemy", "Friendly", "Instances", "Parts", "Target", "NamesPlayers", "Names", "NamesService",
	"NamesExtras", "NamesTarget" }
-- Each tab's representative rows (ticked: Always) and what to read.
local PLATE_PREFIXES = { "plateAlways", "plateGroup", "plateCombat", "plateCombatPvP", "plateCinematic",
	"plateInCities", "plateInInstances", "plateInPvP", "plateInBGs", "plateTargetEnemy", "plateTargetFriendly" }
local NAME_PREFIXES = { "nameAlways", "nameGroup", "nameCombat", "nameCombatPvP", "nameKeep", "nameInCities",
	"nameInInstances", "nameInPvP", "nameInBGs", "nameTargetEnemy", "nameTargetFriendly" }
local PLATE_ROWS = { "Enemies", "PartEnemiesHealth", "Friends", "MyPet", "PartHealth", "YourTarget", "PartMarker" }
local NAME_ROWS = { "Friends", "HostileNPCs", "FriendlyNPCs", "ServiceNPCs", "Guild", "YourTarget" }
local function Plate(row) return ns.PlateRowWanted(row) and "up" or "down" end
local function Kept(key) return NameKeptHere(key, locked) and "yes" or "no" end
local function Over(key)
	local set = NameSet(key)
	return set and (set.active and "hidden" or "game") or "none"
end
local READ = {
	Enemy = function() return ("plate=%s part=%s"):format(Plate("Enemies"), Plate("PartEnemiesHealth")) end,
	Friendly = function() return ("plate=%s pet=%s"):format(Plate("Friends"), Plate("MyPet")) end,
	Instances = function()
		UpdateLockedPlates()
		return "locked=" .. (ns.LOCKED_PLATE_SETS.Friends.active and "off" or "game")
	end,
	Parts = function() return "part=" .. Plate("PartHealth") end,
	Target = function() return ("kept=%s held=%s"):format(Plate("YourTarget"), TargetHeldDown() and "down" or "no") end,
	NamesPlayers = function() return ("kept=%s names=%s"):format(Kept("Friends"), Over("Friends")) end,
	Names = function() return ("kept=%s names=%s"):format(Kept("HostileNPCs"), Over("HostileNPCs")) end,
	NamesService = function() return ("kept=%s names=%s"):format(Kept("FriendlyNPCs"), Over("InteractiveNPCs")) end,
	NamesExtras = function()
		return ("kept=%s names=%s marker=%s"):format(Kept("Guild"), Over("Guild"), Plate("PartMarker"))
	end,
	NamesTarget = function() return ("kept=%s names=%s"):format(Kept("YourTarget"), Over("Target")) end,
}
local TICK = {
	Enemy = function(on)
		db.plateAlwaysEnemies, db.plateAlwaysPartEnemiesHealth, db.plateOwnPartsEnemies = on, on, true
	end,
	Friendly = function(on) db.plateAlwaysFriends, db.plateAlwaysMyPet = on, on end,
	Instances = function(on)
		db.plateInstanceFriends = on and "hide" or "show"
		db.plateInstanceFriendlyMinions = on and "hide" or "show"
	end,
	Parts = function(on) db.plateAlwaysPartHealth = on end,
	Target = function(on) db.plateAlwaysYourTarget = on end,
	NamesPlayers = function(on) db.nameAlwaysFriends = on end,
	Names = function(on) db.nameAlwaysHostileNPCs = on end,
	NamesService = function(on) db.nameAlwaysFriendlyNPCs = on end,
	NamesExtras = function(on) db.nameAlwaysGuild, db.plateAlwaysPartMarker = on, on end,
	NamesTarget = function(on) db.nameAlwaysYourTarget = on end,
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "plates-names-tabs",
	fixed = { client = client, cine = "on" },
	dims = {
		{ "tab", TABS },
		{ "tabState", { "on", "off" } },
		{ "row", { "on", "off" } },
		{ "fight", { "no", "yes" } },
	},
	cell = function(c)
		-- (Every cell from the same start: out of a fight, every tab on, every
		-- row read here unticked, no rules, CineMode's name settings let go.)
		now = now + 10
		locked = false
		suffix = nil
		for _, tab in ipairs(TABS) do db["tabOn:Nameplates:" .. tab] = true end
		for _, row in ipairs(PLATE_ROWS) do
			for _, prefix in ipairs(PLATE_PREFIXES) do db[prefix .. row] = false end
			db.frameRules["plate:" .. row] = nil
		end
		for _, row in ipairs(NAME_ROWS) do
			for _, prefix in ipairs(NAME_PREFIXES) do db[prefix .. row] = false end
			db.frameRules["name:" .. row] = nil
		end
		db.nameAlwaysAllNames = true
		db.plateOwnPartsEnemies = false
		for _, tick in pairs(TICK) do tick(false) end
		for _, set in ipairs(CVAR_SETS) do ns.ApplyCVarSet(set, false) end
		for _, set in pairs(ns.LOCKED_PLATE_SETS) do ns.ApplyCVarSet(set, false) end
		-- (The cell's own.)
		TICK[c.tab](c.row == "on")
		db["tabOn:Nameplates:" .. c.tab] = c.tabState == "on"
		if c.tab == "Instances" then suffix = "Instances" end
		SetUp("placeSuffix", suffix)
		locked = c.fight == "yes"
		now = now + 1
		ns.cvarsSeen.at = -math.huge
		ns.UpdateCVars(true)
		return READ[c.tab]()
	end,
	pins = {
		-- (Tabs on: each row as it's ticked.)
		{ "tab=Enemy tabState=on row=on", "plate=up part=up" },
		{ "tab=Enemy tabState=on row=off", "plate=down part=down" },
		{ "tab=Friendly tabState=on row=on", "plate=up pet=up" },
		{ "tab=Friendly tabState=on row=off", "plate=down pet=down" },
		{ "tab=Instances tabState=on row=on fight=no", "locked=off" },
		{ "tab=Instances tabState=on row=off", "locked=game" },
		{ "tab=Instances fight=yes", "locked=game" }, -- (plate settings can't change in a fight)
		{ "tab=Parts tabState=on row=on", "part=up" },
		{ "tab=Parts tabState=on row=off", "part=down" },
		{ "tab=Target tabState=on row=on", "kept=up held=no" },
		{ "tab=Target tabState=on row=off", "kept=down held=down" },
		{ "tabState=on row=on tab=NamesPlayers", "kept=yes names=game" },
		{ "tabState=on row=on tab=Names", "kept=yes names=game" },
		{ "tabState=on row=on tab=NamesService", "kept=yes names=game" },
		{ "tabState=on row=on tab=NamesTarget", "kept=yes names=game" },
		{ "tabState=on row=on tab=NamesExtras", "kept=yes names=game marker=up" },
		{ "tabState=on row=off tab=NamesPlayers fight=no", "kept=no names=hidden" },
		{ "tabState=on row=off tab=Names fight=no", "kept=no names=hidden" },
		{ "tabState=on row=off tab=NamesService fight=no", "kept=no names=hidden" },
		{ "tabState=on row=off tab=NamesTarget fight=no", "kept=no names=hidden" },
		{ "tabState=on row=off tab=NamesExtras fight=no", "kept=no names=hidden marker=down" },
		-- (In a fight the game holds name settings: as the fight found them.)
		{ "tabState=on row=off tab=NamesPlayers fight=yes", "kept=no names=game" },
		{ "tabState=on row=off tab=Names fight=yes", "kept=no names=game" },
		{ "tabState=on row=off tab=NamesService fight=yes", "kept=no names=game" },
		{ "tabState=on row=off tab=NamesTarget fight=yes", "kept=no names=game" },
		{ "tabState=on row=off tab=NamesExtras fight=yes", "kept=no names=game marker=down" },
		-- (A tab off: its units the game's, whatever its rows say. Kinds' plates
		-- as the game shows them (its settings here: shown), parts shown, unit
		-- rows adding and holding nothing, names neither held off nor kept.)
		{ "tab=Enemy tabState=off", "plate=up part=up" },
		{ "tab=Friendly tabState=off", "plate=up pet=down" },
		{ "tab=Instances tabState=off", "locked=game" },
		{ "tab=Parts tabState=off", "part=up" },
		{ "tab=Target tabState=off", "kept=down held=no" },
		{ "tabState=off tab=NamesPlayers", "kept=no names=game" },
		{ "tabState=off tab=Names", "kept=no names=game" },
		{ "tabState=off tab=NamesService", "kept=no names=game" },
		{ "tabState=off tab=NamesTarget", "kept=no names=game" },
		{ "tabState=off tab=NamesExtras", "kept=no names=game marker=down" },
		-- (Interactive NPCs' names: off wherever CineMode keeps every plate on,
		-- whatever the rows say, its plates showing them. Not a row's doing.)
		{ "tabState=on row=on tab=NamesService fight=no", "kept=yes names=hidden" },
		{ "tabState=off tab=NamesService fight=no", "kept=no names=hidden" },
	},
})
