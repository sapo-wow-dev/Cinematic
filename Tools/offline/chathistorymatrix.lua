-- Chat history at login by its tick and its page (the audit kit's matrix,
-- Tools/offline/matrix.lua; fix card Tools/audits/2026-11-25-chat-history-page.md):
--   python -I Tools/offline/run.py Tools/offline/chathistorymatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/chathistorymatrix.lua forever --base <ref>
-- A saved line from the last session, then the login with Keep chat history
-- ticked or not and the Quality of life page on or off. Each cell: whether
-- the line was shown again in the chat window and whether it's still saved.
-- The rule (2026-11-25): page off = the feature off (nothing shown, nothing
-- added), but what's saved stays while the tick itself is on; only the tick
-- off wipes it.
local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db
local shown
local frame = _G.ChatFrame1 or wow.CreateFrame("Frame", "ChatFrame1", UIParent)
rawset(frame, "AddMessage", function(_, text) if text == "a line from last time" then shown = true end end)

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "chat-history-login",
	fixed = { client = client },
	dims = {
		{ "tick", { "on", "off" } },
		{ "page", { "on", "off" } },
	},
	cell = function(c)
		shown = false
		ns.chardb.chatHistory = { [1] = { { time(), "a line from last time" } } }
		db.chatHistory = c.tick == "on"
		db.handleQuality = c.page == "on"
		wow.Fire("PLAYER_LOGIN")
		local kept = ns.chardb.chatHistory and ns.chardb.chatHistory[1] and #ns.chardb.chatHistory[1] > 0
		return ("shown=%s kept=%s"):format(shown and "yes" or "no", kept and "yes" or "no")
	end,
	pins = {
		{ "tick=on page=on", "shown=yes kept=yes" },
		{ "tick=on page=off", "shown=no kept=yes" },
		{ "tick=off", "shown=no kept=no" },
	},
})
