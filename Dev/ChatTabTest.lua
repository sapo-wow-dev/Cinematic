-- /cine debug chattab (dev copy only): a line landing in a docked chat tab
-- you haven't selected (the Combat Log's crafting lines) must not bring chat
-- up on the selected tab (player report, 2026-11-21; UI/Chat.lua
-- OtherDockTabSelected). One run, four rounds, each: a tab is selected, chat
-- is left to fade, then a pretend line goes through the peek filter for one
-- window, and two seconds of what chat does are logged, with a screenshot.
--   A: General selected, a crafting line for the Combat Log: chat stays down.
--   B: Combat Log selected, a crafting line for it: chat comes up.
--   C: General selected, a whisper for General: chat comes up.
--   D: General selected, a real whisper to a name no one has: the game's
--      "No player named" line comes up through the game (and Glass): chat
--      comes up.
-- Before the rounds every chat window's state is logged (shown, docked, the
-- dock's selected tab, crafting lines going there), and every real crafting
-- line that comes in during the run too. Other players' crafting is ticked
-- for the run and your tab and tick are put back after. Nothing is printed
-- to chat while it runs (a line would change what's tested): the steps show
-- in big text on the screen. Again to stop.

local _, ns = ...

local FADE_WAIT = 30 -- seconds at most for chat to fade before a line
local FADE_LOW = 0.35 -- chat counts as faded below this alpha
local WATCH = 2 -- seconds recorded after a line
local RISE = 0.25 -- chat counts as up once its alpha rises this much

local driver = CreateFrame("Frame")
local hidesWatched = {}
local prompt, run

local function Log(text) ns.Log("chattab", text) end
local function Num(v) return type(v) == "number" and ("%.2f"):format(v) or tostring(v) end

local function Prompt(text)
	if not prompt then
		prompt = CreateFrame("Frame", nil, WorldFrame)
		prompt:SetFrameStrata("TOOLTIP")
		prompt:SetAllPoints(WorldFrame)
		prompt.text = prompt:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		prompt.text:SetPoint("TOP", prompt, "TOP", 0, -WorldFrame:GetHeight() * 0.2)
		prompt.text:SetWidth(WorldFrame:GetWidth() * 0.6)
	end
	prompt.text:SetText(text or "")
	prompt:SetShown(text ~= nil)
end

local function Selected()
	local dock = rawget(_G, "GENERAL_CHAT_DOCK")
	local GetSelected = rawget(_G, "FCFDock_GetSelectedWindow")
	if not (dock and GetSelected) then return nil end
	local ok, selected = pcall(GetSelected, dock)
	return ok and selected or nil
end

local function Select(chatFrame)
	local dock = rawget(_G, "GENERAL_CHAT_DOCK")
	local SelectWindow = rawget(_G, "FCFDock_SelectWindow")
	if dock and SelectWindow and chatFrame then
		local ok, err = pcall(SelectWindow, dock, chatFrame)
		if not ok then Log("selecting " .. tostring(chatFrame:GetName()) .. " failed: " .. tostring(err)) end
	end
end

local function GetsCrafting(chatFrame)
	for _, group in ipairs(chatFrame.messageTypeList or {}) do
		if group == "TRADESKILLS" then return true end
	end
	return false
end

-- The chat window that has the Combat Log in it (ChatFrame2 normally).
local function CombatLogWindow()
	local byName = rawget(_G, "COMBATLOG")
	if type(byName) == "table" and byName.GetName then return byName end
	return rawget(_G, "ChatFrame2")
end

local function WindowsText()
	local parts = {}
	local selected = Selected()
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local cf = _G["ChatFrame" .. i]
		if cf then
			local name, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(i)
			if (name and name ~= "") or ns.Flag(cf:IsShown()) then
				local panel = ns.chatPeekPanels and ns.chatPeekPanels[cf]
				parts[#parts + 1] = ("%s '%s': IsShown %s, visible %s, panel %s, isDocked %s, info shown %s docked %s,"
					.. " selected %s, crafting here %s, counts as shown %s, alpha %s"):format(
					cf:GetName(), tostring(name), tostring(cf:IsShown()), tostring(cf:IsVisible()),
					panel and ("shown " .. tostring(panel:IsShown()) .. " visible " .. tostring(panel:IsVisible())
						.. " alpha " .. Num(panel:GetEffectiveAlpha())) or "none",
					tostring(cf.isDocked), tostring(shown), tostring(docked), tostring(cf == selected),
					tostring(GetsCrafting(cf)), tostring(ns.ChatWindowShown(cf)), Num(ns.ChatTestAlpha(cf)))
			end
		end
	end
	return table.concat(parts, " | ")
end

local function OtherAddons()
	local names = {}
	local count = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
	for i = 1, count do
		local name = C_AddOns.GetAddOnInfo(i)
		if name and C_AddOns.IsAddOnLoaded(i) and not name:match("^Cinematic") and not name:match("^Blizzard_") then
			names[#names + 1] = name
		end
	end
	return #names > 0 and table.concat(names, ", ") or "none"
end

local function Stop(why)
	ns.SetOnUpdate(driver, nil)
	driver:UnregisterAllEvents()
	Prompt(nil)
	if not run then return end
	local r = run
	run = nil
	ns.db.chatPeekTypes.tradeskill = r.keptTick
	if r.keptSelected then Select(r.keptSelected) end
	Log("tab and Other players' crafting tick put back (" .. tostring(r.keptTick) .. ")")
	local verdicts = {}
	for _, round in ipairs(r.rounds) do
		verdicts[#verdicts + 1] = round.name .. " " .. (round.verdict or "not run")
	end
	Log("verdict: " .. table.concat(verdicts, ", ") .. (why and (" (" .. why .. ")") or ""))
	ns.Print("chattab done: " .. table.concat(verdicts, ", ") .. (why and (" (" .. why .. ")") or "")
		.. ". Say \"check log\".")
end

local function Peeked(round, now)
	local cf = round.target
	local untilNow = ns.chatPeekUntil[cf] or 0
	local copy = ns.ChatCopyState and ns.ChatCopyState(cf)
	local alpha = ns.ChatTestAlpha(round.shows) or 0
	if untilNow > round.untilBefore + 0.01 then round.held = true end
	if copy and copy.shown then round.copied = true end
	if alpha > round.alphaBefore + RISE then round.rose = true end
	Log(("round %s +%.2f: peek hold %s, line copy %s, %s alpha %s"):format(round.name, now - round.lineAt,
		untilNow > now and ("%.1fs left"):format(untilNow - now) or "none", tostring(copy and copy.shown),
		round.shows:GetName(), Num(alpha)))
end

local function Step()
	local r = run
	if not r then return end
	local now = GetTime()
	local round = r.rounds[r.index]
	if not round then
		Stop()
		return
	end
	if round.phase == nil then
		Select(round.select)
		round.phase, round.from = "fade", now
		round.shows = round.select or round.target
		Prompt(("Round %s of 4: %s selected. Stand still, hands off the mouse and chat, while chat fades")
			:format(round.name, tostring(round.select and round.select.name or "?")))
		Log(("round %s: selected %s (dock says %s)"):format(round.name, tostring(round.select and round.select:GetName()),
			tostring(Selected() and Selected():GetName())))
		Log("round " .. round.name .. " windows: " .. WindowsText())
	elseif round.phase == "fade" then
		local alpha = ns.ChatTestAlpha(round.shows) or 0
		local held = (ns.chatPeekUntil[round.shows] or 0) > now or (ns.chatPeekUntil[round.target] or 0) > now
		if (alpha < FADE_LOW and not held and now > round.from + 1) or now > round.from + FADE_WAIT then
			round.faded = alpha < FADE_LOW
			Log(("round %s: chat %s after %.1fs (alpha %s, hold %s)"):format(round.name,
				round.faded and "faded" or "did NOT fade", now - round.from, Num(alpha), tostring(held)))
			round.untilBefore = ns.chatPeekUntil[round.target] or 0
			round.alphaBefore = alpha
			round.countsShown = ns.ChatWindowShown(round.target)
			round.lineAt = now
			if round.real then
				local Send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
				local ok, err = pcall(Send, round.text, "WHISPER", nil, round.whisperTo)
				Log(("round %s: real whisper to %s sent %s"):format(round.name, round.whisperTo,
					ok and "ok" or ("FAILED: " .. tostring(err))))
			else
				ns.ChatTestFilter(round.target, round.event, round.text, "Cinetest", "", "", "", 0, "", 0, "", 0, 0, "")
			end
			Log(("round %s: pretend %s line through the filter for %s (counts as shown %s)"):format(round.name,
				round.event, round.target:GetName(), tostring(round.countsShown)))
			round.phase = "watch"
			Prompt(("Round %s of 4: watching chat"):format(round.name))
		end
	elseif round.phase == "watch" then
		if not round.nextLog or now >= round.nextLog then
			round.nextLog = now + 0.25
			Peeked(round, now)
		end
		if not round.shot and now >= round.lineAt + 1 then
			round.shot = true
			Screenshot()
			Log("round " .. round.name .. ": screenshot at +1s")
		end
		if now >= round.lineAt + WATCH then
			local up = (round.held or round.copied or round.rose) == true -- (nil isn't false to ==)
			local pass = (up == round.wantUp) and (round.faded or not round.wantUp)
			round.verdict = pass and "PASS" or "FAIL"
			Log(("round %s: %s (wanted chat %s; hold %s, line copy %s, alpha rose %s, faded first %s)"):format(
				round.name, round.verdict, round.wantUp and "up" or "down", tostring(round.held == true),
				tostring(round.copied == true), tostring(round.rose == true), tostring(round.faded)))
			r.index = r.index + 1
		end
	end
end

function ns.ChatTabTest()
	if run then
		Stop("stopped")
		return
	end
	local general, combat = rawget(_G, "ChatFrame1"), CombatLogWindow()
	if not (general and combat and ns.ChatTestFilter and ns.ChatTestAlpha) then
		ns.Print("chattab: no General or Combat Log window, or no chat test hooks")
		return
	end
	general.name = general.name or "General"
	combat.name = combat.name or "Combat Log"
	ns.debugNoCopyWindow = true
	ns.Print("chattab: running, about 1-2 minutes. The steps show in big text; again to stop.")
	run = {
		index = 1,
		keptTick = ns.db.chatPeekTypes.tradeskill,
		keptSelected = Selected(),
		rounds = {
			{ name = "A", select = general, target = combat, event = "CHAT_MSG_TRADESKILLS",
				text = "Cinetest creates Copper Bar.", wantUp = false },
			{ name = "B", select = combat, target = combat, event = "CHAT_MSG_TRADESKILLS",
				text = "Cinetest creates Copper Bar.", wantUp = true },
			{ name = "C", select = general, target = general, event = "CHAT_MSG_WHISPER",
				text = "Cinetest whisper", wantUp = true },
			{ name = "D", select = general, target = general, event = "CHAT_MSG_SYSTEM (real)", real = true,
				whisperTo = "Zzqxcinetest", text = "Cinematic chat test", wantUp = true },
		},
	}
	ns.db.chatPeekTypes.tradeskill = true
	Log(("start: client %s, chat page %s, show chat on message %s, lines only %s, CineMode %s, in combat %s,"
		.. " other addons: %s"):format(ns.isRetail and "retail" or "Forever/classic",
		tostring(ns.PageOn("handleChat")), tostring(ns.db.chatPeek), tostring(ns.ChatPeekLinesOnly()),
		tostring(ns.IsCineModeOn()), tostring(InCombatLockdown()), OtherAddons()))
	Log("start windows: " .. WindowsText())
	driver:RegisterEvent("CHAT_MSG_TRADESKILLS")
	driver:RegisterEvent("CHAT_MSG_SYSTEM")
	driver:SetScript("OnEvent", function(_, event, text)
		local plain = type(text) == "string" and not (issecretvalue and issecretvalue(text))
		if event == "CHAT_MSG_SYSTEM" then
			if run and run.rounds[run.index] and run.rounds[run.index].real then
				Log(("real system line in (%s); windows: %s"):format(plain and text or "unreadable", WindowsText()))
			end
			return
		end
		Log(("real crafting line in (%s); selected %s; windows: %s"):format(plain and text or "unreadable",
			tostring(Selected() and Selected():GetName()), WindowsText()))
	end)
	-- Who hides General or its linked panel (Glass hides its frame when
	-- ChatFrame1:Hide() is called): the caller's stack, while a run lasts.
	local panel = ns.chatPeekPanels and ns.chatPeekPanels[general]
	for label, target in pairs({ ["General"] = general, ["General's panel"] = panel or false }) do
		if target and not hidesWatched[target] then
			hidesWatched[target] = true
			for _, method in ipairs({ "Hide", "SetShown" }) do
				if type(target[method]) == "function" then
					hooksecurefunc(target, method, function(_, shown)
						if run and not (method == "SetShown" and shown) then
							Log(("%s:%s(%s) from %s"):format(label, method, tostring(shown),
								(debugstack(2, 6, 0) or "?"):gsub("\n", " < ")))
						end
					end)
				end
			end
		end
	end
	ns.SetOnUpdate(driver, Step)
end
