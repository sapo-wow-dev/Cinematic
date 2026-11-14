-- /cine debug loretest [steps]: one run checking Lore Forever support
-- (Support/LoreForever.lua) on WoW Forever. For the run it turns Quest
-- Vision, Custom dialogue frames and Lore Forever's four rows on (put back
-- after), then, a timed step each in the big test box (Frames.lua's
-- ns.PadTestBox):
--   1 open:  talk to a quest giver: does our bubble come up with our round
--            book button on it, on the screen?
--   2 click: click it: does Lore Forever's narration start?
--   3 again: the test starts the narration; click it: does it stop?
--   4 fade:  the test plays the narration and turns CineMode on: do Lore
--            Forever's subtitles and floating player fade?
--   5 mark:  target an NPC, the test turns CineMode on: does the talk mark
--            fade like the target frame, and Willo's sky stay up? (Both show
--            only with the companion app: UNSURE without it.)
-- Every half second the log gets the bubble, our button, Lore Forever's pill
-- on the quest window (shown, play half, playing) and its frames' alpha; our
-- button's clicks as they come; a verdict per step; screenshots at the key
-- moments, named in the log. Steps as arguments (loretest 2 3) redo just
-- those. Into its own saved list, CinematicDB.loreTestLog. Dev copy only
-- (CinematicDev.toc).
local _, ns = ...

local SETUP, STEP, WAIT = 10, 15, 4 -- seconds: the first step, each step's, reading time
local FRAMES = { "LoreForeverSubtitles", "LoreForeverMiniPlayer", "LoreForeverPageSlip", "LoreForeverPinArrive",
	"LoreForeverTalkMark", "LoreForeverLiveSky" }
local ROWS = { "loreSubtitles", "lorePlayer", "loreSlip", "lorePin" } -- (switched on for the run, put back after)
-- (Each step works alone, so a redo of just some of them still opens the
-- talk first. "The NPC's words" is Quest talk's bubble.)
local TALK = "If the NPC's words aren't on screen, RIGHT-CLICK the quest giver first. "
local STEPS = {
	{ key = "open", say = "%d/%d: RIGHT-CLICK the quest giver to talk to them. Their words come up in a box " ..
		"(instead of the game's quest window). Just look: don't click anything else." },
	{ key = "click", say = "%d/%d: " .. TALK .. "Then CLICK the small round BOOK button on the TOP RIGHT " ..
		"CORNER of the box with the NPC's words, ONCE. The narrator should START." },
	{ key = "again", say = "%d/%d: " .. TALK .. "The narrator is talking: CLICK that same round book button " ..
		"ONCE. The narrator should STOP." },
	{ key = "fade", say = "%d/%d: " .. TALK .. "Then HANDS OFF: don't click anything. The test plays the " ..
		"narrator itself and checks Lore Forever's subtitles and player fade out in CineMode." },
	{ key = "mark", say = "%d/%d: Press ESC to close the NPC's words. LEFT-CLICK the quest giver to TARGET " ..
		"them (don't talk). Then HANDS OFF: the test turns CineMode on." },
}

local run -- { at, steps, step, current, notes = { [key] = {...} }, kept = {...} }

-- Your settings from before the run, put back (also saved as
-- CinematicDB.loreTestKept, so a /reload in the middle of a run still puts
-- them back at the next login).
local function PutBack(kept)
	ns.db.questVision, ns.db.questTalk = kept.questVision, kept.questTalk
	for _, key in ipairs(ROWS) do
		if kept.rows[key] == false then pcall(ns.SetAddonFramesOn, key, false) else ns.db.addonFrames[key] = kept.rows[key] end
	end
	if ns.RefreshQuestTalk then pcall(ns.RefreshQuestTalk) end
	CinematicDB.loreTestKept = nil
end
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
	local kept = CinematicDB and CinematicDB.loreTestKept
	if type(kept) == "table" and ns.db then
		kept.rows = type(kept.rows) == "table" and kept.rows or {}
		PutBack(kept)
		ns.Print("Lore Forever test: it was stopped by a reload, your Quest Vision settings are put back.")
	end
end)

