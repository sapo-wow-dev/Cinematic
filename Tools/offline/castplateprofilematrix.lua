-- The nameplates' own cast bar settings in profiles, share strings and backups, every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-26-cast-plate-profiles.md):
--   python -I Tools/offline/run.py Tools/offline/castplateprofilematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/castplateprofilematrix.lua forever --base <ref>
-- Cast Bars' Nameplates settings are each the nameplates' own (<key>_PLATE) or, empty,
-- Default's (PlateCastStyle.lua's View). Since 679e735 they have no DEFAULTS entry, and the
-- profile code went over DEFAULTS alone. The states: which setting (the nameplates' own,
-- Target & focus's own: a neighbor that always had a default), whether the profile has one
-- of its own (a value, or none), and what's done: switch away and back, switch to another
-- profile, the Profiles page's "(changed)", an export imported, an older string that has
-- it, a backup restored, Reset profile, Reset Settings (a built-in keeps only what you made
-- in it). Each cell: the setting after (mine: the value set; follows: empty, Default's;
-- default: Default's default value), or what the page says / the string skipped.
-- The rule: they behave like every other setting.

local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
ns.SwitchProfileLayout = function() end -- (the stand-in has no Edit Mode)
for _, name in ipairs({ "RefreshOptions", "BuildManagedList", "RestartTimers", "RefreshTint", "ApplyBubbles",
	"ApplyUnitFrameParts", "RefreshActionBarStyle", "RefreshMinimapStyle", "RefreshQuestTrackerStyle",
	"RefreshInterfaceRecolor", "ApplyShoulderCam", "ApplyWheelSwitches", "ApplyFrameLinks",
	"SplitAddonRows", "Reload", "ResetLayouts" }) do
	if ns[name] then ns[name] = function() end end
end
ns.ResetLayouts = function() return true end
db.profiles = db.profiles or {}

local BASE = "plateCastBorderR"
local KEYS = { plate = BASE .. "_PLATE", target = BASE .. "_TARGET" }
local MINE = 0.37 -- (no profile's)
local function Word(_, value)
	if value == MINE then return "mine" end
	if value == nil then return "follows" end
	if value == ns.DEFAULTS[BASE] then return "default" end
	return tostring(value)
end

-- (Before an import or restore: the live one back to none, so what the new profile gets is
-- what came with it, not what the live settings still had.)
local function Unset(c)
	db[KEYS[c.key]] = c.key == "target" and ns.DEFAULTS[BASE] or nil
end

local n = 0
local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "cast-plate-profiles",
	fixed = { client = client },
	dims = {
		{ "key", { "plate", "target" } },
		{ "own", { "set", "none" } },
		{ "path", { "switchback", "carry", "changed", "export", "oldstring", "backup", "reset", "resetsettings" } },
	},
	cell = function(c)
		n = n + 1
		local key = KEYS[c.key]
		local name, other = "Balanced", "Subtle"
		-- (Each cell from a clean start: both profiles saved with nothing of either key.)
		if ns.ActiveProfile() ~= name then ns.SetProfile(name) end
		ns.ResetProfile()
		db[KEYS.plate], db[KEYS.target] = nil, ns.DEFAULTS[BASE]
		ns.SaveProfile()
		db.profiles[other] = nil
		local changedBefore = ns.ProfileChanged()
		if c.own == "set" then db[key] = MINE end
		if c.path == "switchback" then
			ns.SetProfile(other)
			ns.SetProfile(name)
			return Word(key, db[key])
		elseif c.path == "carry" then
			ns.SetProfile(other)
			return Word(key, db[key])
		elseif c.path == "changed" then
			return ("changed=%s"):format(changedBefore and "already" or ns.ProfileChanged() and "yes" or "no")
		elseif c.path == "export" then
			local read, why = ns.ReadSharedProfile(ns.ExportProfile(name))
			if not read then return "not read: " .. tostring(why) end
			Unset(c)
			if not ns.AddSharedProfile("Cast" .. n, read.settings) then return "not added" end
			return Word(key, db[key])
		elseif c.path == "oldstring" then
			-- (A string made before 679e735 has the key whenever the player had changed it.)
			local settings = { mouseover = true }
			if c.own == "set" then settings[key] = MINE end
			local text = ns.PackShared("CINE", 1, { format = 1, version = "v2.1.30", name = "Old" .. n, settings = settings })
			local read, why = ns.ReadSharedProfile(text)
			if not read then return "not read: " .. tostring(why) end
			Unset(c)
			if not ns.AddSharedProfile("Old" .. n, read.settings) then return "not added" end
			return ("%s skipped=%d"):format(Word(key, db[key]), read.skipped)
		elseif c.path == "backup" then
			ns.SaveProfile()
			db.profileBackups = {}
			ns.BackupProfile(name, "daily")
			Unset(c)
			local restored = ns.RestoreBackup(name, 1)
			if not restored then return "not restored" end
			return Word(key, db[key])
		elseif c.path == "reset" then
			ns.ResetProfile()
			return Word(key, db[key])
		elseif c.path == "resetsettings" then
			ns.SaveProfile()
			local live = CinematicDB -- luacheck: ignore 113
			ns.ResetAddon(true)
			local kept = CinematicDB and CinematicDB.profiles and CinematicDB.profiles[name] -- luacheck: ignore 113
			CinematicDB = live -- luacheck: ignore 111 113
			return "kept=" .. Word(key, kept and kept[key])
		end
	end,
	pins = {
		-- (What you set stays with the profile, and comes along.)
		{ "own=set", "mine" },
		{ "own=none key=plate", "follows" },
		{ "own=none key=target", "default" },
		-- (Another profile doesn't get it.)
		{ "path=carry key=plate", "follows" },
		{ "path=carry key=target", "default" },
		{ "path=changed own=set", "changed=yes" },
		{ "path=changed own=none", "changed=no" },
		{ "path=oldstring own=set", "mine skipped=0" },
		{ "path=oldstring own=none key=plate", "follows skipped=0" },
		{ "path=oldstring own=none key=target", "default skipped=0" },
		-- (Reset: back to the built-in's, which has none.)
		{ "path=reset key=plate", "follows" },
		{ "path=reset key=target", "default" },
		-- (Reset Settings: a built-in keeps only what you made in it, not settings.)
		{ "path=resetsettings", "kept=follows" },
	},
})
