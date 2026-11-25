-- Quest Vision's cast watcher (Visions/QuestMobs.lua: an NPC you used a
-- quest's item on counts as done), every state (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-quest-cast-watch.md):
--   python -I Tools/offline/run.py Tools/offline/questcastmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/questcastmatrix.lua forever --base <ref>
-- Quest Vision on or off, a quest in your log with an item to use or none;
-- a spell cast at your target. Each cell: whether the cast's target was
-- looked at (ns.IsQuestMob asked: its tooltip read). The rule: only with an
-- item quest in the log, the only time a cast can mark an NPC done; then
-- whatever Quest Vision says, as the quest-mob answer it keeps right is also
-- read by the plates' Quest mobs row, the plate level and the tooltips.
local client = arg and arg[1] or "forever"
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	UnitGUID = function(unit) return unit == "target" and "Creature-0-1-2-3-4-5" or nil end
	UnitName = function(unit) return unit == "target" and "Channeler" or nil end
	UnitIsDead = function() return false end
	GetItemSpell = function() return "Use", 99 end
	C_Item = { GetItemSpell = GetItemSpell }
	C_QuestLog = { GetQuestObjectives = function() return { { numFulfilled = 0 } } end,
		IsOnQuest = function() return true end }
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
local items = {}
ns.QuestLogItems = function() return items end
local asked = 0
local realIsQuestMob = ns.IsQuestMob
ns.IsQuestMob = function(...)
	asked = asked + 1
	return realIsQuestMob(...)
end

local castWatcher
for _, frame in ipairs(wow.frames) do
	local onEvent = frame._scripts and frame._scripts.OnEvent
	local info = onEvent and debug.getinfo(onEvent, "S")
	if info and info.source:find("QuestMobs.lua", 1, true) and frame._events.UNIT_SPELLCAST_SENT then
		castWatcher = frame
	end
end
assert(castWatcher, "no cast watcher")

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "quest-cast-watch",
	fixed = { client = client },
	dims = {
		{ "vision", { "on", "off" } },
		{ "itemQuest", { "yes", "no" } },
	},
	cell = function(c)
		db.enabled, db.visions = true, true
		db.questVision = c.vision == "on"
		items = c.itemQuest == "yes" and { { questID = 1, itemID = 5 } } or {}
		wow.Fire("QUEST_LOG_UPDATE") -- (the item quests read again)
		asked = 0
		pcall(castWatcher._scripts.OnEvent, castWatcher, "UNIT_SPELLCAST_SENT", "player", "Channeler", "cast-1", 99)
		return "looked=" .. (asked > 0 and "yes" or "no")
	end,
	pins = {
		{ "itemQuest=yes", "looked=yes" },
		{ "itemQuest=no", "looked=no" },
	},
})
