-- The Chat page's tabs over its message rows, every state (the audit kit's
-- matrix, Tools/offline/matrix.lua; fix card Tools/audits/2026-11-22-settings-chat-tabs.md):
--   python -I Tools/offline/run.py Tools/offline/chattabsmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/chattabsmatrix.lua --base <ref>
-- A message comes in (a whisper: the Conversations tab's Whispers row; a skill
-- up: the Game Messages tab's Skill ups row; a Trade channel line: the
-- Channels tab's Trade row) through the game's chat filter (ChatPeekFilter,
-- UI/Chat.lua). The Chat page made (opened once) or not, the page's switch,
-- the tabs (all on, the row's own tab off, another content tab off), and the
-- row's own Always or Never. Each cell: "peek" (the chat window shows for it)
-- or "none". The rule (the switch tree): peek only with the page, the row's
-- tab and the row all on; another tab off changes nothing.
-- (bdb2e1d audit 2026-11-22: the tabs were never read, a tab off did nothing.)

local client = arg and arg[1] or "forever"
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc")
local db = ns.db

local TABS = { conv = "tabOn:Chat/page:2", game = "tabOn:Chat/page:3", channel = "tabOn:Chat/page:4" }
local OTHER = { conv = "game", game = "channel", channel = "conv" }

-- The filter, and its peek (PeekUnlessBubble) swapped for a counter.
local function Upvalue(fn, name)
	for i = 1, 200 do
		local key, value = debug.getupvalue(fn, i)
		if not key then return end
		if key == name then return value, i end
	end
end
local Filter = Upvalue(ns.ChatTestFilter, "ChatPeekFilter")
local peeks = 0
if Filter then
	local _, index = Upvalue(Filter, "PeekUnlessBubble")
	if index then debug.setupvalue(Filter, index, function() peeks = peeks + 1 end) end
end
local chatFrame = wow.CreateFrame("Frame", "ChatTabsMatrixWindow")

local made = false
local function MakePage()
	if made then return end
	made = true
	for _, entry in ipairs(ns.lazySettingsPages or {}) do
		if entry.name == "Chat" and not entry.made then entry.Make("chattabsmatrix") end
	end
	if ns.MapTabContainers then ns.MapTabContainers() end -- (a timer in game)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "chattabs-rows",
	fixed = { client = client },
	dims = {
		{ "made", { "no", "yes" } }, -- (first: a page once made stays made)
		{ "row", { "conv", "game", "channel" } },
		{ "pageSwitch", { "on", "off" } },
		{ "tabs", { "allOn", "ownOff", "otherOff" } },
		{ "rowSet", { "always", "never" } },
	},
	cell = function(c)
		if not Filter then return "no filter" end
		if c.made == "yes" then MakePage() end
		db.handleFrames, db.handleChat, db.chatPeek = true, c.pageSwitch == "on", true
		db.chatHideOwn, db.chatHideBubbled = false, false
		for _, key in pairs(TABS) do db[key] = true end
		if c.tabs == "ownOff" then db[TABS[c.row]] = false end
		if c.tabs == "otherOff" then db[TABS[OTHER[c.row]]] = false end
		local on = c.rowSet == "always"
		db.chatPeekTypes.whisper, db.chatPeekTypes.skill, db.chatPeekChannelList.Trade = on, on, on
		peeks = 0
		if c.row == "conv" then
			Filter(chatFrame, "CHAT_MSG_WHISPER", "hello", "Someone-Realm", nil, "", nil, nil, nil, 0, "", nil, nil,
				"Player-1-00000001")
		elseif c.row == "game" then
			Filter(chatFrame, "CHAT_MSG_SKILL", "Your skill in Cooking has increased to 2.")
		else
			Filter(chatFrame, "CHAT_MSG_CHANNEL", "WTS stuff", "Someone-Realm", nil, "2. Trade - City", nil, nil, nil,
				2, "Trade", nil, nil, "Player-1-00000001")
		end
		for _, key in pairs(TABS) do db[key] = true end
		db.handleChat = true
		return peeks > 0 and "peek" or "none"
	end,
	pins = {
		{ "", "none" },
		{ "pageSwitch=on tabs=allOn rowSet=always", "peek" },
		{ "pageSwitch=on tabs=otherOff rowSet=always", "peek" },
	},
})
