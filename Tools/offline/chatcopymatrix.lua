-- Show just those messages: a copied line as the chat window rises under it,
-- every state (the audit kit's matrix, Tools/offline/matrix.lua; fix card
-- Tools/audits/2026-11-23-chat-copy-full-window.md):
--   python -I Tools/offline/run.py Tools/offline/chatcopymatrix.lua [forever|retail] < /dev/null
--   python -I Tools/audit.py diff Tools/offline/chatcopymatrix.lua --base <ref>
-- A line peeks a faded chat window with Show just those messages on: its copy
-- shows over the window. Then another line comes in under it or not (one
-- from someone else, or the same line again), the window is scrolled to the
-- bottom or not, and the window has a few lines or is full (the game keeps
-- 128 per window: its line count stops growing). Then the window starts to
-- come up (moused over). Each cell: whether the copy showed, and as the window
-- rises, whether the copy fades across it ("crossing": its line sits on the
-- window's own) or goes in a quick fade ("gone": the window's newest line is
-- another one now, or it's scrolled up).
-- (Before 2026-11-23 a full window never told a newer line came in: its count
-- stayed 128, and the copy crossed over a different line, two texts on top
-- of each other, only after a long session.)

local client = arg and arg[1] or "forever"
local now = 100
local function Install(wow)
	-- luacheck: push ignore 111 112 113 121 122
	GetTime = function() return now end
	-- (Our copy frame: its alpha kept, to read back.)
	wow.Methods.SetAlpha = function(self, alpha) self._a = alpha end
	wow.Methods.GetAlpha = function(self) return self._a or 1 end
	wow.Methods.SetFadeDuration = function(self, seconds) self._fadeTime = seconds end
	wow.Methods.GetFadeDuration = function(self) return self._fadeTime or 0 end
	-- luacheck: pop
end
local ns, wow = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", Install)
local db = ns.db
db.handleFrames, db.handleChat, db.chatPeek, db.chatPeekLinesOnly = true, true, true, true

local function Upvalue(fn, name)
	for i = 1, 200 do
		local key, value = debug.getupvalue(fn, i)
		if not key then return end
		if key == name then return value end
	end
end
local PeekWindow = Upvalue(ns.ChatTestPeek, "PeekWindow")
local PeekLine = PeekWindow and Upvalue(PeekWindow, "PeekLine")
local ShowCopy = PeekLine and Upvalue(PeekLine, "ShowCopy")
local Watch = ShowCopy and Upvalue(ShowCopy, "OnCopyWatch")

-- A game chat window: its lines (newest last, 128 kept), alpha and scroll.
local MAX_LINES = 128
local windows = 0
local function Window()
	windows = windows + 1
	local cf = wow.CreateFrame("ScrollingMessageFrame", "ChatCopyMatrixWindow" .. windows, UIParent)
	cf._lines, cf._fade, cf._bottom = {}, 0, true
	rawset(cf, "AddMessage", function(self, line, r, g, b)
		table.insert(self._lines, { line, r or 1, g or 1, b or 1 })
		if #self._lines > MAX_LINES then table.remove(self._lines, 1) end
	end)
	rawset(cf, "GetNumMessages", function(self) return #self._lines end)
	rawset(cf, "GetMessageInfo", function(self, i)
		local entry = self._lines[i]
		if entry then return entry[1], entry[2], entry[3], entry[4] end
	end)
	rawset(cf, "GetEffectiveAlpha", function(self) return self._fade end)
	rawset(cf, "AtBottom", function(self) return self._bottom end)
	return cf
end

local Matrix = dofile("Tools/offline/matrix.lua")
Matrix.Run({
	name = "chatcopy-rise",
	fixed = { client = client },
	dims = {
		{ "lines", { "few", "full" } },
		{ "newer", { "none", "other", "same" } },
		{ "bottom", { "yes", "no" } },
	},
	cell = function(c)
		if not Watch then return "no copy watch" end
		local cf = Window()
		local count = c.lines == "full" and 200 or 10
		for i = 1, count do cf:AddMessage(("[10:%02d] [Zed]: filler %d"):format(i % 60, i)) end
		local line = "[11:00] [Bob]: hello there"
		cf:AddMessage(line)
		ns.ChatTestPeek(cf, line)
		local st = ns.ChatCopyState(cf)
		local first = st and st.shown and "shown" or "hidden"
		if c.newer == "other" then cf:AddMessage("[11:00] [Ann]: you receive loot") end
		if c.newer == "same" then cf:AddMessage(line) end
		cf._bottom = c.bottom == "yes"
		now = now + 0.1
		Watch()
		-- (The window starts to come up: moused over.)
		cf._fade = 0.5
		now = now + 0.05
		Watch()
		now = now + 0.2
		Watch()
		st = ns.ChatCopyState(cf)
		local rise
		if not (st and st.shown) then
			rise = "gone"
		elseif math.abs((st.alpha or 0) - 0.5) < 0.01 then
			rise = "crossing"
		else
			rise = ("alpha %.2f"):format(st.alpha or -1)
		end
		now = now + 100
		Watch()
		return ("first=%s rise=%s"):format(first, rise)
	end,
	pins = {
		-- (A newer line under it, or scrolled up: its line isn't the window's
		-- newest on screen, so it goes as the window comes up.)
		{ "", "first=shown rise=gone" },
		-- (Nothing newer, at the bottom: it sits on the window's own line.)
		{ "newer=none bottom=yes", "first=shown rise=crossing" },
	},
})
