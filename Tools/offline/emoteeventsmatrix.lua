-- Emote Vision's event watcher (Visions/EmoteVision.lua) with the vision on or
-- off (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-emote-events-off.md):
--   python -I Tools/offline/run.py Tools/offline/emoteeventsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/emoteeventsmatrix.lua forever --base <ref>
-- Emote Vision on, off, or off then on again (an event while off, then the
-- one tested); the event: an aura change on you (a buff added and one
-- refreshed), a fight's end, the group changing. Each cell: whether the
-- watcher read anything (auras, the group's GUIDs and levels). The rule: off,
-- none of that is read; on (and back on), it is.
local client = arg and arg[1] or "forever"
local reads = 0
local function Count(result)
	return function(...)
		reads = reads + 1
		if type(result) == "function" then return result(...) end
		return result
	end
end
local function Install()
	-- luacheck: push ignore 111 112 113 121 122
	UnitAffectingCombat = function() return false end
	UnitIsDeadOrGhost = function() return false end
	IsInRaid = function() return false end
	IsInGroup = function() return true end
	UnitAura = Count(nil)
	UnitGUID = Count(function(unit) return unit == "party1" and "Player-1-0001" or nil end)
	UnitLevel = Count(60)
	C_UnitAuras = {
		GetAuraDataByIndex = Count(nil),
		GetAuraDataByAuraInstanceID = Count(function(_, id)
			return { auraInstanceID = id, isHelpful = true, expirationTime = 500, name = "Fort" }
		end),
	}
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db

-- (The watcher: the frame EmoteVision.lua made for UNIT_AURA and the emote
-- lines; its handler called alone, so other features' frames read nothing.)
local watcher
for _, frame in ipairs(wow.frames) do
	local onEvent = frame._scripts and frame._scripts.OnEvent
	local info = onEvent and debug.getinfo(onEvent, "S")
	if info and info.source:find("EmoteVision.lua", 1, true) and frame._events.UNIT_AURA
		and frame._events.CHAT_MSG_TEXT_EMOTE then
		watcher = frame
	end
end
assert(watcher, "no Emote Vision watcher")
local function Send(event, ...)
	pcall(watcher._scripts.OnEvent, watcher, event, ...)
end
local EVENTS = {
	aura = { "UNIT_AURA", "player", { isFullUpdate = false, updatedAuraInstanceIDs = { 7 },
		addedAuras = { { auraInstanceID = 8, name = "Mark", expirationTime = 600, isHelpful = true } } } },
	fightEnds = { "PLAYER_REGEN_ENABLED" },
	roster = { "GROUP_ROSTER_UPDATE" },
}

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "emote-events",
	fixed = { client = client },
	dims = {
		{ "vision", { "on", "off", "offThenOn" } },
		{ "event", { "aura", "fightEnds", "roster" } },
	},
	cell = function(c)
		db.enabled, db.visions = true, true
		db.emoteVision = c.vision == "on"
		local each = EVENTS[c.event]
		if c.vision == "offThenOn" then
			Send(unpack(each))
			db.emoteVision = true
		end
		reads = 0
		Send(unpack(each))
		return "read=" .. (reads > 0 and "yes" or "no")
	end,
	pins = {
		{ "", "read=yes" },
		{ "vision=off", "read=no" },
	},
})