local function Say(text)
	local log = CinematicDB and CinematicDB.loreTestLog
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

local function Pill() return ns.LoreForeverPill and ns.LoreForeverPill() end
local function Playing()
	local pill = Pill()
	return pill and pill.playing and true or false
end
-- Pressing Lore Forever's own play half, for the steps that need a line playing.
local function PressPill(why)
	local pill = Pill()
	if not (pill and pill.play and pill.play:IsShown()) then
		Say("  couldn't press Lore Forever's play button (" .. why .. "): " .. (pill and "no play half" or "no pill"))
		return
	end
	local ok, err = pcall(pill.play.Click, pill.play)
	Say("  pressed Lore Forever's play button (" .. why .. "): " .. (ok and "ok" or tostring(err)))
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

local function FramesLine()
	local parts = {}
	for _, name in ipairs(FRAMES) do
		local frame = _G[name]
		if frame then
			parts[#parts + 1] = ("%s visible %s alpha %s eff %s faded-by-us %s"):format(name,
				tostring(Ask(frame, "IsVisible")), Num(Ask(frame, "GetAlpha")), Num(Ask(frame, "GetEffectiveAlpha")),
				tostring(ns.IsFaded and ns.IsFaded(frame)))
		else
			parts[#parts + 1] = name .. " not made"
		end
	end
	local target = _G.TargetFrame
	parts[#parts + 1] = ("TargetFrame visible %s eff %s"):format(tostring(Ask(target, "IsVisible")),
		Num(Ask(target, "GetEffectiveAlpha")))
	return table.concat(parts, "; ")
end

local function Snapshot()
	local bubble, button, pill = _G.CinematicQuestTalkBubble, ns.loreTalkButton, Pill()
	local rect, on = Rect(button)
	return ("bubble %s; button %s, shown %s, takes mouse %s, level %s/%s, on screen %s (%s), alpha %s; " ..
		"pill %s, shown %s, play half %s, playing %s, canPlay %s; QuestFrame shown %s; target %s; CineMode %s"):format(
		bubble and (Ask(bubble, "IsVisible") and "shown" or "hidden") or "not made",
		button and "made" or "none", tostring(Ask(button, "IsVisible")), tostring(Ask(button, "IsMouseEnabled")),
		Num(Ask(button, "GetFrameLevel")), tostring(Ask(button, "GetFrameStrata")), tostring(on), rect,
		Num(Ask(button, "GetEffectiveAlpha")),
		pill and "found" or "not found", tostring(Ask(pill, "IsShown")), tostring(pill and Ask(pill.play, "IsShown")),
		tostring(pill and pill.playing), tostring(pill and pill.canPlay), tostring(Ask(_G.QuestFrame, "IsShown")),
		tostring(UnitExists("target") and UnitName("target")), tostring(ns.IsCineModeOn and ns.IsCineModeOn()))
end

-- Every mouse press while a run's on: where, and what was under the pointer,
-- so a click that never reached our button shows what took it.
local presses = CreateFrame("Frame")
presses:SetScript("OnEvent", function(_, _, mouseButton)
	if not run then return end
	local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
	local names = {}
	for _, focus in ipairs(foci) do
		local ok, name = pcall(focus.GetName, focus)
		names[#names + 1] = (focus == ns.loreTalkButton and "OUR BOOK BUTTON")
			or (ok and type(name) == "string" and name)
			or (focus == WorldFrame and "WorldFrame") or "<unnamed>"
	end
	local x, y = GetCursorPosition()
	Say(("  mouse %s down at %d,%d, under it: %s"):format(tostring(mouseButton), x, y,
		#names > 0 and table.concat(names, ", ") or "nothing"))
end)

-- Our button's clicks (once per session, logged only while a run's on).
local hookedButton
local function Hook()
	local button = ns.loreTalkButton
	if button and hookedButton ~= button then
		hookedButton = button
		button:HookScript("OnClick", function()
			if not run then return end
			local note = run.current and run.notes[run.current]
			Say("  our book button clicked, playing now " .. tostring(Playing()))
			-- (What it did is read a second later, Tick.)
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
	if not note.pill then return "FAIL: bubble up, Lore Forever's play button never found on the quest window" end
	if not note.recorded then
		return "UNSURE: that quest has no Lore Forever recording, so no book button (right): try another quest giver"
	end
	if not note.button then return "FAIL: a recording, but no book button on the bubble" end
	if not note.onScreen then return "FAIL: book button shown but off the screen" end
	return "PASS: bubble up with the book button on it, on the screen"
end
local function ClickVerdict(note)
	if (note.clicks or 0) == 0 and note.noRecording and not note.recordedSeen then
		return "UNSURE: that quest has no Lore Forever recording, so no book button (right): try another quest giver"
	end
	if (note.clicks or 0) == 0 then return "NOT DONE: the button wasn't clicked" end
	if note.playingBefore == nil then return "UNSURE: clicked in the step's first half second" end
	if note.playingAfter == nil then return "UNSURE: clicked too late to read what it did" end
	if note.playingAfter ~= note.playingBefore then
		return ("PASS: %s -> %s"):format(note.playingBefore and "playing" or "silent",
			note.playingAfter and "playing" or "stopped")
	end
	return ("FAIL: clicked %d times, still %s"):format(note.clicks, note.playingAfter and "playing" or "silent")
end
VERDICT.click, VERDICT.again = ClickVerdict, ClickVerdict
function VERDICT.fade(note)
	if not note.cine then return "FAIL: CineMode didn't come on" end
	if not note.shown then return "UNSURE: neither its subtitles nor its player were up to fade" end
	if note.stayed then return "FAIL: stayed visible: " .. note.stayed end
	return "PASS: faded: " .. table.concat(note.fadedNames, ", ")
end
function VERDICT.mark(note)
	if not note.cine then return "FAIL: CineMode didn't come on" end
	local out = {}
	if not note.markShown then
		out[#out + 1] = "talk mark UNSURE (never showed: companion app or Live game info off?)"
	elseif note.markOff then
		out[#out + 1] = "talk mark FAIL (" .. note.markOff .. ")"
	else
		out[#out + 1] = "talk mark PASS (matched the target frame)"
	end
	if not note.skyShown then
		out[#out + 1] = "sky UNSURE (never showed)"
	elseif note.skyFaded then
		out[#out + 1] = "sky FAIL (faded to " .. note.skyFaded .. ")"
	else
		out[#out + 1] = "sky PASS (stayed up)"
	end
	return table.concat(out, "; ")
end

local function ReadLateClicks()
	for _, note in pairs(run.notes) do
		if note.clickAt and note.playingAfter == nil then
			note.playingAfter = Playing()
		end
	end
end

local function CineOff()
	if run.cineByUs and ns.IsCineModeOn and ns.IsCineModeOn() then pcall(Cinematic_ToggleCineMode) end
	run.cineByUs = nil
end

local function Finish(done)
	if run.ticker then run.ticker:Cancel() end
	ReadLateClicks()
	CineOff()
	if Playing() then PressPill("stop at the end") end
	local kept = run.kept
	PutBack(kept)
	for _, index in ipairs(run.steps) do
		local step = STEPS[index]
		local line = ("%d %s: %s"):format(index, step.key, VERDICT[step.key](run.notes[step.key] or {}))
		Say("verdict " .. line)
		ns.Print(line)
	end
	Say("settings put back: questVision " .. tostring(kept.questVision) .. ", questTalk " .. tostring(kept.questTalk))
	run = nil
	presses:UnregisterEvent("GLOBAL_MOUSE_DOWN")
	ns.PadTestBox(done and "Test done." or "Test stopped.", "Say \"check log\" (/reload first)", 1, 0.82, 0)
	C_Timer.After(15, function() if not run then ns.PadTestBoxHide() end end)
end

-- CineMode on (by the test), with a screenshot just before.
local function CineOn(note, index, key)
	note.cineAsked = true
	Say("  before CineMode: " .. FramesLine())
	Say("  " .. Shot(("step %d %s BEFORE"):format(index, key)))
	if not (ns.IsCineModeOn and ns.IsCineModeOn()) then
		local ok, err = pcall(Cinematic_ToggleCineMode)
		run.cineByUs = true
		Say("  CineMode toggled on: " .. (ok and "ok" or tostring(err)))
	end
end

local function Eff(name)
	local frame = _G[name]
	if not (frame and Ask(frame, "IsVisible")) then return nil end
	local eff = Ask(frame, "GetEffectiveAlpha")
	return type(eff) == "number" and eff or nil
end

local function Tick()
	local now = GetTime() - run.at
	Hook()
	if now < SETUP then
		ns.PadTestBox("For this test, Cinematic's own quest dialogue is turned ON (your settings come back after). " ..
			"Stand NEXT TO a quest giver with a yellow ! over them (starting zones have Lore Forever's " ..
			"voices). Don't talk to them yet. If a quest window is open, close it (Esc).",
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
		CineOff()
		run.step, run.current = index, step.key
		run.notes[step.key] = { fadedNames = {} }
		-- (So each click has one thing to do: start a silent line, then stop
		-- a playing one.)
		if step.key == "click" and Playing() then PressPill("so the click starts it") end
		if step.key == "again" and not Playing() then PressPill("so the click stops it") end
		if step.key == "mark" and Playing() then PressPill("quiet for the mark step") end
		Say(("--- step %d: %s ---"):format(run.steps[index], step.key))
		Say("  " .. Snapshot())
		Say("  " .. FramesLine())
	end
	local note = run.notes[step.key]
	-- Clicks count from the step's start: the state just before the first
	-- click is what's compared, a second after it what it did.
	if (step.key == "click" or step.key == "again") and (note.clicks or 0) == 0 and into >= 0.5 then
		note.playingBefore = Playing()
	elseif note.clickAt and note.playingAfter == nil and GetTime() - note.clickAt >= 1 then
		note.playingAfter = Playing()
		Say("  a second after the click: " .. (note.playingAfter and "playing" or "silent"))
	end
	-- (A quest with no Lore Forever recording has no book button: said in
	-- the box at once, so another quest giver can be tried.)
	local say = step.say:format(index, #run.steps)
	local pill, bubble = Pill(), _G.CinematicQuestTalkBubble
	if step.key ~= "mark" and bubble and Ask(bubble, "IsVisible") and pill and Ask(pill, "IsShown") then
		if Ask(pill.play, "IsShown") then
			note.recordedSeen = true
		else
			note.noRecording = true
			say = ("%d/%d: This quest has NO Lore Forever voice, so there's no book button. Press ESC, then " ..
				"RIGHT-CLICK a different quest giver."):format(index, #run.steps)
		end
	end
	if into < WAIT then
		ns.PadTestBox(say, ("GET READY: starts in %d"):format(math.ceil(WAIT - into)), 1, 0.82, 0)
		return
	end
	ns.PadTestBox(say, ("RECORDING: %d sec left"):format(math.ceil(STEP - into)), 0.3, 1, 0.3)
	if step.key == "fade" and not note.started then
		note.started = true
		if not Playing() then PressPill("for the fade") end
	end
	if (step.key == "fade" or step.key == "mark") and not note.cineAsked and into >= WAIT + 3 then
		CineOn(note, run.steps[index], step.key)
	end
	Say("  " .. Snapshot())
	Say("  " .. FramesLine())
	local button = ns.loreTalkButton
	if step.key == "open" then
		pill = Pill()
		if bubble and Ask(bubble, "IsVisible") then note.bubble = true end
		if pill then note.pill = true end
		if pill and Ask(pill, "IsShown") and Ask(pill.play, "IsShown") then note.recorded = true end
		if button and Ask(button, "IsVisible") then
			note.button = true
			local _, on = Rect(button)
			if on then note.onScreen = true end
			if not note.shot then
				note.shot = true
				Say("  " .. Shot(("step %d open"):format(run.steps[index])))
			end
		end
	elseif note.cineAsked and into >= WAIT + 5.5 then
		note.cine = note.cine or (ns.IsCineModeOn and ns.IsCineModeOn()) or false
		if step.key == "fade" then
			note.stayed = nil
			note.fadedNames = {}
			for _, name in ipairs({ "LoreForeverSubtitles", "LoreForeverMiniPlayer" }) do
				local frame = _G[name]
				if frame and Ask(frame, "IsVisible") then
					note.shown = true
					local eff = Ask(frame, "GetEffectiveAlpha")
					if type(eff) == "number" and eff < 0.2 then
						note.fadedNames[#note.fadedNames + 1] = name
					else
						note.stayed = ("%s at %s"):format(name, Num(eff))
					end
				end
			end
		else
			local mark, target, sky = Eff("LoreForeverTalkMark"), Eff("TargetFrame"), Eff("LoreForeverLiveSky")
			if mark then
				note.markShown = true
				local want = target or 0
				note.markOff = math.abs(mark - want) > 0.15
					and ("mark %s, target frame %s"):format(Num(mark), Num(target)) or nil
			end
			if sky then
				note.skyShown = true
				note.skyFaded = sky < 0.5 and Num(sky) or nil
			end
		end
		if not note.shotAfter then
			note.shotAfter = true
			Say("  " .. Shot(("step %d %s AFTER"):format(run.steps[index], step.key)))
		end
	end
end

-- Typed again while running: stops.
function ns.LoreForeverTest(args)
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
	CinematicDB.loreTestLog = {}
	presses:RegisterEvent("GLOBAL_MOUSE_DOWN")
	run = { at = GetTime(), steps = steps, step = -1, notes = {},
		kept = { questVision = ns.db.questVision, questTalk = ns.db.questTalk, rows = {} } }
	for _, key in ipairs(ROWS) do
		run.kept.rows[key] = ns.db.addonFrames[key]
	end
	CinematicDB.loreTestKept = run.kept
	ns.db.questVision, ns.db.questTalk = true, true
	for _, key in ipairs(ROWS) do
		pcall(ns.SetAddonFramesOn, key, true)
	end
	if ns.RefreshQuestTalk then pcall(ns.RefreshQuestTalk) end
	local rows = {}
	for _, known in ipairs(ns.ADDON_FRAMES) do
		if known.addon == "LoreForever" then rows[#rows + 1] = known.key end
	end
	Say(("start: game %s, LoreForever %s, version %s, support on %s, rows [%s], Spoken_Quests %s, questTalk now %s " ..
		"(was %s), questVision was %s, steps %s"):format(
		tostring((select(4, GetBuildInfo()))), tostring(loaded("LoreForever")),
		tostring(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("LoreForever", "Version")),
		tostring(ns.AddonSupportOn("LoreForever")), table.concat(rows, " "), tostring(loaded("Spoken_Quests")),
		tostring(ns.QuestVisionSetting("questTalk")), tostring(run.kept.questTalk), tostring(run.kept.questVision),
		table.concat(steps, " ")))
	run.ticker = C_Timer.NewTicker(0.5, function()
		local ok, err = pcall(Tick)
		if not ok then
			Say("error: " .. tostring(err))
			if run then Finish(false) end
		end
	end)
	ns.Print(("Lore Forever test: %d sec, follow the box (type it again to stop)"):format(SETUP + #steps * STEP))
end
