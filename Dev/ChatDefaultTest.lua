-- /cine debug chatdefault (dev copy only): Show just those messages works
-- only with the game's own chat (ns.ChatIsDefault, UI/Chat.lua). With
-- EllesmereUI's chat our copy of a new line showed under its own line: two
-- lines (2026-11-20). With DaylightUI's chat (the game's windows at alpha 0
-- under a window of its own) every new line showed twice (a player,
-- 2026-11-24). On the test kit since 2026-11-24 (was an old test). Nothing to
-- do: it runs, takes screenshots and says DONE.
--   1 setup     what chat is on screen: which addon claims the window, the chat
--               addons loaded, DaylightUI's chat style and ChatFrame1's alpha.
--               A chat addon loaded = not the game's own chat (PASS/FAIL)
--   2 checkbox  Show just those messages shown only with the game's own chat
--   3 yours     your chat as it is: a test line comes in while chat is faded.
--               Game's chat: a copy of just the line, the window stays faded.
--               Another addon's: no copy, the window comes up instead
--   4 flipped   the other way round (ns.ChatIsDefault answers the opposite for
--               the step), so both answers are proven on this client
-- Into CinematicDB.chatDefaultTestLog.
local _, ns = ...

local CHAT_ADDONS = { "EllesmereUIChat", "ElvUI", "Glass", "Chattynator", "Prat-3.0", "DaylightUI_Chat" }
-- (Those that make ns.ChatIsDefault false by being loaded; the rest by a
-- "chatwindow" claim, which the setup line shows.)
local REPLACES = { Chattynator = true, DaylightUI_Chat = true }
local HOLD = 4 -- reveal time for the test (seconds), put back after
local LOOK_AT = 0.6 -- seconds after the line that the result is read

local realIsDefault -- ns.ChatIsDefault while the flipped step swaps it

local function Loaded(name)
	local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	return IsLoaded and IsLoaded(name) and true or false
end

local function Num(v)
	if issecretvalue and issecretvalue(v) then return "secret" end
	return type(v) == "number" and ("%.2f"):format(v) or tostring(v)
end

local function Name(frame)
	local name = frame and frame.GetName and frame:GetName()
	return type(name) == "string" and name or (frame and "unnamed" or "none")
end

local function CopyText(st)
	if not st then return "no copy frame" end
	return ("copy %s a=%s lines=%s, window lines %s a=%s"):format(st.shown and "UP" or "gone", Num(st.alpha),
		tostring(st.count), tostring(st.windowCount), Num(st.windowAlpha))
end

-- DaylightUI's chat: its style ("classic" restyles the game's windows; the
-- others draw a window of its own over them at alpha 0).
local function DaylightChat()
	if not Loaded("DaylightUI_Chat") then return "not loaded" end
	local dui = _G.DaylightUI
	local ok, style = pcall(function() return dui and dui.Get and dui:Get("Chat", "style") end)
	return ("loaded, style %s"):format(ok and tostring(style) or ("unreadable: " .. tostring(style)))
end

