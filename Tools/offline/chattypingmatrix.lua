-- Typing brings the chat windows up, by the Chat page and its Conversations
-- tab (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-25-chat-typing-tab.md):
--   python -I Tools/offline/run.py Tools/offline/chattypingmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/chattypingmatrix.lua forever --base <ref>
-- In CineMode, the chat window faded out, then typing (the input box open)
-- with the Chat page on or off, its Conversations tab (where the Typing row
-- is) on or off, and the Typing row (Show chat while typing) on or off.
-- Each cell: the chat window up or down after a second of frame passes.
-- The rule (the user's): a tab is a container, off: all on it off (just the
-- input box comes up then, as with the row off).
-- luacheck: push ignore 111 112 113 121 122
local client = arg and arg[1] or "forever"
local now = 100
local typing = false
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
chat._alpha = 1
rawset(chat, "SetAlpha", function(self, alpha) self._alpha = alpha end)
rawset(chat, "GetAlpha", function(self) return self._alpha end)
rawset(chat, "IsMouseOver", function() return false end)
local db = ns.db
db.handleFrames, db.showInChat = true, true
db.mouseover = false
ns.MarkChatHolders = function() end
ns.IsChatActive = function() return typing end
ns.EditModeActive = function() return false end
pcall(ns.BuildManagedList)
local entry
for _, each in ipairs(ns.managed) do
	if each.frame == chat then entry = each end
end
local function Pass(times)
	for _ = 1, times do
		now = now + 0.05
		local ok, err = pcall(ns.UpdateFrames, true, 0.05)
		if not ok then return "pass: " .. tostring(err) end
	end
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "chat-typing",
	fixed = { client = client },
	dims = {
		{ "page", { "on", "off" } },
		{ "tab", { "on", "off" } },
		{ "row", { "on", "off" } },
	},
	cell = function(c)
		if not entry then return "chat not faded" end
		typing = false
		ns.chatTypingUntil = 0
		db.handleChat, db["tabOn:Chat/page:2"], db.chatShowWhileTyping = true, true, false
		local err = Pass(60)
		if err then return err end
		if entry.alpha > 0.05 then return "not faded to start: " .. tostring(entry.alpha) end
		db.handleChat, db["tabOn:Chat/page:2"] = c.page == "on", c.tab == "on"
		db.chatShowWhileTyping = c.row == "on"
		typing = true
		err = Pass(20)
		typing = false
		ns.chatTypingUntil = 0
		if err then return err end
		return entry.alpha > 0.5 and "up" or "down"
	end,
	pins = {
		{ "", "down" },
		{ "page=on tab=on row=on", "up" },
	},
})
-- luacheck: pop
