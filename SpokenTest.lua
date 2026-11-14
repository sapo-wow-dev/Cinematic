-- /cine debug spokentest [steps]: one run checking Spoken support
-- (Support/Spoken.lua) on WoW Forever. For the run it turns Quest Vision and
-- Custom dialogue frames on (put back after), then, a timed step each in the
-- big test box (Frames.lua's ns.PadTestBox):
--   1 open:  talk to a quest giver: does our bubble come up with Spoken's
--            round Play button on it, on the screen?
--   2 click: click it: does a line start (or the playing one stop)?
--   3 again: click it again: does it turn the other way?
--   4 fade:  the window still open, the test reads the quest (Spoken's
--            /spqread) and turns CineMode on: do Spoken's narrator windows,
--            subtitles and the 3D faces in them fade?
-- Every half second the log gets the bubble, the button, what Spoken plays
-- and its frames' alpha (and their models'); Spoken's clip events and our
-- button's clicks as they come; a verdict per step; screenshots at the key
-- moments, named in the log. Steps as arguments (spokentest 2 3) redo just
-- those. Into its own saved list, CinematicDB.spokenTestLog. Dev copy only
-- (CinematicDev.toc).
local _, ns = ...

local SETUP, STEP, WAIT = 10, 15, 4 -- seconds: the first step, each step's, reading time
local FRAMES = { "SpokenPlayerFrame", "SpokenMinimalPlayerFrame", "SpokenSubtitleFrame", "SpokenDialogueUIPlayerFrame" }
-- (Each step works alone, so a redo of just some of them still opens the
-- talk first. "The NPC's words" is Quest talk's bubble: players don't know
-- it by any name.)
local TALK = "If the NPC's words aren't on screen, RIGHT-CLICK the quest giver first. "
local STEPS = {
	{ key = "open", say = "%d/%d: RIGHT-CLICK the quest giver to talk to them. Their words come up in a box " ..
		"(instead of the game's quest window). Just look: don't click anything else." },
	{ key = "click", say = "%d/%d: " .. TALK .. "Then CLICK the small round PLAY button on the TOP RIGHT " ..
		"CORNER of the box with the NPC's words, ONCE. The voice should START." },
	{ key = "again", say = "%d/%d: " .. TALK .. "The voice is playing: CLICK that same round button ONCE. " ..
		"The voice should STOP." },
	{ key = "fade", say = "%d/%d: " .. TALK .. "Then HANDS OFF: don't click anything, not even the round " ..
		"button. The test plays the voice itself and checks Spoken's subtitles fade out in CineMode." },
}

local ROWS = { "spokenNarrator", "spokenMinimal", "spokenSubtitles" } -- (switched on for the run, put back after)

local run -- { at, steps, step, notes = { [key] = {...} }, kept = {...} }