-- One round: chat faded, a test line in, read after LOOK_AT. flip: the
-- other answer of ns.ChatIsDefault for the round.
local function Round(r, name, flip)
	local cf = DEFAULT_CHAT_FRAME
	if not ns.ChatWindowShown(cf) then
		r:Skip("your main chat tab isn't the one shown: pick it and run again")
		return
	end
	-- (Faded first: no peek left, no copy up, the window unseen, for a fade out.)
	local quietAt
	local faded = r:WaitFor("Hands off: waiting for chat to fade (mouse off chat).", { check = function()
		local now, st = GetTime(), ns.ChatCopyState(cf)
		local quiet = not ns.ChatSeen(cf) and not (st and st.shown) and (ns.chatPeekUntil[cf] or 0) <= now
		if not quiet then quietAt = nil return false end
		quietAt = quietAt or now
		return now - quietAt >= (tonumber(ns.FadeOutTime()) or 0.5) + 0.8
	end })
	r:Log(("round %s: chat faded (%s), ChatFrame1 alpha %s"):format(name, tostring(faded), Num(cf:GetAlpha())))
	if flip then ns.ChatIsDefault = function() return not realIsDefault() end end
	local isDefault = ns.ChatIsDefault()
	local before = ns.chatPeekUntil[cf] or 0
	local line = ("|cffffd200Cinematic chat test %s: this line came in|r"):format(name)
	cf:AddMessage(line)
	ns.ChatTestPeek(cf, line)
	r:Log(("round %s: line in, game's chat %s, lines only %s: %s"):format(name, tostring(isDefault),
		tostring(ns.ChatPeekLinesOnly()), CopyText(ns.ChatCopyState(cf))))
	r:Sleep(LOOK_AT)
	local st = ns.ChatCopyState(cf)
	local copyUp = st and st.shown and true or false
	local windowUp = (ns.chatPeekUntil[cf] or 0) > before
	if flip then ns.ChatIsDefault = realIsDefault end
	r:Log(("round %s at +%.1fs: %s, window peek until %s (was %s), seen %s"):format(name, LOOK_AT, CopyText(st),
		Num(ns.chatPeekUntil[cf]), Num(before), tostring(ns.ChatSeen(cf))))
	-- The panel the window's lines are drawn on (DaylightUI's holder): it comes
	-- up with the peek, or nothing shows (run q5a6f: only ChatFrame1, at alpha
	-- 0 under DaylightUI, came up). Read as it fades in, up to 3 s.
	local panel = ns.chatPeekPanels and ns.chatPeekPanels[cf]
	local panelUp
	if panel and not isDefault and not flip then
		local t0 = GetTime()
		repeat
			local a = panel:GetEffectiveAlpha()
			panelUp = not (issecretvalue and issecretvalue(a)) and a >= 0.9
			if not panelUp then r:Sleep(0.1) end
		until panelUp or GetTime() - t0 > 3
		r:Log(("round %s: panel %s alpha %s after %.1f s"):format(name, Name(panel),
			Num(panel:GetEffectiveAlpha()), GetTime() - t0))
	end
	-- (Still inside the hold: the copy or the window is on screen for the shot.)
	r:Shot("round " .. name .. ": the test line", { behind = panel or cf })
	if panelUp ~= nil then
		r:Verdict(panelUp, "the panel holding the window's lines came up for the line: " .. tostring(panelUp))
	end
	if isDefault then
		r:Verdict(copyUp and not windowUp, ("game's chat: a copy of just the line (copy %s), window stays faded (up %s)"):format(
			tostring(copyUp), tostring(windowUp)))
	else
		r:Verdict(not copyUp and windowUp, ("another addon's chat: no copy (copy %s), the window comes up (up %s)"):format(
			tostring(copyUp), tostring(windowUp)))
	end
end

