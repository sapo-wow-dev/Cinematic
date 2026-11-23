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
--                the copy stays whole on the window's own line, and goes once
--                the window is all the way up (no cross-fade, 2026-11-23)
--   3 achieve    an achievement as the game sends it ("%s has earned...", the
--                window shows the name): the copy shows its line, the whole
--                window doesn't come up (Q5). With a screenshot
--   4 blocked    a whisper "ok", with an older "ok" from the same player in the
--                window: landed, the copy shows the new line; blocked by a filter
--                after ours (never added), no older line shows, the whole
--                window peeks instead (Q6)
--   5 hover      YOUR ONE ACTION: mouse over your chat window. A copy of its
--                newest line shows first; then, frame by frame: the window comes
--                up in ~0.1 s (ns.CHAT_HOVER_FADE_IN, not the 1.5 s Fade in time),
--                and the copy is never part see-through while it's up (Q8)
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
	-- (CineMode left alone: the hover step needs it on, chat faded. The kit
	-- turned it off under the step, and timed that fade in, run q78a8.)
	cineMode = true,
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
		if extra.cineOff == "true" and ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then
			Cinematic_ToggleCineMode()
		end
		return "Achievements and Whispers rows put back, test window gone, CineMode as it was"
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
			proven = "chatlines run q78a8 (Forever): quick fade with another or the same line; with none, whole then gone", run = function(r)
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
					local held = up and st and st.shown and math.abs((st.alpha or 0) - 1) < 0.01
					w:SetAlpha(1) -- (all the way up)
					r:Sleep(0.3)
					local after, st2 = State(w)
					r:Log("round none, window at 1: " .. after)
					r:Verdict(held and not (st2 and st2.shown),
						"full window, nothing newer: copy stays whole on the window's own line, then goes once it's up ("
							.. text .. " / " .. after .. ")")
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
		{ key = "hover", title = "hover your chat: quick fade, no cross-fade",
			proven = "chatlines run qfba7 (Forever): 0.075 s over 8 frames (0.25 0.64 1.00), copy whole then gone", run = function(r)
			if not Ready(r) then return end
			local cf = DEFAULT_CHAT_FRAME or _G.ChatFrame1
			if not (ns.ChatTestAlpha and ns.CHAT_HOVER_FADE_IN and ns.IsCineModeOn and Cinematic_ToggleCineMode) then
				r:Skip("no hover fade hooks (ns.CHAT_HOVER_FADE_IN, ns.ChatTestAlpha) or no CineMode toggle")
				return
			end
			if not ns.IsCineModeOn() then
				r:Keep("cineOff", "true")
				Cinematic_ToggleCineMode()
				r:Log("CineMode turned on for the step (put back at the end)")
			end
			-- (Chat faded first: up to the hold and fade out, mouse elsewhere.)
			local start = GetTime()
			while (ns.ChatTestAlpha(cf) or 1) > 0.001 and GetTime() - start < 15 do r:Sleep(0.2) end
			local base = ns.ChatTestAlpha(cf)
			r:Log(("chat window alpha before: %s, hover fade in %s s, Fade in time %s s"):format(tostring(base),
				tostring(ns.CHAT_HOVER_FADE_IN), tostring(ns.FadeInTime())))
			if (base or 1) > 0.02 then
				r:Skip("your chat window never faded (alpha " .. tostring(base) .. "): nothing to fade in")
				return
			end
			-- A line of ours in your chat, and its copy, as a message peeking would show.
			local line = ("|cff999999[Cinematic test] hover your chat: this line's copy stays whole as the window comes up|r")
			cf:AddMessage(line)
			ns.ChatTestPeek(cf, line)
			local copyUp = ns.ChatCopyState(cf)
			copyUp = copyUp and copyUp.shown
			r:Log("copy of the newest line up: " .. tostring(copyUp))
			-- Frame by frame from here: when the window starts up and gets there,
			-- and the copy's alpha while it's up.
			local rec = { partial = 0, frames = 0 }
			local watcher = CreateFrame("Frame")
			watcher:SetScript("OnUpdate", function()
				local now, a = GetTime(), ns.ChatTestAlpha(cf) or 0
				-- (Timed from the rise: up from where it lay, not a fade out's
				-- tail. Run q7384 started at 0.03 still fading out, and timed
				-- your reaction too.)
				if a > 0.02 and rec.last and rec.last <= 0.02 and not rec.from then
					rec.from = now
					-- (What brought it up: run qda7e went 0 to 1 in one frame, after 6
					-- minutes. The mouse on it, or typing, which shows it at once.)
					rec.cause = ("mouse over it %s, typing %s, alpha before %.2f"):format(
						tostring(ns.Flag(cf:IsMouseOver())), tostring(ns.IsChatActive and ns.IsChatActive()), rec.last or -1)
					rec.trail = {}
				end
				if rec.trail and #rec.trail < 12 then rec.trail[#rec.trail + 1] = ("%.2f"):format(a) end
				rec.last = a
				if a >= 0.99 and rec.from and not rec.to then rec.to = now end
				if rec.from and not rec.to then
					rec.frames = rec.frames + 1
					local st = ns.ChatCopyState(cf)
					-- (A quick fade is right when a newer line came in under it: its
					-- line no longer sits on the window's. Run q78a8 had one.)
					if st and st.quick then rec.quick = true end
					if st and st.shown and not st.quick and (st.alpha or 1) > 0.02 and (st.alpha or 1) < 0.98 then
						rec.partial = rec.partial + 1
						rec.partialAt = rec.partialAt or ("copy a=%.2f window a=%.2f quick=%s"):format(st.alpha, a, tostring(st.quick))
					end
				end
			end)
			r:WaitFor("Move your mouse over your chat window.", { check = function() return rec.to end })
			watcher:SetScript("OnUpdate", nil)
			local took = rec.to - rec.from
			r:Log(("came up: %s; alpha frame by frame: %s"):format(tostring(rec.cause),
				table.concat(rec.trail or {}, " ")))
			local st = ns.ChatCopyState(cf)
			r:Log(("window up in %.3f s over %d frames; copy part see-through on %d frame(s) %s; quick fade %s; copy now %s"):format(
				took, rec.frames, rec.partial, tostring(rec.partialAt or ""), tostring(rec.quick or false), tostring(st and st.shown)))
			-- (Smooth, not a jump: at 60 fps a 0.1 s fade is ~6 frames.)
			r:Verdict(rec.frames >= 2, ("the window faded in over %d frame(s), not in one jump"):format(rec.frames))
			r:Verdict(took <= ns.CHAT_HOVER_FADE_IN + 0.1,
				("hovered chat comes up in about %.1f s, not the Fade in time: %.3f s"):format(ns.CHAT_HOVER_FADE_IN, took))
			if copyUp then
				r:Verdict(rec.partial == 0 and not (st and st.shown),
					("no cross-fade: the copy was never part see-through (%d frame(s)), and it's gone with the window up"):format(rec.partial))
			else
				r:Log("no copy showed (newest line unreadable?): cross-fade not checked")
			end
		end },
	},
})
