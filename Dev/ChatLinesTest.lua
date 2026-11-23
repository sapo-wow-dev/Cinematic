-- /cine debug chatlines: Show just those messages (UI/Chat.lua), the 2026-11-23
-- audit fixes on the game's own message frame. Nothing for you to do: it
-- runs on a test chat window of its own (made from the game's
-- ScrollingMessageFrame, 128 lines kept as the game's chat windows do), never
-- your chat, and says DONE. Ledger: Tools/tests/chat-lines-only.md.
--   1 probe      your chat window: its line cap and line count; how many of its
--                last 20 lines read secret (Q7: the mark falls back when they do);
--                the test window keeps 128 lines (Q1, live)
--   2 full       a full test window (128 lines): a line's copy shows; another
--                line comes in under it; the window comes up halfway: the copy
--                goes in the quick fade (Q4). Then the same with nothing newer:
--                the copy crosses over the window's own line (stays, ~half)
--   3 achieve    an achievement as the game sends it ("%s has earned...", the
--                window shows the name): the copy shows its line, the whole
--                window doesn't come up (Q5). With a screenshot
--   4 blocked    a whisper "ok", with an older "ok" from the same player in the
--                window: landed, the copy shows the new line; blocked by a filter
--                after ours (never added), no older line shows, the whole
--                window peeks instead (Q6)
-- Into CinematicDB.chatLinesTestLog. Dev copy only.
local _, ns = ...

local FIRST = "Chatlinestest"
local WHO = FIRST .. "-Realm"

local tf -- the test window
local function TestWindow()
	if tf then return tf end
	tf = CreateFrame("ScrollingMessageFrame", nil, UIParent)
	tf:SetSize(420, 160)
	tf:SetPoint("CENTER", UIParent, "CENTER", 0, -120) -- (clear of your own chat: run 1's shot had it over it)
	tf:SetFontObject(ChatFontNormal)
	tf:SetJustifyH("LEFT")
	tf:SetMaxLines(128)
	tf:SetFading(false)
	tf:SetInsertMode(_G.SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM or "BOTTOM")
	return tf
end

-- A fresh window: emptied, faded (as chat is in CineMode), n filler lines in.
local function Fresh(n)
	local w = TestWindow()
	w:Clear()
	w:SetAlpha(0)
	w:Show()
	ns.chatPeekUntil[w] = nil
	for i = 1, n do w:AddMessage(("[10:%02d] filler line %d"):format(i % 60, i), 0.7, 0.7, 0.7) end
	return w
end

local function State(w)
	local st = ns.ChatCopyState(w)
	if not st then return "no copy", nil end
	return ("copy %s a=%.2f quick=%s linesUp=%s windowCount=%s window a=%s line=%s"):format(
		st.shown and "up" or "gone", tonumber(st.alpha) or -1, tostring(st.quick), tostring(st.linesUp),
		tostring(st.windowCount), tostring(st.windowAlpha), tostring(st.line)), st
end

local function Ready(r)
	if not (ns.ChatTestPeek and ns.ChatTestFilter and ns.ChatCopyState) then
		r:Skip("the chat code has no test hooks")
		return false
	end
	if not ns.ChatPeekLinesOnly() then
		r:Skip(("Show just those messages isn't active: setting %s, Chat page on %s, the game's own chat %s"):format(
			tostring(ns.db.chatPeekLinesOnly), tostring(ns.PageOn("handleChat")), tostring(ns.ChatIsDefault())))
		return false
	end
	return true
end

local function WindowPeeking(w) return (ns.chatPeekUntil[w] or 0) > GetTime() end

ns.TestKit.Define({
	name = "chatlines",
	key = "chatLinesTest",
	title = "Chat: just those messages",
	about = "Show just those messages on a test chat window: full window, achievements, blocked lines; nothing to do",
	settings = { "handleFrames", "handleChat", "chatPeek", "chatPeekLinesOnly", "chatHideOwn", "tabOn:Chat/page:2", "tabOn:Chat/page:3" },
	context = function()
		return ("lines only %s, chat default %s"):format(tostring(ns.ChatPeekLinesOnly and ns.ChatPeekLinesOnly()),
			tostring(ns.ChatIsDefault and ns.ChatIsDefault()))
	end,
	putBack = function(extra)
		for key, text in pairs(extra) do
			local row = key:match("^type:(.+)$")
			if row and ns.db.chatPeekTypes then
				ns.db.chatPeekTypes[row] = (text == "true" and true) or (text == "false" and false) or nil
			end
		end
		if tf then tf:Clear() tf:Hide() ns.chatPeekUntil[tf] = nil end
		return "Achievements and Whispers rows put back, test window gone"
	end,
	steps = {
		{ key = "setup", title = "your chat, and the test window", run = function(r)
			r:Set("handleFrames", true)
			r:Set("handleChat", true)
			r:Set("chatPeek", true)
			r:Set("chatPeekLinesOnly", true)
			r:Set("chatHideOwn", false)
			r:Set("tabOn:Chat/page:2", true)
			r:Set("tabOn:Chat/page:3", true)
			for _, row in ipairs({ "achievement", "whisper" }) do
				r:Keep("type:" .. row, tostring(ns.db.chatPeekTypes[row]))
				ns.db.chatPeekTypes[row] = true
			end
			local cf = DEFAULT_CHAT_FRAME or _G.ChatFrame1
			r:Probe("your chat: GetMaxLines", function() return cf:GetMaxLines() end)
			local _, count = r:Probe("your chat: GetNumMessages", function() return cf:GetNumMessages() end)
			local secret, plain = 0, 0
			if type(count) == "number" and not (issecretvalue and issecretvalue(count)) then
				for i = count, math.max(1, count - 19), -1 do
					local line = cf:GetMessageInfo(i)
					if issecretvalue and issecretvalue(line) then secret = secret + 1 else plain = plain + 1 end
				end
			end
			r:Log(("your chat's last lines: %d plain, %d secret (in combat %s)"):format(plain, secret,
				tostring(InCombatLockdown())))
			local w = Fresh(140)
			local _, n = r:Probe("test window: GetNumMessages after 140 lines", function() return w:GetNumMessages() end)
			r:Verdict(n == 128, "the game's message frame keeps 128 lines: " .. tostring(n))
			r:Probe("test window: newest line", function() return w:GetMessageInfo(w:GetNumMessages()) end)
		end },
		{ key = "full", title = "full window: a newer line under the copy",
			proven = "chatlines run 1 (qd892, Forever): quick fade with another or the same line, crossing with none", run = function(r)
			if not Ready(r) then return end
			for _, round in ipairs({ { "other", true }, { "same", true }, { "none", false } }) do
				local w = Fresh(140)
				local line = ("[11:00] [%s]: round %s, hello there"):format(FIRST, round[1])
				w:AddMessage(line)
				ns.ChatTestPeek(w, line)
				r:Sleep(0.3)
				local text, st = State(w)
				r:Log("round " .. round[1] .. ", copy in: " .. text)
				local up = st and st.shown
				if round[1] == "other" then w:AddMessage("[11:00] You receive loot: [Linen Cloth].", 0, 0.67, 0) end
				if round[1] == "same" then w:AddMessage(line) end
				w:SetAlpha(0.5) -- (the window comes up: as a mouse-over starts it)
				r:Sleep(0.4)
				text, st = State(w)
				r:Log("round " .. round[1] .. ", window at 0.5: " .. text)
				if round[2] then
					r:Verdict(up and not (st and st.shown),
						("full window, %s line under it: copy showed, then went in the quick fade (%s)"):format(round[1], text))
				else
					r:Verdict(up and st and st.shown and math.abs((st.alpha or 0) - 0.5) < 0.15,
						"full window, nothing newer: copy crosses over the window's own line (" .. text .. ")")
				end
				w:Hide() -- (its copy goes with it: a clean start for the next round)
				r:Sleep(0.3)
			end
		end },
		{ key = "achieve", title = "an achievement shows on its own",
			proven = "chatlines run 1 (qd892, Forever): its line on its own, window faded", run = function(r)
			if not Ready(r) then return end
			local w = Fresh(40)
			local _, link = r:Probe("GetAchievementLink(6)", _G.GetAchievementLink, 6)
			if type(link) ~= "string" then link = "|cffffff00|Hachievement:6:0:0:0:0:0:0:0:0:0|h[Level 10]|h|r" end
			local text = "%s has earned the achievement " .. link .. "!"
			local _, playerLink = r:Probe("GetPlayerLink", _G.GetPlayerLink, WHO, "[" .. FIRST .. "]")
			if type(playerLink) ~= "string" then playerLink = "|Hplayer:" .. WHO .. "|h[" .. FIRST .. "]|h" end
			local line = text:format(playerLink)
			ns.ChatTestFilter(w, "CHAT_MSG_ACHIEVEMENT", text, WHO, "", "", "", "", 0, 0, "", 0, 0, nil)
			w:AddMessage(line, 1, 1, 0) -- (the game adds it right after the filters)
			r:Sleep(0.3)
			local state, st = State(w)
			r:Log("achievement: " .. state)
			r:Verdict(st and st.shown and st.line == line and not WindowPeeking(w),
				"the achievement's line shows on its own, the window stays faded: " .. state)
			r:Shot("the achievement's copy over the faded test window", { behind = w })
			w:Hide()
			r:Sleep(0.2)
		end },
		{ key = "blocked", title = "a blocked line never shows an older one",
			proven = "chatlines run 1 (qd892, Forever): landed = new line; blocked = no old line, whole window", run = function(r)
			if not Ready(r) then return end
			local old = ("[10:59] [%s] whispers: ok"):format(FIRST)
			local new = ("[11:00] [%s] whispers: ok"):format(FIRST)
			-- Landed: the new line.
			local w = Fresh(40)
			w:AddMessage(old, 1, 0.5, 1)
			w:AddMessage("[10:59] filler after", 0.7, 0.7, 0.7)
			ns.ChatTestFilter(w, "CHAT_MSG_WHISPER", "ok", WHO, "", "", "", "", 0, 0, "", 0, 0, nil)
			w:AddMessage(new, 1, 0.5, 1)
			r:Sleep(0.3)
			local state, st = State(w)
			r:Log("landed: " .. state)
			r:Verdict(st and st.shown and st.line == new, "landed: the copy shows the new line: " .. state)
			w:Hide()
			r:Sleep(0.3)
			-- Blocked: another filter after ours drops it, it never lands.
			w = Fresh(40)
			w:AddMessage(old, 1, 0.5, 1)
			w:AddMessage("[10:59] filler after", 0.7, 0.7, 0.7)
			ns.ChatTestFilter(w, "CHAT_MSG_WHISPER", "ok", WHO, "", "", "", "", 0, 0, "", 0, 0, nil)
			r:Sleep(0.3)
			state, st = State(w)
			r:Log("blocked: " .. state .. ", whole window peeking " .. tostring(WindowPeeking(w)))
			r:Verdict(not (st and st.shown and st.line == old) and WindowPeeking(w),
				"blocked: no older line shows, the whole window peeks as for any line not found: " .. state)
			ns.chatPeekUntil[w] = nil
			w:Hide()
		end },
	},
})
