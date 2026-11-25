-- The Hover Groups page's switch over the groups' events, not just hovering
-- (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-hover-groups-page.md):
--   python -I Tools/offline/run.py Tools/offline/hoverpagematrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/hoverpagematrix.lua forever --base <ref>
-- A Hover group of the minimap with Chat message ticked, the page on or
-- off, then a frames pass in CineMode with a chat window peeking or not.
-- Each cell: how many groups the pass used (the ones handed to the unit
-- frames' parts), how many were up, and how often their reach was read.
-- The rule (the user's, 2026-11-25): page off = all off, no group pulls its
-- members up by any event either.
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
local now = 100
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	GetTime = function() return now end
	InCombatLockdown = function() return false end
	UnitAffectingCombat = function() return false end
	MouseIsOver = function() return false end
	UnitIsDeadOrGhost = function() return false end
	UnitIsDead = function() return false end
	UnitIsGhost = function() return false end
	GetMouseFoci = function() return {} end
	ChatEdit_GetActiveWindow = function() return nil end
	C_Minimap = setmetatable({ GetNumTrackingTypes = function() return 0 end },
		{ __index = function() return function() end end })
end)
local chat = CreateFrame("Frame", "ChatFrame1", UIParent)
rawset(_G, "DEFAULT_CHAT_FRAME", chat)
local db = ns.db
db.handleFrames = true
ns.MarkChatHolders = function() end
ns.IsChatActive = function() return false end
ns.EditModeActive = function() return false end
db.hoverGroups = { { name = "test", members = { "minimap" }, triggers = { chat = true } } }
local used, up, reach = 0, 0, 0
local partsOff, groupReach = ns.SetUnitPartsOff, ns.HoverGroupReach
ns.SetUnitPartsOff = function(groups, groupsUp, ...)
	used = #groups
	up = 0
	for _ in pairs(groupsUp or {}) do up = up + 1 end
	return partsOff(groups, groupsUp, ...)
end
ns.HoverGroupReach = function(...)
	reach = reach + 1
	return groupReach(...)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "hover-groups-page",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "event", { "chat", "none" } },
	},
	cell = function(c)
		db.mouseover = c.page == "on"
		now = now + 30
		wipe(ns.chatPeekUntil)
		if c.event == "chat" then ns.chatPeekUntil[chat] = now + 10 end
		used, up, reach = -1, -1, 0
		local ok, err = pcall(ns.UpdateFrames, true, 0.05)
		wipe(ns.chatPeekUntil)
		db.mouseover = true
		if not ok then return "pass: " .. tostring(err) end
		return ("groups=%d up=%d reach=%d"):format(used, up, reach)
	end,
	pins = {
		{ "page=off", "groups=0 up=0 reach=0" },
		{ "page=on event=chat", "groups=1 up=1 reach=1" },
		{ "page=on event=none", "groups=1 up=0 reach=1" },
	},
})
-- luacheck: pop
