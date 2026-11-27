-- DaylightUI's Loot roll window row on an update (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-26-daylight-rolls-update.md):
--   python -I Tools/offline/run.py Tools/offline/dlrollsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/dlrollsmatrix.lua forever --base <ref>
-- A fresh install or one from before the row (3da7a12), with the row
-- unpicked or picked Theirs or Ours already; DaylightUI's own roll window
-- (Skins, rolls.enabled) on or off; Roll Vision's window (rollWindow) on or
-- off. The once-only updates run (Migrations.lua), then each cell: Roll
-- Vision's window at a roll (plays, aside for DaylightUI's, or off) and the
-- row's pick.
-- The rule (2026-11-26): players who had Cinematic before keep Roll Vision's
-- window (the row starts at Ours for them); fresh installs get the row's
-- default (Theirs); a pick made is kept.
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db

local skins = {}
rawset(_G, "DaylightUI", {
	Get = function(_, scope, path)
		if scope == "Skins" then return skins[path] end
		return nil
	end,
	GetModule = function(_, name) return name == "Skins" and { enabled = true } or nil end,
})
local IsLoaded = C_AddOns.IsAddOnLoaded
local loaded = { DaylightUI = true, DaylightUI_Skins = true }
C_AddOns.IsAddOnLoaded = function(addon) return loaded[addon] or IsLoaded(addon) end -- luacheck: ignore 122
for _, addon in ipairs({ "DaylightUI", "DaylightUI_Skins" }) do wow.Fire("ADDON_LOADED", addon) end

local function Row()
	for _, row in ipairs(ns.CONFLICTS) do
		if row.key == "rolls" and row.addon == "DaylightUI" then return row end
	end
end
local newInstall = ns.newInstall

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "dl-rolls-update",
	fixed = { client = client },
	dims = {
		{ "install", { "fresh", "existing" } },
		{ "pick", { "none", "theirs", "ours" } },
		{ "their", { "on", "off" } },
		{ "rollWindow", { "on", "off" } },
	},
	cell = function(c)
		local row = Row()
		-- (Code from before the row (3da7a12, v2.1.34 and older): an error, read as "old code
		-- errors", not a changed cell.)
		if not row then error("no DaylightUI Loot roll window row in this code (3da7a12)") end
		-- (As saved by the old version: no update of this release's done yet.)
		for key in pairs(db) do
			if type(key) == "string" and key:match("^daylightRolls.*V%d+$") then db[key] = nil end
		end
		db.conflictPicks = c.pick ~= "none" and { [row.id] = c.pick } or {}
		ns.newInstall = c.install == "fresh"
		ns.RunMigrations()
		ns.newInstall = newInstall
		skins["rolls.enabled"] = c.their == "on"
		db.rollWindow = c.rollWindow == "on"
		local state, pick = ns.ConflictState("rolls")
		local rv = not db.rollWindow and "off" or (state == row and pick == "theirs") and "aside" or "plays"
		return ("rv=%s pick=%s"):format(rv, (ns.ConflictPick(row)))
	end,
	pins = {
		-- (A pick made is kept.)
		{ "pick=ours", "rv=plays pick=ours" },
		{ "pick=theirs", "rv=aside pick=theirs" },
		-- (Fresh: the row's default, DaylightUI's window.)
		{ "pick=none install=fresh", "rv=aside pick=theirs" },
		-- (From before: Roll Vision's window kept, the row at Ours.)
		{ "pick=none install=existing", "rv=plays pick=ours" },
		-- (Its window off: no clash, Roll Vision's plays whatever the pick.)
		{ "pick=theirs their=off", "rv=plays pick=theirs" },
		{ "pick=none install=fresh their=off", "rv=plays pick=theirs" },
		-- (Roll Vision's window off: off.)
		{ "pick=ours rollWindow=off", "rv=off pick=ours" },
		{ "pick=theirs rollWindow=off", "rv=off pick=theirs" },
		{ "pick=none install=fresh rollWindow=off", "rv=off pick=theirs" },
		{ "pick=none install=existing rollWindow=off", "rv=off pick=ours" },
	},
})
C_AddOns.IsAddOnLoaded = IsLoaded -- luacheck: ignore 122
rawset(_G, "DaylightUI", nil)
