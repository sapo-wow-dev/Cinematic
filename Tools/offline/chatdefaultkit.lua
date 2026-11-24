-- /cine debug chatdefault (Dev/ChatDefaultTest.lua, a kit test) offline:
--   python -I Tools/offline/run.py Tools/offline/chatdefaultkit.lua < /dev/null
-- Runs the test through the kit on a stand-in game with pretend time, twice:
-- the game's own chat (round 1 copies the line), then DaylightUI's chat
-- loaded (round 1 brings the window up, no copy: the doubled lines a player
-- saw, 2026-11-24). Every verdict must PASS, the settings come back.
-- luacheck: push ignore 111 112 113 121 122 212
local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print((ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Has(log, pattern)
	for _, line in ipairs(log or {}) do
		if line:find(pattern) then return line end
	end
end

local now = 100
local ns, wow = dofile("Tools/offline/load.lua")("forever", "CinematicDev.toc", function(w)
	GetTime = function() return now end
	w.Methods.SetAlpha = function(self, alpha) self._a = alpha end
	w.Methods.GetAlpha = function(self) return self._a or 1 end
	w.Methods.SetFadeDuration = function(self, seconds) self._fadeTime = seconds end
	w.Methods.GetFadeDuration = function(self) return self._fadeTime or 0 end
end)
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
local timers, tickers = {}, {}
C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
C_Timer.NewTicker = function(every, fn)
	local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
	tickers[#tickers + 1] = t
	return t
end
local function Advance(seconds)
	local stop = now + seconds
	while now < stop do
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do
			if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end
		end
		for i = #due, 1, -1 do due[i].fn() end
		-- (The line copies' watch, as each frame would: hides them once their time's up.)
		if Watch then Watch() end
		for _, t in ipairs(tickers) do
			if not t.cancelled and t.next <= now then
				t.next = now + t.every
				t.fn(t)
			end
		end
	end
end
Screenshot = function() end
local cine = true
ns.IsCineModeOn = function() return cine end
Cinematic_ToggleCineMode = function() cine = not cine end
ns.PadTestBox = function() end
ns.PadTestBoxHide = function() end

local db = ns.db
db.handleFrames, db.handleChat = true, true
local switch = "handleChat"
while switch do
	db[switch] = true
	switch = ns.PageSwitchOf(switch)
end

-- The main chat window: lines kept, faded (alpha 0), shown.
local cf = wow.CreateFrame("ScrollingMessageFrame", "ChatDefaultKitWindow", UIParent)
cf._lines = {}
rawset(cf, "AddMessage", function(self, line) table.insert(self._lines, line) end)
rawset(cf, "GetNumMessages", function(self) return #self._lines end)
rawset(cf, "GetMessageInfo", function(self, i) return self._lines[i] end)
rawset(cf, "GetEffectiveAlpha", function() return 0 end)
rawset(cf, "AtBottom", function() return true end)
cf:SetAlpha(0)
DEFAULT_CHAT_FRAME = cf
ns.ChatWindowShown = function() return true end
ns.ChatSeen = function() return false end

local IsLoaded = C_AddOns.IsAddOnLoaded
local function Run(label, loaded, want)
	print("== " .. label)
	C_AddOns.IsAddOnLoaded = function(name) return loaded[name] or false end
	local was = db.chatPeekLinesOnly
	ns.HandleSlash("debug chatdefault full") -- (every step, proven or not)
	Advance(40)
	local log = CinematicDB.chatDefaultTestLog
	local done = Has(log, "DONE: ")
	Check(label .. ": finished DONE", done ~= nil, done)
	Check(label .. ": no FAIL", done and done:find(" 0 fail", 1, true) ~= nil, done)
	local round = Has(log, "round 1 %(your chat%) at")
	Check(label .. ": round 1 " .. want, round and round:find(want == "copy" and "copy UP" or "copy gone", 1, true) ~= nil
		or (want == "window" and round and round:find("no copy frame", 1, true) ~= nil), round)
	Check(label .. ": setting put back", db.chatPeekLinesOnly == was, tostring(db.chatPeekLinesOnly))
	Check(label .. ": CineMode back on", cine == true)
	if not done or os.getenv("CHATKIT_VERBOSE") then
		for _, line in ipairs(log or {}) do print("   " .. line) end
	end
end

Run("game's own chat", {}, "copy")
-- DaylightUI's chat: its holder (the panel its lines are drawn on), the main
-- window claimed onto it by Support/DaylightUI.lua as the addon loads.
local holder = wow.CreateFrame("Frame", "DaylightUIChat", UIParent)
rawset(holder, "GetEffectiveAlpha", function() return 1 end)
ChatFrame1 = cf
C_AddOns.IsAddOnLoaded = function(name) return name == "DaylightUI" or name == "DaylightUI_Chat" end
wow.Fire("ADDON_LOADED", "DaylightUI_Chat")
ns.BuildManagedList()
Advance(1)
Check("DaylightUI chat: the main window's panel is its holder", ns.chatPeekPanels[cf] == holder,
	tostring(ns.chatPeekPanels[cf]))
Run("DaylightUI chat", { DaylightUI = true, DaylightUI_Chat = true }, "window")
C_AddOns.IsAddOnLoaded = IsLoaded

print(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
-- luacheck: pop
