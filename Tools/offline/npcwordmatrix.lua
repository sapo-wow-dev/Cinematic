-- Where a rule's old npc word turns into interacting, every place it's kept
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-24-npc-word-everywhere.md):
--   python -I Tools/offline/run.py Tools/offline/npcwordmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/npcwordmatrix.lua --base <ref>
-- A rule "not npc" kept in: the live settings, a saved profile, a backup, a
-- deleted profile's backup (each through the once-only update), a profile
-- string or a camera trigger string, made before (no npcWord) or now. Each
-- cell: the rule's text once loaded or read.
-- The rule (2026-11-24): everything from before npc meant a targeted NPC reads
-- interacting; strings made from now on keep npc.
-- luacheck: push ignore 111 112 113 121 122 212
local client = arg and arg[1] or "forever"
local ns = dofile("Tools/offline/load.lua")(client, "Cinematic.toc")
local Matrix = dofile("Tools/offline/matrix.lua")
local db = ns.db
local KEY = "effect:inn"

local function Migrated(place)
	db.profiles.MatrixSaved, db.profileBackups, db.deletedProfiles = nil, {}, {}
	local rules = { [KEY] = "not npc" }
	local wasLive = db.frameRules[KEY]
	if place == "live" then db.frameRules[KEY] = "not npc"
	elseif place == "profile" then db.profiles.MatrixSaved = { settings = { frameRules = rules } }
	elseif place == "backup" then db.profileBackups.MatrixSaved = { { time = 1, settings = { frameRules = rules } } }
	else db.deletedProfiles = { { name = "gone", backups = { { time = 1, settings = { frameRules = rules } } } } } end
	db.ruleNpcInteractingV1 = nil
	ns.RunMigrations()
	local out
	if place == "live" then out = db.frameRules[KEY]; db.frameRules[KEY] = wasLive
	elseif place == "profile" then out = db.profiles.MatrixSaved.settings.frameRules[KEY]
	elseif place == "backup" then out = db.profileBackups.MatrixSaved[1].settings.frameRules[KEY]
	else out = db.deletedProfiles[1].backups[1].settings.frameRules[KEY] end
	db.profiles.MatrixSaved, db.profileBackups, db.deletedProfiles = nil, {}, {}
	return out
end

local function Shared(place, made)
	local mark = made == "now" and "target" or nil
	if place == "string" then
		local read = ns.ReadSharedProfile(ns.PackShared("CINE", 1, { format = 1, version = "v", name = "M",
			npcWord = mark, settings = { frameRules = { [KEY] = "not npc" } } }))
		return read and read.settings.frameRules and read.settings.frameRules[KEY]
	end
	local read = ns.ReadCameraShare(ns.PackCameraShare({ kind = "trigger", name = "M", npcWord = mark,
		triggers = { t1 = "event:X" }, defs = { t1 = { name = "M", cond = "not npc" } } }))
	return read and read.defs and read.defs[1] and read.defs[1].cond
end

Matrix.Run({
	name = "npc-word-everywhere",
	fixed = { client = client },
	dims = { { "place", { "live", "profile", "backup", "deleted", "string", "camera" } }, { "made", { "before", "now" } } },
	cell = function(c)
		local text
		if c.place == "string" or c.place == "camera" then text = Shared(c.place, c.made)
		elseif c.made == "before" then text = Migrated(c.place)
		else return "n/a" end -- (saved from now on: written with the new words)
		return "rule=" .. tostring(text)
	end,
	pins = {
		{ "made=now", "n/a" },
		{ "made=before", "rule=not interacting" },
		{ "place=string made=now", "rule=not npc" },
		{ "place=camera made=now", "rule=not npc" },
	},
})
-- luacheck: pop
