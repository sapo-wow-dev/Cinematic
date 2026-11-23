-- Show just those messages: which window line a message's copy shows, every
-- state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-chat-copy-find-line.md):
--   python -I Tools/offline/run.py Tools/offline/chatfindmatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/chatfindmatrix.lua --base <ref>
-- A message comes in through the game's chat filter (ChatPeekFilter, UI/Chat.lua)
-- to a faded chat window: a whisper (plain words, a short "ok", a "?" with no
-- word, a quest link another addon rewrote) or an achievement (the game sends
-- "%s has earned...", the window shows the name). It lands in the window, or
-- another addon's filter (a spam filter) blocks it after ours. Before it, the
-- window has an older line with the same words by the same player, by someone
-- else, or none; and a few lines or its full 128.
-- Each cell: "copy=new" (the copy shows the line that just came in),
-- "copy=old" (an older line), "window" (the whole window peeks: no line found)
-- or "none".
-- (Before 2026-11-23 a blocked message copied an older line with its words,
-- and an achievement never found its line: the whole window came up.)

local client = arg and arg[1] or "forever"
local now = 100
local timers = {}
local function Install(wow)
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
	-- (Our copy frame: its last line kept, to read back.)
	wow.Methods.AddMessage = function(self, line) self._last = line end
	wow.Methods.Clear = function(self) self._last = nil end
	wow.Methods.SetFadeDuration = function(self, seconds) self._fadeTime = seconds end
	wow.Methods.GetFadeDuration = function(self) return self._fadeTime or 0 end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.handleFrames, db.handleChat, db.chatPeek, db.chatPeekLinesOnly = true, true, true, true
db.chatHideOwn, db.chatHideBubbled = false, false
db.chatPeekTypes.whisper, db.chatPeekTypes.achievement = true, true

local function Upvalue(fn, name)
	for i = 1, 200 do
		local key, value = debug.getupvalue(fn, i)
		if not key then return end
		if key == name then return value end
	end
end
local Filter = Upvalue(ns.ChatTestFilter, "ChatPeekFilter")
local lineCopies = Upvalue(ns.ChatCopyState, "lineCopies")

local MAX_LINES = 128
local windows = 0
local function Window()
	windows = windows + 1
	local cf = wow.CreateFrame("ScrollingMessageFrame", "ChatFindMatrixWindow" .. windows, UIParent)
	cf._lines = {}
	rawset(cf, "AddMessage", function(self, line)
		table.insert(self._lines, line)
		if #self._lines > MAX_LINES then table.remove(self._lines, 1) end
	end)
	rawset(cf, "GetNumMessages", function(self) return #self._lines end)
	rawset(cf, "GetMessageInfo", function(self, i)
		if self._lines[i] then return self._lines[i], 1, 1, 1 end
	end)
	rawset(cf, "GetEffectiveAlpha", function() return 0 end)
	rawset(cf, "AtBottom", function() return true end)
	return cf
end

local BOB = "|Hplayer:Bob-Realm:1|h[Bob]|h"
local ZED = "|Hplayer:Zed-Realm:2|h[Zed]|h"
-- Each kind: its event, the message text, and the window's line for it by a
-- player at a time.
local KINDS = {
	plain = { "CHAT_MSG_WHISPER", "hello there" },
	short = { "CHAT_MSG_WHISPER", "ok" },
	noword = { "CHAT_MSG_WHISPER", "?" },
	rewritten = { "CHAT_MSG_WHISPER", "get |Hquest:1:10|h[Foo Bar]|h now please",
		shown = "get |Hquest:1:10|h[[10] Foo Bar]|h now please" },
	achievement = { "CHAT_MSG_ACHIEVEMENT", "%s has earned the achievement |Hachievement:6:x|h[Level 10]|h!" },
}
local function WindowLine(kind, who, time)
	local text = kind.shown or kind[2]
	if kind[1] == "CHAT_MSG_ACHIEVEMENT" then return ("[%s] "):format(time) .. text:format(who) end
	return ("[%s] %s whispers: %s"):format(time, who, text)
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "chatfind-line",
	fixed = { client = client },
	dims = {
		{ "kind", { "plain", "short", "noword", "rewritten", "achievement" } },
		{ "landed", { "yes", "blocked" } },
		{ "older", { "none", "same", "other" } },
		{ "lines", { "few", "full" } },
	},
	cell = function(c)
		if not (Filter and lineCopies) then return "no filter" end
		local kind = KINDS[c.kind]
		local cf = Window()
		for i = 1, (c.lines == "full" and 200 or 30) do cf:AddMessage(("[10:%02d] %s: filler %d"):format(i % 60, ZED, i)) end
		if c.older ~= "none" then
			cf:AddMessage(WindowLine(kind, c.older == "same" and BOB or ZED, "10:59"))
			cf:AddMessage("[10:59] " .. ZED .. ": filler after")
			cf:AddMessage("[10:59] " .. ZED .. ": filler after 2")
		end
		local oldLine = c.older ~= "none" and WindowLine(kind, c.older == "same" and BOB or ZED, "10:59") or nil
		local newLine = WindowLine(kind, BOB, "11:00")
		now = now + 100
		timers = {}
		Filter(cf, kind[1], kind[2], "Bob-Realm", nil, "", nil, nil, nil, 0, "", nil, nil, "Player-1-00000002")
		if c.landed == "yes" then cf:AddMessage(newLine) end
		local due = timers
		timers = {}
		for _, fn in ipairs(due) do fn() end
		local copy = lineCopies[cf]
		local shown = copy and copy.frame:IsShown() and copy.frame._last
		if shown == newLine then return "copy=new" end
		if shown and shown == oldLine then return "copy=old" end
		if shown then return "copy=other" end
		if (ns.chatPeekUntil[cf] or 0) > now then return "window" end
		return "none"
	end,
	pins = {
		-- (It landed: the copy shows it.)
		{ "", "copy=new" },
		-- (Blocked after our filter: no line of its own to show, the whole
		-- window as for any line not found. Never an older line.)
		{ "landed=blocked", "window" },
	},
})