local function Say(text)
	local log = CinematicDB and CinematicDB.spokenTestLog
	if log then
		log[#log + 1] = ("%.1f %s"):format(run and GetTime() - run.at or 0, text)
	end
end

local function Num(value)
	if value == nil then return "nil" end
	if issecretvalue and issecretvalue(value) then return "secret" end
	if type(value) == "number" then return ("%.2f"):format(value) end
	return tostring(value)
end
local function Ask(frame, method)
	if not (frame and frame[method]) then return nil end
	local ok, value = pcall(frame[method], frame)
	return ok and value or nil
end

-- A screenshot, the box hidden for it, named in the log by its time, as the
-- game names the file (WoWScrnShot_MMDDYY_HHMMSS). Called from our own
-- function: handed to a timer itself it was refused on Forever.
local function Shot(what)
	ns.PadTestBoxHide()
	local ok, err = pcall(function() Screenshot() end)
	return ok and ("screenshot %s at %s"):format(what, date("%m%d%y_%H%M%S")) or ("screenshot failed: " .. tostring(err))
end

local function Spoken() return _G.Spoken end
local function Playing()
	local sp = Spoken()
	local ok, clip = pcall(function() return sp and sp:GetNowPlaying() end)
	return ok and clip or nil
end
local function ClipName(clip)
	if type(clip) ~= "table" then return tostring(clip) end
	return tostring(clip.key)
end

-- Where a frame is, in screen pixels, and whether that's on the screen.
local function Rect(frame)
	local l, b, w, h = Ask(frame, "GetLeft"), Ask(frame, "GetBottom"), Ask(frame, "GetWidth"), Ask(frame, "GetHeight")
	local s = Ask(frame, "GetEffectiveScale") or 1
	if type(l) ~= "number" or type(b) ~= "number" then return "no rect", false end
	local sw, sh = UIParent:GetWidth() * UIParent:GetEffectiveScale(), UIParent:GetHeight() * UIParent:GetEffectiveScale()
	local x, y = l * s, b * s
	local on = x + (w or 0) * s > 0 and x < sw and y + (h or 0) * s > 0 and y < sh
	return ("at %d,%d size %dx%d"):format(x, y, (w or 0) * s, (h or 0) * s), on
end

-- The 3D faces in a frame (models take no alpha from their parent).
local function Models(frame, out, depth)
	out = out or {}
	depth = depth or 0
	if not frame or depth > 6 then return out end
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.SetUnit or child.SetCreature or child.SetDisplayInfo then
			out[#out + 1] = child
		end
		Models(child, out, depth + 1)
	end
	return out
end

local function FramesLine()
	local parts = {}
	for _, name in ipairs(FRAMES) do
		local frame = _G[name]
		if frame then
			local models = {}
			for _, model in ipairs(Models(frame)) do
				models[#models + 1] = ("%s/%s"):format(Num(Ask(model, "GetEffectiveAlpha")),
					tostring(Ask(model, "IsVisible")))
			end
			parts[#parts + 1] = ("%s shown %s alpha %s eff %s faded-by-us %s models[%s]"):format(name,
				tostring(Ask(frame, "IsVisible")), Num(Ask(frame, "GetAlpha")), Num(Ask(frame, "GetEffectiveAlpha")),
				tostring(ns.IsFaded and ns.IsFaded(frame)), table.concat(models, " "))
		else
			parts[#parts + 1] = name .. " not made"
		end
	end
	return table.concat(parts, "; ")
end

local function Snapshot()
	local bubble, button = _G.CinematicQuestTalkBubble, ns.spokenTalkButton
	local rect, on = Rect(button)
	return ("bubble %s; button %s, shown %s, enabled %s, takes mouse %s, level %s/%s, on screen %s (%s), alpha %s; " ..
		"QuestFrame shown %s, GossipFrame shown %s; playing %s; CineMode %s"):format(
		bubble and (Ask(bubble, "IsVisible") and "shown" or "hidden") or "not made",
		button and "made" or "none", tostring(Ask(button, "IsVisible")), tostring(Ask(button, "IsEnabled")),
		tostring(Ask(button, "IsMouseEnabled")), Num(Ask(button, "GetFrameLevel")), tostring(Ask(button, "GetFrameStrata")),
		tostring(on), rect,
		Num(Ask(button, "GetEffectiveAlpha")), tostring(Ask(_G.QuestFrame, "IsShown")), tostring(Ask(_G.GossipFrame, "IsShown")),
		ClipName(Playing()), tostring(ns.IsCineModeOn and ns.IsCineModeOn()))
end

-- Spoken's clip events and our button's clicks, once per session (logged only
-- while a run's on).
local hooked, hookedButton

-- Every mouse press while a run's on: where, and what was under the pointer
-- (the frame the game gives it to, and whether that's our button), so a click
-- that never reached the button shows what took it.
local presses = CreateFrame("Frame")
presses:SetScript("OnEvent", function(_, _, mouseButton)
	if not run then return end
	local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
	local names = {}
	for _, focus in ipairs(foci) do
		local ok, name = pcall(focus.GetName, focus)
		names[#names + 1] = (focus == ns.spokenTalkButton and "OUR PLAY BUTTON")
			or (ok and type(name) == "string" and name)
			or (focus == WorldFrame and "WorldFrame")
			or ("<anon, parent " .. tostring(focus.GetParent and focus:GetParent() and
				(pcall(focus:GetParent().GetName, focus:GetParent()) and focus:GetParent():GetName()) or "?") .. ">")
	end
	local x, y = GetCursorPosition()
	local button = ns.spokenTalkButton
	Say(("  mouse %s down at %d,%d, under it: %s; over our button %s"):format(tostring(mouseButton), x, y,
		#names > 0 and table.concat(names, ", ") or "nothing", tostring(button and Ask(button, "IsMouseOver"))))
end)

local function Hook()
	local sp = Spoken()
	if not hooked and sp and sp.RegisterCallback then
		hooked = true
		for _, event in ipairs({ "CLIP_QUEUED", "CLIP_STARTED", "CLIP_STOPPED", "CLIP_DROPPED" }) do
			pcall(sp.RegisterCallback, sp, event, function(clip, finished)
				if not run then return end
				Say(("  spoken %s %s%s"):format(event, ClipName(clip), finished ~= nil and (" finished " .. tostring(finished)) or ""))
				local note = run.current and run.notes[run.current]
				if note then note.events = (note.events or 0) + 1 end
			end)
		end
	end
	local button = ns.spokenTalkButton
	if button and hookedButton ~= button then
		hookedButton = button
		button:HookScript("OnClick", function()
			if not run then return end
			local note = run.current and run.notes[run.current]
			Say("  our Play button clicked, playing now " .. ClipName(Playing()))
			-- (What it did is read a second later, Tick: a line may start a frame on.)
			if note then
				note.clicks = (note.clicks or 0) + 1
				note.clickAt = GetTime()
			end
		end)
	end
end

local VERDICT = {}
function VERDICT.open(note)
	if not note.bubble then return "FAIL: our bubble never came up" end
	if not note.button then return "FAIL: bubble up, no Play button on it" end
	if not note.onScreen then return "FAIL: Play button shown but off the screen" end
	return "PASS: bubble up with the Play button on it, on the screen"
end
local function ClickVerdict(note)
	if (note.clicks or 0) == 0 then return "NOT DONE: the button wasn't clicked" end
	if note.playingBefore == nil then return "UNSURE: clicked in the step's first half second" end
	if note.playingAfter == nil then return "UNSURE: clicked too late to read what it did" end
	if note.playingAfter ~= note.playingBefore then
		local glyph = note.glyphAfter == note.playingAfter and "" or
			("; but its icon shows %s"):format(note.glyphAfter and "Stop" or "Play")
		return ("%s: %s -> %s%s"):format(glyph == "" and "PASS" or "FAIL", note.playingBefore and "playing" or "silent",
			note.playingAfter and "playing" or "stopped", glyph)
	end
	return ("FAIL: clicked %d times, still %s (events %d)"):format(note.clicks, note.playingAfter and "playing" or
		"silent", note.events or 0)
end
VERDICT.click, VERDICT.again = ClickVerdict, ClickVerdict
function VERDICT.fade(note)
	if not note.cine then return "FAIL: CineMode didn't come on" end
	if not note.spokenShown then return "UNSURE: none of Spoken's windows were up to fade" end
	local out = note.faded and "PASS: Spoken's windows faded" or "FAIL: Spoken's windows stayed"
	if note.modelStayed then out = out .. "; a 3D face stayed visible" end
	return out
end

-- A click in a step's last second: what it did, read as the step ends
-- (before the next one changes what's playing).
local function ReadLateClicks()
	for _, note in pairs(run.notes) do
		if note.clickAt and note.playingAfter == nil then
			note.playingAfter = Playing() ~= nil
			note.glyphAfter = ns.spokenTalkButton and ns.spokenTalkButton.playing and true or false
		end
	end
end

local function Finish(done)
	if run.ticker then run.ticker:Cancel() end
	ReadLateClicks()
	local kept = run.kept
	if run.cineByUs and ns.IsCineModeOn and ns.IsCineModeOn() then pcall(Cinematic_ToggleCineMode) end
	ns.db.questVision, ns.db.questTalk = kept.questVision, kept.questTalk
	for _, key in ipairs(ROWS) do
		if kept.rows[key] == false then pcall(ns.SetAddonFramesOn, key, false) else ns.db.addonFrames[key] = kept.rows[key] end
	end
	if ns.RefreshQuestTalk then pcall(ns.RefreshQuestTalk) end
	for _, index in ipairs(run.steps) do
		local step = STEPS[index]
		local line = ("%d %s: %s"):format(index, step.key, VERDICT[step.key](run.notes[step.key] or {}))
		Say("verdict " .. line)
		ns.Print(line)
	end
	Say("settings put back: questVision " .. tostring(kept.questVision) .. ", questTalk " .. tostring(kept.questTalk) ..
		", Spoken rows " .. tostring(kept.rows.spokenNarrator) .. "/" .. tostring(kept.rows.spokenMinimal) .. "/" ..
		tostring(kept.rows.spokenSubtitles))
	run = nil
	presses:UnregisterEvent("GLOBAL_MOUSE_DOWN")
	ns.PadTestBox(done and "Test done." or "Test stopped.", "Say \"check log\" (/reload first)", 1, 0.82, 0)
	C_Timer.After(15, function() if not run then ns.PadTestBoxHide() end end)
end

local function Tick()
	local now = GetTime() - run.at
	Hook()
	if now < SETUP then
		ns.PadTestBox("Stand NEXT TO a quest giver with a yellow ! over them. Don't talk to them yet. " ..
			"If a quest window is open, close it (Esc).",
			("Starts in %d"):format(math.ceil(SETUP - now)), 1, 0.82, 0)
		if run.step ~= 0 then
			run.step = 0
			Say("--- setup ---")
			Say(Snapshot())
		end
		return
	end
	local index = math.floor((now - SETUP) / STEP) + 1
	if index > #run.steps then
		Finish(true)
		return
	end
	local step = STEPS[run.steps[index]]
	local into = now - SETUP - (index - 1) * STEP
	if index ~= run.step then
		ReadLateClicks()
		run.step, run.current = index, step.key
		run.notes[step.key] = {}
		-- (So each click has one thing to do: start a silent line, then stop a
		-- playing one, started fresh here so it can't end by itself first.)
		local sp = Spoken()
		if (step.key == "click" or step.key == "again") and Playing() and sp then
			pcall(sp.StopAll, sp)
			Say("  stopped what was playing")
		end
		if step.key == "again" and SlashCmdList and SlashCmdList.SPOKENQUESTSREAD then
			local ok, err = pcall(SlashCmdList.SPOKENQUESTSREAD, "")
			Say("  read the quest (/spqread), so the click should stop it: " .. (ok and "ok" or tostring(err)))
		end
		Say(("--- step %d: %s ---"):format(run.steps[index], step.key))
		Say("  " .. Snapshot())
		Say("  " .. FramesLine())
	end
	local note = run.notes[step.key]
	-- Clicks count from the step's start (players click during GET READY too):
	-- the state just before the first click is what's compared, a second
	-- after it what it did. (From half a second in: a line just asked for
	-- takes a moment to count as playing.)
	if (step.key == "click" or step.key == "again") and (note.clicks or 0) == 0 and into >= 0.5 then
		note.playingBefore = Playing() ~= nil
	elseif note.clickAt and note.playingAfter == nil and GetTime() - note.clickAt >= 1 then
		note.playingAfter = Playing() ~= nil
		note.glyphAfter = ns.spokenTalkButton and ns.spokenTalkButton.playing and true or false
		Say("  a second after the click: " .. (note.playingAfter and "playing " .. ClipName(Playing()) or "silent") ..
			", button icon " .. (note.glyphAfter and "Stop" or "Play"))
	end
	if into < WAIT then
		ns.PadTestBox(step.say:format(index, #run.steps), ("GET READY: starts in %d"):format(math.ceil(WAIT - into)),
			1, 0.82, 0)
		return
	end
	ns.PadTestBox(step.say:format(index, #run.steps), ("RECORDING: %d sec left"):format(math.ceil(STEP - into)),
		0.3, 1, 0.3)
	if step.key == "fade" and not note.started then
		note.started = true
		if not Playing() and SlashCmdList and SlashCmdList.SPOKENQUESTSREAD then
			local ok, err = pcall(SlashCmdList.SPOKENQUESTSREAD, "")
			Say("  read the quest (/spqread): " .. (ok and "ok" or tostring(err)))
		end
	end
	if step.key == "fade" and not note.cineAsked and into >= WAIT + 3 then
		note.cineAsked = true
		Say("  before CineMode: " .. FramesLine())
		Say("  " .. Shot(("step %d fade BEFORE"):format(run.steps[index])))
		if not (ns.IsCineModeOn and ns.IsCineModeOn()) then
			local ok, err = pcall(Cinematic_ToggleCineMode)
			run.cineByUs = true
			Say("  CineMode toggled on: " .. (ok and "ok" or tostring(err)))
		end
	end
	local line = Snapshot()
	Say("  " .. line)
	Say("  " .. FramesLine())
	local bubble, button = _G.CinematicQuestTalkBubble, ns.spokenTalkButton
	if step.key == "open" then
		if bubble and Ask(bubble, "IsVisible") then note.bubble = true end
		if button and Ask(button, "IsVisible") then
			note.button = true
			local _, on = Rect(button)
			if on then note.onScreen = true end
			if not note.shot then
				note.shot = true
				Say("  " .. Shot(("step %d open"):format(run.steps[index])))
			end
		end
	elseif step.key == "fade" and note.cineAsked then
		note.cine = note.cine or (ns.IsCineModeOn and ns.IsCineModeOn()) or false
		if into >= WAIT + 5.5 then
			for _, name in ipairs(FRAMES) do
				local frame = _G[name]
				-- (Visible, not just shown: last run its narrator window was "shown"
				-- under a hidden parent and passed as faded.)
				if frame and Ask(frame, "IsVisible") and name ~= "SpokenDialogueUIPlayerFrame" then
					note.spokenShown = true
					local eff = Ask(frame, "GetEffectiveAlpha")
					if type(eff) == "number" and eff < 0.2 then note.faded = true end
					for _, model in ipairs(Models(frame)) do
						local m = Ask(model, "GetEffectiveAlpha")
						if Ask(model, "IsVisible") and type(m) == "number" and m > 0.5 then note.modelStayed = true end
					end
				end
			end
			if not note.shotAfter then
				note.shotAfter = true
				Say("  " .. Shot(("step %d fade AFTER"):format(run.steps[index])))
			end
		end
	end
end

-- Typed again while running: stops.
function ns.SpokenTest(args)
	if run then
		Finish(false)
		return
	end
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
	local steps = {}
	for number in (args or ""):gmatch("%d+") do
		number = tonumber(number)
		if STEPS[number] then steps[#steps + 1] = number end
	end
	if #steps == 0 then
		for i = 1, #STEPS do steps[i] = i end
	end
	CinematicDB.spokenTestLog = {}
	presses:RegisterEvent("GLOBAL_MOUSE_DOWN")
	run = { at = GetTime(), steps = steps, step = -1, notes = {},
		kept = { questVision = ns.db.questVision, questTalk = ns.db.questTalk, rows = {} } }
	ns.db.questVision, ns.db.questTalk = true, true
	for _, key in ipairs(ROWS) do
		run.kept.rows[key] = ns.db.addonFrames[key]
		pcall(ns.SetAddonFramesOn, key, true)
	end
	if ns.RefreshQuestTalk then pcall(ns.RefreshQuestTalk) end
	local sp = Spoken()
	Say(("start: game %s, Spoken %s, Spoken_Quests %s, API %s, /spqread %s, support on %s, quests part %s, " ..
		"gossip part %s, questTalk now %s (was %s), questVision was %s, gamepad %s, steps %s"):format(
		tostring((select(4, GetBuildInfo()))), tostring(loaded("Spoken")), tostring(loaded("Spoken_Quests")),
		tostring(sp and sp.IsCompatible and sp:IsCompatible(1)),
		tostring(SlashCmdList and SlashCmdList.SPOKENQUESTSREAD ~= nil), tostring(ns.AddonSupportOn("Spoken_Quests")),
		tostring(sp and sp.IsPartOn and sp:IsPartOn("quests")), tostring(sp and sp.IsPartOn and sp:IsPartOn("gossip")),
		tostring(ns.QuestVisionSetting("questTalk")), tostring(run.kept.questTalk), tostring(run.kept.questVision),
		tostring(ns.IsGamePadOn and ns.IsGamePadOn()), table.concat(steps, " ")))
	run.ticker = C_Timer.NewTicker(0.5, function()
		local ok, err = pcall(Tick)
		if not ok then
			Say("error: " .. tostring(err))
			if run then Finish(false) end
		end
	end)
	ns.Print(("Spoken test: %d sec, follow the box (type it again to stop)"):format(SETUP + #steps * STEP))
end