ns.TestKit.Define({
	name = "chatdefault",
	key = "chatDefaultTest",
	-- (CineMode left alone: chat fades in it; turned on for the run if off.)
	cineMode = true,
	title = "Chat: just those messages, other chat addons",
	about = "Show just those messages only with the game's own chat (DaylightUI, EllesmereUI, ElvUI, Glass, " ..
		"Chattynator): two test lines, nothing to do",
	needs = "A chat addon on (DaylightUI's chat, its own window) to prove that side; without one the game's chat side",
	settings = { "chatPeek", "chatPeekLinesOnly", "chatPeekTime" },
	context = function()
		return ("game's chat %s, lines only %s, DaylightUI chat %s"):format(
			tostring(ns.ChatIsDefault and ns.ChatIsDefault()), tostring(ns.ChatPeekLinesOnly and ns.ChatPeekLinesOnly()),
			DaylightChat())
	end,
	putBack = function(extra)
		if realIsDefault then ns.ChatIsDefault = realIsDefault end
		if extra.cineOff == "true" and ns.IsCineModeOn and ns.IsCineModeOn() and Cinematic_ToggleCineMode then
			Cinematic_ToggleCineMode()
			return "CineMode turned off again"
		end
		return "nothing of its own"
	end,
	setup = function(r)
		realIsDefault = ns.ChatIsDefault
		r:Set("chatPeek", true)
		r:Set("chatPeekLinesOnly", true)
		r:Set("chatPeekTime", HOLD)
		if ns.IsCineModeOn and not ns.IsCineModeOn() and Cinematic_ToggleCineMode then
			r:Keep("cineOff", "true")
			Cinematic_ToggleCineMode()
			r:Log("CineMode turned on for the run (put back at the end)")
		end
	end,
	steps = {
		{ key = "setup", title = "what chat is on screen",
			proven = "chatdefault run q7612 (2026-11-24, Forever, DaylightUI's chat): not the game's chat, linked to DaylightUIChat",
			run = function(r)
			if not (ns.ChatTestPeek and ns.ChatCopyState and ns.ChatIsDefault and ns.ChatSeen) then
				r:Fail("the chat code has no test hooks")
				return
			end
			if not ns.PageOn("handleChat") then
				r:Skip("the Chat page is off: turn it on and run again")
				return
			end
			local claimants = ns.LinkClaimants and ns.LinkClaimants("chatwindow")
			local loaded, replacing = {}, {}
			for _, name in ipairs(CHAT_ADDONS) do
				if Loaded(name) then
					loaded[#loaded + 1] = name
					if REPLACES[name] then replacing[#replacing + 1] = name end
				end
			end
			local isDefault = ns.ChatIsDefault()
			local cf = DEFAULT_CHAT_FRAME
			r:Log(("window claimed by %s; chat addons loaded: %s; DaylightUI chat %s; main chat alpha %s, shown %s"):format(
				claimants and table.concat(claimants, ", ") or "none", #loaded > 0 and table.concat(loaded, ", ") or "none",
				DaylightChat(), Num(cf and cf:GetAlpha()), tostring(cf and ns.Flag(cf:IsShown()))))
			local other = (claimants ~= nil) or #replacing > 0
			r:Verdict(isDefault == not other, ("game's own chat %s (want %s: claimed %s, replacing addons %s)"):format(
				tostring(isDefault), tostring(not other), tostring(claimants ~= nil),
				#replacing > 0 and table.concat(replacing, ", ") or "none"))
			if Loaded("DaylightUI_Chat") then
				r:Verdict(not isDefault and not ns.ChatPeekLinesOnly(),
					"DaylightUI's chat loaded: no line copies (the doubled lines, 2026-11-24)")
				local panel = ns.chatPeekPanels and ns.chatPeekPanels[cf]
				r:Verdict(panel ~= nil and panel == _G.DaylightUIChat, ("the main window's panel is DaylightUI's holder: %s"):format(
					Name(panel)))
			else
				r:Log("DaylightUI's chat not loaded: its side proven offline only (Tools/offline/chatdefault.lua)")
			end
		end },
		{ key = "checkbox", title = "the setting shown only with the game's chat",
			proven = "chatdefault run q7612 (2026-11-24): hidden with DaylightUI's chat",
			run = function(r)
			local entry = ns.FindEntryOf and ns.FindEntryOf("chatPeekLinesOnly")
			local box = entry and entry.edges and entry.edges.top
			if not (box and box.Refresh) then
				r:Fail("Show just those messages not found in the settings")
				return
			end
			box:Refresh()
			local shown, isDefault = box:IsShown() and true or false, ns.ChatIsDefault()
			r:Verdict(shown == isDefault, ("checkbox shown %s (want %s)"):format(tostring(shown), tostring(isDefault)))
		end },
		{ key = "yours", title = "your chat as it is: a test line",
			proven = "chatdefault run q7612 (2026-11-24): DaylightUI's window up (0.93 in 0.6 s), no copy, the line once in the shot",
			run = function(r)
			Round(r, "1 (your chat)", false)
		end },
		{ key = "flipped", title = "the other way round",
			proven = "chatdefault run q7612 (2026-11-24): game's-chat answer copies just the line, window stays faded",
			run = function(r)
			Round(r, "2 (flipped)", true)
		end },
	},
})
