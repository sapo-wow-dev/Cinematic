-- Shoulder Cam (shoulderCam): the camera sits over your shoulder (right, or
-- left: shoulderCamSide), you to the side of the screen. It's the game's
-- test_cameraOverShoulder offset (yards, negative for the left), which it
-- eases over to on its own (in about 0.3 s: Run 3). That's a fixed distance,
-- so the closer the camera the further aside it pushes you: 1 yard is 5% of
-- the way to the screen's edge at 15 yards away, 41% at 2 (Run 3b). So you
-- pick a spot instead (shoulderCamSpot: that share of the way from the middle
-- to the edge) and the offset follows your zoom to hold you there, eased back
-- to the middle closer than SPOT_EASE_TO yards. The game ignores that while Keep
-- Character Centered (Accessibility) is on, so that's turned off meanwhile, and
-- CameraReduceUnexpectedMovement too (the same since 11.0.2, as DynamicCam found).
-- It's one of Blizzard's experimental camera settings: writing it brings up
-- their warning, once a session, and the game clears the offset at every
-- reload and login (Forever, Run 2 of Tools/shoulder-test-plan.md), so theirs
-- would come every session. Ours instead, once ever (db.shoulderCamNoticed,
-- not part of a profile): until it's accepted nothing's written, and Cancel
-- turns the Shoulder Cam off. After that the game's warning is kept quiet
-- while it's on: its event stopped, as DynamicCam and DialogueUI do (Run 2b:
-- none at the write, a reload or a relog). The game can't be told to hear it
-- again, so after turning off it's back from the next /reload.
-- Your own settings (db.shoulderCamYours) come back as it's turned off.
-- Disable (ResetTestCvars) turns it off here too.
-- (Not ns.ApplyCVarSet: Keep Character Centered would be put back on logout.)
--
-- It's a held setting, not a camera: it doesn't move the view, so it doesn't
-- claim the camera lock. It goes to 0 (paused) while mounted
-- (shoulderCamNotMounted), indoors (shoulderCamNotIndoors) and while one of Cinematic's cameras that frame you
-- runs (shoulderCamPause): the standing-still ones (cozy, vista, fish, AFK,
-- teleport), the flight camera and its fly-bys, and the death camera, whose
-- shots are built around you in the middle, and wherever its Show in row
-- (shoulder:cam) has it off. The quest cam and Chat Cam keep
-- it: an over-the-shoulder dialogue shot is the look they're after.
local ADDON_NAME, ns = ...
local L = ns.L

-- Soft release: in the player copy it's there but locked, page and all,
-- till a tester types /cine testshoulder (db.shoulderCamTester) and reloads.
-- The dev copy always has it.
function ns.ShoulderCamUnlocked()
	return ns.isDev or (ns.db and ns.db.shoulderCamTester) and true or false
end

-- On, and not standing aside for another addon that owns the shoulder offset
-- (DynamicCam writes it with every situation change: Support/DynamicCam.lua).
local function ShoulderOn()
	if not ns.ShoulderCamUnlocked() then return false end
	if ns.FeatureYieldedTo and ns.FeatureYieldedTo("shoulderCam") then return false end
	return ns.Setting("shoulderCam")
end

local POLL = 0.2 -- seconds between checks for a pause (mounting, a camera starting)

-- Where: its Show in row (Always ticked to start with: everywhere). Off
-- there, it's paused (back behind you) as any other pause.
local ROW_KEY = "shoulder:cam"
ns.CINE_SHOW_SETTING[ROW_KEY] = "shoulderCamAlways"

local function Same(a, b)
	return a == b or (tonumber(a) ~= nil and tonumber(a) == tonumber(b))
end

-- Why it's paused now, or nil.
local function PauseReason()
	local db = ns.db
	-- (Forever's gamepad UI holds Keep Character Centered on inside the game:
	-- written 0, it reads 1 at once, no code of anyone's writing it, and no
	-- setting of the 105 about the gamepad, centering or following changes
	-- that (padscan, 2026-11-13). With it on, the offset does nothing.)
	if not ns.isRetail and ns.IsGamePadOn and ns.IsGamePadOn() then
		return "gamepad"
	end
	if not db.shoulderCamAlways then
		local ok, here = pcall(ns.RowOnNow, ROW_KEY, false, true)
		if not (ok and here) then
			return "show in"
		end
	end
	-- (ns.Flag: any of these can be secret on Forever.)
	if db.shoulderCamNotMounted and IsMounted and ns.Flag(IsMounted()) then
		return "mounted"
	end
	-- (Casting a mount: already easing out, so you're behind it by the time the
	-- mount's size comes in (it swings the offset out 2-5 times: the "mounts"
	-- run). A cast that's stopped puts it back.)
	if db.shoulderCamNotMounted and C_MountJournal and C_MountJournal.GetMountFromSpell then
		local okCast, spell = pcall(function() return select(9, UnitCastingInfo("player")) end)
		local okMount, mount = pcall(C_MountJournal.GetMountFromSpell, okCast and spell or nil)
		if okCast and spell and okMount and ns.Flag(mount ~= nil) then
			return "mounting"
		end
	end
	-- (Indoors the game pushes the camera in off the walls, and the offset jerks
	-- with each push: DynamicCam's help says so too. Back in the middle there.)
	if db.shoulderCamNotIndoors and IsIndoors and ns.Flag(IsIndoors()) then
		return "indoors"
	end
	if db.shoulderCamPause then
		if UnitOnTaxi and ns.Flag(UnitOnTaxi("player")) then
			return "flight"
		end
		if UnitIsDead and ns.Flag(UnitIsDead("player")) then
			return "dead"
		end
		local camera = ns.ActiveEvent and select(2, ns.ActiveEvent())
		if camera and camera ~= "quest" then
			return camera
		end
	end
end

-- The offset to write: yards, negative for the left shoulder; "0" paused.
local SPOT_EASE_FROM, SPOT_EASE_TO = 1, 4 -- yards: in the middle at 1, eased out to your spot by 4
local OFFSET_MOST = 15 -- yards (DynamicCam's range too)
-- Near walls the game pulls the camera in, out of our sight (the walls run,
-- 2026-11-12: GetCameraZoom read 15.0 all through, no setting stops it), and
-- an offset sized for the full distance then threw you far to the side,
-- behind a tree or off screen (3.3 yards at 15 away). So the offset stops at
-- OFFSET_SAFE: zoomed far out you sit nearer the middle than your spot, and a
-- pull-in throws you less far (right up close it still can).
local OFFSET_SAFE = 1.5 -- yards
local OFFSET_STEP = 0.02 -- yards: a smaller change to the offset isn't written
local paused -- (PauseReason at the last check, every POLL)

-- The offset that holds you at your spot at this distance (Run 3: you sit
-- yards / (distance x view width) of the way to the edge).
-- The model's size factor (Run 4): how far the game moves you for an offset,
-- as a share of how far it moves a Dwarf (a Skyborne 0.86). Ours, measured
-- (never another addon's tables): each `/cine debug shoulder sweep offsets`
-- on foot saves the one for your race and sex (db.shoulderCamScales, not part
-- of a profile), over the ones measured so far here. 1 until measured.
-- A shapeshift form is another model with its own factor: a Night Elf's bear
-- sat about twice as far out as the elf for the same offset (a 2026-11-11
-- recording: ~18% of the way to the edge, then ~35% each time bear form went
-- on, back each time it came off). So a form has its own key (race-sex-formN),
-- measured by the same sweep in that form; until then a bear goes by
-- FORM_SCALES, read off recordings, and other forms by the on-foot factor.
-- (A second recording, 18:46 that day, with 1.75 for the bear and 1 for the
-- elf and the spot at 20%: the bear rested at 21%, the elf at 16.5%.)
-- The model changes later than the form does on the way out: the game says
-- "no form" about 0.15 s before the bear's gone (that recording: with the
-- elf's offset written at once the bear swung out to ~40%, then the elf
-- snapped back to 16%). Into a form it's 0.06 to 0.1 s later (the log), and
-- an offset written at the form's change, ahead of it, jumped the whole view
-- sideways in one frame and crept back (a third recording, 18:51: a stump
-- beside you jumped 6% of the screen's width). Written in the model's own
-- frame (UNIT_MODEL_CHANGED) the game's change of factor and its ease to the
-- new offset cancel: out of bear form that way the view hardly moved. So at
-- any change of form the old factor's kept till the model's changed, or
-- SWAP_WAIT at most.
-- (That third recording, standing still: the elf rested on 20.1% with 0.82,
-- the bear on 18.4% with 1.85, so 1.70.)
-- (The cat, the zoomcurve run 2026-11-12, standing still with the elf's
-- offset held: the elf on 10.8% of the way to the edge, the cat on 20.3%,
-- so 0.82 x 20.3 / 10.8 = 1.55.)
-- (Mounts change it too: not measured yet.)
local MEASURED_SCALES = { ["Dwarf-2"] = 1, ["Skyborne-2"] = 0.86, ["NightElf-3"] = 0.82 }
-- bear, cat, dire bear: off the recordings till the sweep's run in them
local FORM_SCALES = { [5] = 1.70, [1] = 1.55, [8] = 1.70 }
local SWAP_WAIT = 0.4 -- seconds: the longest the old form's factor is kept without the model's event
local lastForm -- (the form at the last plain read: kept if a read comes back secret)
local function FormNow()
	if not GetShapeshiftFormID then return nil end
	local ok, form = pcall(function()
		local id = GetShapeshiftFormID()
		if id == nil then return false end
		return id + 0 == id and id -- (a secret one errors here: the last one's kept)
	end)
	if ok then lastForm = form or nil end
	return lastForm
end
-- The form whose model is on screen.
-- (ns.shoulderSwap: knobs for ShoulderCamTest.lua's "forms" run, which tries
-- other timings to find the one with the least bump: lead = the offset goes
-- in this long after the form's change on the way INTO a form, not at the
-- model's; boost = into a form it's pushed this share past the new offset for
-- boostFor seconds, to hurry the game's ease.
-- The first run (19:11 that day, the view's sideways move read off a fence
-- post, in 945ths of the screen's width): the game alone 1 either way; at
-- the model's change 11 one way for 8 frames going in, 4 coming out; 0.03 s
-- after the form's change (a frame or two ahead of the model) 15 the other
-- way; 50% past for 0.06 s cut the 11 short after 2 frames, then threw it 19
-- the other way, and coming out made 4 into 11. The up and down move, 12 of
-- 397, is the game's own: the same with the offset at 0.)
-- The second run (21:04, six small pushes): as built 8-9 for some 9 frames;
-- 35% past for 0.035 s and 50% past for 0.02 s both 7 for 2 frames, then
-- level, with nothing past the other way; 25% for 0.05 s and 50% for 0.035 s
-- went 5 and 7 past. Out of a form the pushes changed nothing (4-5 for 6
-- frames, as before). So SWAP_PUSH: into a form the offset's pushed that
-- share past for SWAP_PUSH_FOR. Those first 2 frames are the model already
-- changed with our offset not yet in, and no earlier write helps (above).
local SWAP_PUSH, SWAP_PUSH_FOR = 0.35, 0.035
local shownKnown, shownForm, swapBy, swapLed
local lastYards, boostFrom, boostUntil, boostBy = 0, nil, nil, nil -- (yards at the last frame; a push's start, end and share)
local function Swapped()
	if shownForm == nil then return end
	local knobs = ns.shoulderSwap
	boostBy = knobs and knobs.boost or SWAP_PUSH
	boostFrom, boostUntil = lastYards, GetTime() + (knobs and knobs.boostFor or SWAP_PUSH_FOR)
end
local function ModelForm()
	local form = FormNow()
	if not shownKnown then shownKnown, shownForm = true, form end
	if form == shownForm then
		swapBy = nil
	else
		if not swapBy then
			local knobs = ns.shoulderSwap
			local lead = knobs and shownForm == nil and knobs.lead or nil
			swapBy, swapLed = GetTime() + (lead or SWAP_WAIT), lead ~= nil
			ns.Log("shoulder", ("form: %s -> %s, waiting for %s"):format(tostring(shownForm), tostring(form),
				lead and ("%.2f s"):format(lead) or "the model"))
		elseif GetTime() >= swapBy then
			ns.Log("shoulder", swapLed and ("form: going by form %s now"):format(tostring(form))
				or ("form: no model event in %.1f s, going by form %s"):format(SWAP_WAIT, tostring(form)))
			shownForm, swapBy = form, nil
			Swapped()
		end
	end
	return shownForm
end
local function ModelSwapped()
	local was, now = shownForm, FormNow()
	shownKnown, shownForm, swapBy = true, now, nil
	if was ~= now then Swapped() end
	ns.Log("shoulder", ("model changed: form %s (was %s)"):format(tostring(shownForm), tostring(was)))
end
function ns.ShoulderModelKey()
	local _, race = UnitRace("player")
	local foot = ("%s-%s"):format(tostring(race), tostring(UnitSex("player")))
	local form = ModelForm()
	return form and ("%s-form%d"):format(foot, form) or foot, form, foot
end
function ns.ShoulderModelScale()
	local key, form, foot = ns.ShoulderModelKey()
	local scales = ns.db and ns.db.shoulderCamScales
	local saved = scales and scales[key]
	if type(saved) == "number" and saved > 0.2 then return saved, "measured here" end
	if MEASURED_SCALES[key] then return MEASURED_SCALES[key], "built in" end
	if form then
		if FORM_SCALES[form] then return FORM_SCALES[form], "estimated for this form" end
		saved = scales and scales[foot]
		if type(saved) == "number" and saved > 0.2 then return saved, "on-foot one: form not measured" end
		if MEASURED_SCALES[foot] then return MEASURED_SCALES[foot], "on-foot one: form not measured" end
	end
	return 1, "not measured"
end

-- The camera's distance as it is on screen. GetCameraZoom gives where a zoom
-- is going, at once, and the game glides the camera there (the zoomcurve run,
-- 2026-11-12, offset held: 2 yards in or out ~90% done in 0.4-0.5 s, about
-- an ease of 0.19 s), while a written offset settles in about 0.1 s. An
-- offset for the zoom's end written at once ran ahead of the camera: you went
-- sideways fast, stopped, then the zoom caught up ("staircase like"). So the
-- offset follows this, eased toward the zoom's end by ZOOM_EASE (the glide's
-- 0.19 less the offset's own 0.04). Started fresh, or after a pause, it's the
-- zoom's end at once.
local ZOOM_EASE = 0.15
local seenZoom, seenAt
local function SeenZoom()
	local target = GetCameraZoom and GetCameraZoom() or 8
	local now = GetTime()
	if not seenZoom or now - seenAt > 0.5 then
		seenZoom = target
	else
		seenZoom = target + (seenZoom - target) * math.exp(-(now - seenAt) / ZOOM_EASE)
	end
	seenAt = now
	return seenZoom
end

local function SpotYards()
	local distance = SeenZoom()
	local yards = (ns.db.shoulderCamSpot or 0.2) * distance * ns.ShoulderViewWidth() / ns.ShoulderModelScale()
	local k = math.min(1, math.max(0, (distance - SPOT_EASE_FROM) / (SPOT_EASE_TO - SPOT_EASE_FROM)))
	yards = math.min(OFFSET_SAFE, yards * k * k * (3 - 2 * k))
	-- (Just into a form: past the new offset for a moment, SWAP_PUSH.)
	if boostUntil then
		if GetTime() < boostUntil then
			return math.max(0, math.min(OFFSET_MOST, yards + boostBy * (yards - boostFrom)))
		end
		boostUntil = nil
	end
	lastYards = yards
	return yards
end

-- In and out gently: a pause (a mount, indoors, our cameras) and its end used
-- to write the whole offset at once, which the game crosses in about 0.3 s:
-- "so fast and jarring" (2026-11-13). So the offset's taken in and out over
-- BLEND_TIME, eased at both ends; turned on fresh, it eases in too.
local BLEND_TIME = 0.9
local blend, blendAt = 0, nil
local function Blend(toward)
	local now = GetTime()
	local step = blendAt and math.min(0.25, now - blendAt) / BLEND_TIME or 0
	-- (Resting all the way out, it's not asked every frame: no clock kept, so
	-- the way back in starts from its first frame, not with a jump.)
	blendAt = not (blend <= 0 and toward <= 0) and now or nil
	blend = toward > blend and math.min(toward, blend + step) or math.max(toward, blend - step)
	return blend * blend * (3 - 2 * blend)
end

local function ShoulderValue(again)
	if not again then paused = PauseReason() end
	local k = Blend(paused and 0 or 1)
	if k <= 0 then
		return "0"
	end
	local yards = SpotYards() * k
	return ("%.2f"):format(ns.db.shoulderCamSide == "left" and -yards or yards)
end

-- (The offset's following your zoom, and quiet ones (the talk turn's steps):
-- logged in full only to the detail log.)
local function Write(yours, cvar, value, quiet)
	local now = GetCVar(cvar)
	if now ~= nil and not Same(now, value) then
		if yours[cvar] == nil then
			yours[cvar] = now
		end
		local text = ("Shoulder Cam: %s %s -> %s"):format(cvar, now, value)
		if quiet or cvar == "test_cameraOverShoulder" and tonumber(now) ~= 0 and tonumber(value) ~= 0 then
			ns.LogDetail("cvar", text)
		else
			ns.Log("cvar", text)
		end
		SetCVar(cvar, value)
	end
end

local UpdateFollow -- (below: the frames that follow you)

-- The game's warning kept quiet (since WoW 12.1 its event goes through
-- GameEvent; before, UIParent heard it).
local WARNING_EVENT = "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"
local quieted
local function QuietWarning()
	if quieted then return end
	quieted = true
	local game = _G.GameEvent
	if game and game.UnregisterInternalEvent then pcall(game.UnregisterInternalEvent, WARNING_EVENT) end
	pcall(UIParent.UnregisterEvent, UIParent, WARNING_EVENT)
	ns.Log("cvar", "Shoulder Cam: the game's experimental camera warning kept quiet")
end

-- (Tools/shoulder-sim: a new session, as a reload starts this file again.)
function ns.ResetShoulderSession() quieted = nil end

-- Our notice, once: Accept and it starts; Cancel turns it off.
local asking
local function Answered(yes)
	asking = nil
	if yes then
		ns.db.shoulderCamNoticed = true
	else
		ns.db.shoulderCam = false
	end
	ns.ApplyShoulderCam()
	if ns.RefreshOptions then ns.RefreshOptions() end
end
local function AskNotice()
	if asking then return end
	asking = true
	if not StaticPopupDialogs.CINEMATIC_SHOULDER_NOTICE then
		StaticPopupDialogs.CINEMATIC_SHOULDER_NOTICE = {
			text = L["The Shoulder Cam uses one of Blizzard's experimental camera settings. The game would " ..
				"warn about it every time you log in, so Cinematic keeps that warning away while the Shoulder " ..
				"Cam is on. If the camera ever acts up, turn the Shoulder Cam off and your own camera " ..
				"settings come back."],
			button1 = ACCEPT or L["Accept"], button2 = CANCEL or L["Cancel"],
			OnAccept = function() Answered(true) end,
			OnCancel = function() Answered(false) end,
			timeout = 0, whileDead = true, hideOnEscape = false,
		}
	end
	StaticPopup_Show("CINEMATIC_SHOULDER_NOTICE")
end

-- Turn to who you talk to (shoulderCamTalkTurn). The game's own interact
-- focus (test_cameraTargetFocusInteract...) turns the camera to whoever you
-- talk to, but in about 0.2 s, a snap, and nothing sets its speed (the "talk"
-- map run, 2026-11-11, Tools/shoulder-test-plan.md). Its strengths are a
-- straight share of the turn, and it follows them while the window's open
-- (the "ramp" run): so the focus stays on with them at 0, and as a window
-- opens they're stepped up to the game's own (talk.yaw, talk.pitch) over
-- shoulderCamTalkTime seconds, eased. While one of Cinematic's cameras holds
-- the view (the quest or chat camera) they're stepped back down over the same
-- time, and up again once it's done. The way back as the window closes is
-- the game's 0.2 s, a snap: closed, the focus has no one to turn to, and
-- nothing turns the camera beforehand (the "back" run, 2026-11-12: camera
-- follow didn't move it). So after shoulderCamTalkHold seconds on them the
-- strengths glide back down at the same pace, the window still open, and the
-- close has nothing left to snap (0: they stay up till it closes). A new
-- window (the quest's text after the gossip) turns to them again. They go
-- back to 0 talk.grace after the last window closes (from gossip to a quest's
-- text, one window closes before the next opens). Its own Show in row off
-- (shoulder:cam) turns it off too; mounted, indoors and the rest don't.
local talk = {
	enable = "test_cameraTargetFocusInteractEnable",
	yawCVar = "test_cameraTargetFocusInteractStrengthYaw",
	pitchCVar = "test_cameraTargetFocusInteractStrengthPitch",
	yaw = 1, pitch = 0.75, -- (the game's defaults)
	grace = 0.6,
	open = { "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "MERCHANT_SHOW",
		"TRAINER_SHOW", "BANKFRAME_OPENED", "TAXIMAP_OPENED", "AUCTION_HOUSE_SHOW", "MAIL_SHOW",
		"GUILDBANKFRAME_OPENED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" },
	close = { "GOSSIP_CLOSED", "QUEST_FINISHED", "MERCHANT_CLOSED", "TRAINER_CLOSED", "BANKFRAME_CLOSED",
		"TAXIMAP_CLOSED", "AUCTION_HOUSE_CLOSED", "MAIL_CLOSED", "GUILDBANKFRAME_CLOSED",
		"PLAYER_INTERACTION_MANAGER_FRAME_HIDE" },
	on = false, closedAt = nil, share = 0, -- (a window open; when the last closed; how far the turn is, 0-1)
	back = false, fullAt = nil, -- (gliding back now; when the turn got all the way there)
}

local function TalkOn()
	return ShoulderOn() and ns.db.shoulderCamTalkTurn and paused ~= "show in"
end

local function SetTalkShare(yours, share)
	local k = share * share * (3 - 2 * share)
	Write(yours, talk.yawCVar, ("%.3f"):format(k * talk.yaw), true)
	Write(yours, talk.pitchCVar, ("%.3f"):format(k * talk.pitch), true)
end

-- Yours back for these (the rest of the Shoulder Cam staying on).
local function GiveBack(yours, ...)
	for i = 1, select("#", ...) do
		local cvar = select(i, ...)
		if yours[cvar] ~= nil then
			if not Same(GetCVar(cvar), yours[cvar]) then
				ns.Log("cvar", ("Shoulder Cam: %s back to %s"):format(cvar, yours[cvar]))
				SetCVar(cvar, yours[cvar])
			end
			yours[cvar] = nil
		end
	end
end

-- Closing slowly. Closing the panel before the glide back's done still
-- snapped the rest (user, 2026-11-12: "it glides back in .5 seconds"; the
-- game's 0.2 s). So the call that ends the conversation (whichever of
-- closing.calls the panel makes) is held back: the panel's gone at once, the
-- conversation stays open unseen while the turn glides back at its own pace,
-- then the held call goes. Walking off ends it on the game's side: that still
-- snaps. A new window meanwhile (another NPC, the vendor after the gossip)
-- drops the held calls (the game's moved on to it; ending it would close the
-- new one). Never in a fight; a timer ends it if the glide can't finish.
-- Wrapped only once the talk turn's first on. Each is logged ("shoulder").
-- Only gossip and quest text: a vendor, bank, mailbox, trainer or flight
-- master held open unseen would still take a bag click (an item sold or
-- banked), so those close at once and snap back as the game's do.
local closing = {
	calls = { { "C_GossipInfo", "CloseGossip" }, { nil, "CloseQuest" } },
	wrapped = false, held = {}, since = nil,
}

local function CloseNow(why)
	local held = closing.held
	if #held == 0 then return end
	closing.held = {}
	ns.Log("shoulder", ("talk close: ending the conversation now (%s, turn at %.2f, %.2f s held)"):format(why,
		talk.share, GetTime() - (closing.since or GetTime())))
	closing.passing = true
	for _, call in ipairs(held) do
		local ok, err = pcall(call.fn, unpack(call.args, 1, call.n))
		if not ok then ns.Log("shoulder", ("talk close: %s failed: %s"):format(call.label, tostring(err))) end
	end
	closing.passing = nil
end

local function WrapCloses()
	if closing.wrapped then return end
	closing.wrapped = true
	local names = {}
	for _, entry in ipairs(closing.calls) do
		local owner = entry[1] and _G[entry[1]] or (not entry[1] and _G or nil)
		local fn = owner and owner[entry[2]]
		local label = (entry[1] and entry[1] .. "." or "") .. entry[2]
		if type(fn) == "function" then
			names[#names + 1] = label
			owner[entry[2]] = function(...)
				if closing.passing or not (TalkOn() and talk.on and talk.share > 0.02) or InCombatLockdown() then
					return fn(...)
				end
				local held = closing.held
				held[#held + 1] = { fn = fn, args = { ... }, n = select("#", ...), label = label }
				if #held == 1 then
					closing.since, talk.back = GetTime(), true
					ns.Log("shoulder", ("talk close: %s held while the camera glides back (turn at %.2f)"):format(
						label, talk.share))
					local wait = (ns.db.shoulderCamTalkTime or 1.5) + 1
					C_Timer.After(wait, function() CloseNow("timer") end)
				else
					ns.Log("shoulder", ("talk close: %s held too"):format(label))
				end
			end
		end
	end
	ns.Log("shoulder", "talk close: watching " .. (#names > 0 and table.concat(names, ", ") or "nothing"))
end

-- Turn to your target (shoulderCamTargetTurn, off by default). The game's
-- enemy focus (test_cameraTargetFocusEnemy...) turns the camera toward an
-- enemy you target, but out of combat at fixed strengths it does nothing: it
-- moves only while its strengths are changing, and holds the turn after the
-- target's gone till they come back down (the "enemy" map run, retail dummy,
-- 2026-11-12, Tools/shoulder-test-plan.md). So, as with the talk turn, it's on
-- with them at 0, eased up to the game's own (aim.yaw, aim.pitch) over
-- shoulderCamTalkTime while an enemy's targeted, and down again over the same
-- time once it isn't: a slow turn there and a glide back. In a fight it's
-- untested. A target the game won't say is an enemy (secret) counts as none.
local aim = {
	enable = "test_cameraTargetFocusEnemyEnable",
	yawCVar = "test_cameraTargetFocusEnemyStrengthYaw",
	pitchCVar = "test_cameraTargetFocusEnemyStrengthPitch",
	yaw = 0.5, pitch = 0.4, -- (the game's defaults, Forever and retail)
	share = 0, had = nil, -- (how far the turn is, 0-1; whether an enemy was targeted at the last frame)
}

local function AimOn()
	return ShoulderOn() and ns.db.shoulderCamTargetTurn and paused ~= "show in"
end

local function SetAimShare(yours, share)
	local k = share * share * (3 - 2 * share)
	Write(yours, aim.yawCVar, ("%.3f"):format(k * aim.yaw), true)
	Write(yours, aim.pitchCVar, ("%.3f"):format(k * aim.pitch), true)
end

local function HasEnemy()
	return UnitExists("target") and ns.Flag(UnitCanAttack("player", "target")) or false
end

-- Frames follow you through the turn. The game won't say how far it turned
-- (or where the target is), but a click does: the target was under the
-- cursor. You slide the other way by about aim.slide of the click's x (both as
-- shares of the half-width), eased in with the turn ("aimclick" run, retail,
-- 2026-11-13: dummy at -0.8 or 0.85, you slid 13% of the width; in the middle,
-- none). Picked with a targeting key (Tab), from a unit frame or any other
-- way: no clue, so the frames stay where the offset puts you, as before.
aim.slide = 0.32
aim.turnBy = 0.47 -- (the share of the target's x the game's turn takes off, at full)
aim.farthest = 0.85 -- (the click's x it's never taken past: the furthest measured)
-- (Over the world or a nameplate: forbidden ones can't be asked, so count as a plate.)
function aim.OverWorld()
	local ok, focus = pcall(function()
		if GetMouseFoci then return GetMouseFoci()[1] end
		return GetMouseFocus and GetMouseFocus()
	end)
	if not ok or focus == nil or focus == WorldFrame then return true end
	if focus.IsForbidden and focus:IsForbidden() then return true end
	local okName, name = pcall(focus.GetName, focus)
	return okName and type(name) == "string" and name:find("^NamePlate") ~= nil or false
end
aim.mouse = CreateFrame("Frame")
pcall(aim.mouse.RegisterEvent, aim.mouse, "GLOBAL_MOUSE_DOWN")
aim.mouse:SetScript("OnEvent", function(_, _, button)
	if button ~= "LeftButton" and button ~= "RightButton" then return end
	local x = GetCursorPosition()
	local width = UIParent:GetWidth() * UIParent:GetEffectiveScale()
	aim.downAt, aim.downX, aim.downWorld = GetTime(), (x / width - 0.5) * 2, aim.OverWorld()
	aim.downButton = button
end)
for _, name in ipairs({ "TargetNearestEnemy", "TargetNearestEnemyPlayer", "TargetNearest", "TargetNearestFriend",
	"TargetNearestPartyMember", "TargetNearestRaidMember", "TargetLastTarget", "TargetLastEnemy", "TargetUnit" }) do
	if type(_G[name]) == "function" then hooksecurefunc(name, function() aim.keyAt = GetTime() end) end
end
-- (At each target change: a click's x, or none.)
function aim.Picked()
	if not HasEnemy() then return end -- (cleared: the slide eases back with the turn)
	local now, how = GetTime(), "no click or key"
	if aim.keyAt and now - aim.keyAt < 0.5 then
		aim.clickX, how = nil, "a targeting key"
	elseif aim.downAt and now - aim.downAt < 1 then
		aim.clickX = aim.downWorld and aim.downX or nil
		how = aim.downWorld and "a click" or "a click off the world (a unit frame?)"
	else
		aim.clickX = nil
	end
	aim.dragged, aim.fixedX = nil, nil
	aim.Mark()
	ns.Log("shoulder", ("target turn: picked by %s (cursor x %s, so you slide %s of the half-width) | facing %s, " ..
		"at %s, guessed %s yards away"):format(how,
		aim.clickX and ("%.3f"):format(aim.clickX) or "-", aim.clickX and ("%.3f"):format(-aim.slide * aim.clickX) or "none",
		aim.facing0 and ("%.3f"):format(aim.facing0) or "can't be read",
		aim.spot and ("%.1f, %.1f"):format(aim.spot[1], aim.spot[2]) or "can't be read", tostring(aim.yards)))
end

-- Then, as you turn and move: where the target is from you now. At the click
-- it's put in the world: the cursor's x gives its direction (the camera looking
-- your way then), and how far it is is a guess (between your spells' ranges
-- that do and don't reach it; else the game's interact ranges, out of a
-- fight; else 20 yards). Your facing (GetPlayerFacing) and where you are
-- (UnitPosition: north first, then west; facing 0 north and counting to the left) then
-- give its direction from you as you go. Either one unreadable (in an
-- instance): turning only, or just the click.
function aim.Facing()
	local ok, facing = pcall(GetPlayerFacing)
	if not ok then return nil end
	local okNumber, number = pcall(function() return facing + 0 end)
	return okNumber and number or nil
end
function aim.Spot()
	-- (Its first number is the north one: a strafe left, facing 5.13, moved it
	-- 5.0 and the second 2.2, retail 2026-11-13; the other way round reads a
	-- strafe as walking toward or away.)
	local ok, north, west = pcall(UnitPosition, "player")
	if not ok then return nil end
	local okNumber, spot = pcall(function() return { north + 0, west + 0 } end)
	return okNumber and spot or nil
end
function aim.Yards()
	-- (Your spells' ranges first: they answer in a fight too, Frames.lua.)
	local spells = ns.TargetSpellYards and ns.TargetSpellYards()
	if spells then return spells end
	if InCombatLockdown() then return 20 end
	for _, band in ipairs({ { 3, 7 }, { 2, 10 }, { 4, 20 } }) do
		local ok, near = pcall(CheckInteractDistance, "target", band[1])
		if ok and near ~= nil and not (issecretvalue and issecretvalue(near)) then
			if near then return band[2] end
		else
			return 20
		end
	end
	return 35
end
function aim.Mark()
	aim.facing0, aim.spot, aim.yards, aim.where = nil, nil, nil, nil
	if not aim.clickX then return end
	aim.facing0, aim.spot, aim.yards = aim.Facing(), aim.Spot(), aim.Yards()
	if aim.facing0 and aim.spot then
		local toward = aim.facing0 - math.atan(aim.clickX * ns.ShoulderViewWidth())
		aim.where = { aim.spot[1] + aim.yards * math.cos(toward), aim.spot[2] + aim.yards * math.sin(toward) }
	end
end
-- The click's x as it would be now (shares of the half-width; nil: none).
-- The target's direction from your facing now (radians, + right, -pi to pi),
-- or nil: no click, or your facing can't be read. (Also for ShoulderCamTest.lua.)
function aim.Angle()
	if not aim.clickX then return nil end
	local width = ns.ShoulderViewWidth()
	local facing = aim.facing0 and aim.Facing()
	if not facing then return nil end
	local angle
	local spot = aim.where and aim.Spot()
	if spot then
		local toward = math.atan2(aim.where[2] - spot[2], aim.where[1] - spot[1])
		angle = facing - toward
	else
		angle = facing - aim.facing0 + math.atan(aim.clickX * width)
	end
	return (angle + math.pi) % (2 * math.pi) - math.pi
end
ns.ShoulderAimAngle = aim.Angle

-- How far you slide with the game's turn, by how far round the target is
-- (degrees off your facing, either side), in shares of the half-width:
-- measured ("angles" run, retail, 2026-11-13, zoom 9, turning with the keys
-- and holding still at each). It grows to about 75 degrees, holds to 110 and
-- eases off behind you (160 degrees: 0.17). But near straight behind, which
-- side the target's on is a few degrees either way, and the guess (its
-- distance only a guess) put it on the wrong one: the PRD went 0.3 the other
-- way from you (2026-11-13). So from 135 degrees it eases to nothing by 165:
-- on your spot there, never on the wrong side.
aim.CURVE = { { 0, 0 }, { 15, 0.04 }, { 30, 0.12 }, { 45, 0.16 }, { 60, 0.24 }, { 75, 0.29 }, { 90, 0.29 },
	{ 110, 0.30 }, { 135, 0.24 }, { 165, 0 }, { 180, 0 } }
function aim.Slide(degrees)
	local from = aim.CURVE[1]
	for i = 2, #aim.CURVE do
		local to = aim.CURVE[i]
		if degrees <= to[1] then
			return from[2] + (to[2] - from[2]) * (degrees - from[1]) / (to[1] - from[1])
		end
		from = to
	end
	return 0
end

-- The click's x as it would be now (shares of the half-width, the one the
-- slide's worked out from: aim.slide of it; nil: none).
function aim.NowX()
	if not aim.clickX then return nil end
	local angle = aim.Angle()
	-- (No facing to go by: the click as it was, read off the same curve.)
	if not angle then angle = math.atan(aim.clickX * ns.ShoulderViewWidth()) end
	local degrees = math.deg(angle)
	local x = aim.Slide(math.abs(degrees)) / aim.slide
	return degrees < 0 and -x or x
end

local function AimTick(elapsed)
	local yours = ns.db and ns.db.shoulderCamYours
	if not (yours and AimOn()) or ns.shoulderTestHold or (ns.DialogueUICameraOn and ns.DialogueUICameraOn()) then
		return
	end
	local step = elapsed / math.max(0.1, ns.db.shoulderCamTalkTime or 1.5)
	local enemy = HasEnemy()
	if enemy ~= aim.had then
		aim.had = enemy
		ns.Log("shoulder", ("target turn: %s (target %s, attackable %s; enemy focus %s, turn %s, tilt %s, share %.2f)"):format(
			enemy and "an enemy targeted, turning to it" or "no enemy, gliding back",
			UnitExists("target") and "yes" or "none", select(2, pcall(tostring, UnitCanAttack("player", "target"))) or "secret",
			tostring(GetCVar(aim.enable)), tostring(GetCVar(aim.yawCVar)), tostring(GetCVar(aim.pitchCVar)), aim.share))
	end
	if aim.share >= 1 and not aim.full and enemy then
		aim.full = true
		ns.Log("shoulder", ("target turn: full (enemy focus %s, turn %s, tilt %s)"):format(tostring(GetCVar(aim.enable)),
			tostring(GetCVar(aim.yawCVar)), tostring(GetCVar(aim.pitchCVar))))
	elseif not enemy then
		aim.full = nil
	end
	if enemy then
		aim.share = math.min(1, aim.share + step)
	else
		aim.share = math.max(0, aim.share - step)
		if aim.share == 0 then aim.clickX = nil end
	end
	-- (The left button held on the world: the camera's being turned by itself,
	-- which nothing tells an addon (your facing stays), so the guess is lost:
	-- the frames go back to the offset's place till the next click. A plain
	-- click's down for well under 0.3 seconds.)
	-- The right button too ("follow" run, retail 2026-11-13): turning with it
	-- drops the game's turn toward the target, the camera going straight
	-- behind you (you were back on your spot a second after), so the guess,
	-- which counted on the turn, went the wrong way.
	if aim.clickX and aim.downButton and aim.downWorld and aim.downAt
		and GetTime() - aim.downAt > 0.3 and IsMouseButtonDown and IsMouseButtonDown(aim.downButton) then
		ns.Log("shoulder", ("target turn: the camera turned with the mouse (%s), the frames let go of the guess"):format(
			aim.downButton))
		aim.clickX, aim.dragged = nil, true
	end
	-- Your mouse over your target: where it is on screen now, a fresh fix
	-- (picked with Tab, it's the only one). The cursor's x is where the target
	-- sits with the game's turn partway: that turn takes off aim.turnBy of its x
	-- at full ("aimclick": 0.86 went to 0.46), so the x without it is put back.
	-- Not after a drag: that undid the game's turn (the camera stays behind
	-- you), so there's no turn left to follow.
	aim.hoverClock = (aim.hoverClock or 0) + elapsed
	if enemy and not aim.dragged and aim.hoverClock >= 0.2 and IsMouseButtonDown
		and not IsMouseButtonDown("LeftButton") and not IsMouseButtonDown("RightButton") then
		aim.hoverClock = 0
		if UnitExists("mouseover") and ns.Flag(UnitIsUnit("mouseover", "target")) and aim.OverWorld() then
			local x = GetCursorPosition()
			local seen = (x / (UIParent:GetWidth() * UIParent:GetEffectiveScale()) - 0.5) * 2
			local k = aim.share * aim.share * (3 - 2 * aim.share)
			local without = seen / math.max(0.3, 1 - aim.turnBy * k)
			without = math.max(-aim.farthest, math.min(aim.farthest, without))
			local was = aim.NowX()
			aim.clickX = without
			aim.Mark()
			if not aim.fixedX or math.abs(aim.fixedX - without) > 0.05 then
				ns.Log("shoulder", ("target turn: your mouse is over it: seen at x %.3f with the turn at %.2f, so %.3f " ..
					"without it (the guess had %s) | %s yards"):format(seen, aim.share, without,
					was and ("%.3f"):format(was) or "none", tostring(aim.yards)))
			end
			aim.fixedX = without
		end
	end
	-- (Following a click: where it thinks the target is, twice a second.)
	aim.logClock = (aim.logClock or 0) + elapsed
	if aim.clickX and aim.logClock >= 0.5 then
		aim.logClock = 0
		local facing, spot, nowX = aim.Facing(), aim.Spot(), aim.NowX()
		ns.Log("shoulder", ("target turn: following, x now %s (click %.3f), share %.2f | facing %s, at %s"):format(
			nowX and ("%.3f"):format(nowX) or "-", aim.clickX, aim.share, facing and ("%.3f"):format(facing) or "-",
			spot and ("%.1f, %.1f"):format(spot[1], spot[2]) or "-"))
	end
	SetAimShare(yours, aim.share)
end

-- Every frame while the Shoulder Cam's on.
local function TalkTick(elapsed)
	local yours = ns.db and ns.db.shoulderCamYours
	if not (yours and TalkOn()) or ns.shoulderTestHold or (ns.DialogueUICameraOn and ns.DialogueUICameraOn()) then
		CloseNow("talk turn off")
		return
	end
	if talk.on and talk.closedAt and GetTime() - talk.closedAt >= talk.grace then
		talk.on, talk.closedAt = false, nil
	end
	if not talk.on then
		talk.share, talk.back, talk.fullAt = 0, false, nil
	else
		local step = elapsed / math.max(0.1, ns.db.shoulderCamTalkTime or 1.5)
		local holder = ns.CameraHolder and ns.CameraHolder("talk")
		if talk.back or holder and holder ~= "you" then
			talk.share = math.max(0, talk.share - step)
		else
			talk.share = math.min(1, talk.share + step)
			local hold = ns.db.shoulderCamTalkHold or 0
			if talk.share >= 1 and hold > 0 then
				talk.fullAt = talk.fullAt or GetTime()
				if GetTime() - talk.fullAt >= hold then
					talk.back = true
					ns.LogDetail("cvar", "Shoulder Cam: talk turn glides back")
				end
			end
		end
	end
	SetTalkShare(yours, talk.share)
	if #closing.held > 0 and talk.share <= 0 then CloseNow("glided back") end
end

local poller = CreateFrame("Frame")
poller:Hide()

function ns.ApplyShoulderCam()
	if not ns.db then
		return
	end
	local yours = ns.db.shoulderCamYours
	if ShoulderOn() and not ns.db.shoulderCamNoticed then
		AskNotice() -- (nothing written till it's answered)
	elseif ShoulderOn() then
		QuietWarning()
		yours = yours or {}
		ns.db.shoulderCamYours = yours
		-- (DialogueUI's camera sets the same offset for its talks, and puts
		-- back what it found: hands off till it's done. Support/DialogueUI.lua.)
		if not (ns.shoulderTestHold or (ns.DialogueUICameraOn and ns.DialogueUICameraOn())) then
			-- (Gamepad mode on Forever: the game holds centering on, so these
			-- are given back rather than written five times a second, and it
			-- says why once a session.)
			if PauseReason() == "gamepad" then
				GiveBack(yours, "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement")
				if not ns.shoulderPadSaid then
					ns.shoulderPadSaid = true
					ns.Log("shoulder", "paused: Forever's gamepad UI keeps your character centered, so the offset can't work")
					ns.Print(L["Shoulder Cam is paused while the gamepad UI is on: the game keeps your character centered in it."])
				end
			else
				Write(yours, "CameraKeepCharacterCentered", "0")
				Write(yours, "CameraReduceUnexpectedMovement", "0")
			end
			Write(yours, "test_cameraOverShoulder", ShoulderValue())
			-- (The strengths at 0 before the focus goes on, so it can't snap.)
			if TalkOn() then
				SetTalkShare(yours, talk.share)
				Write(yours, talk.enable, "1")
				WrapCloses()
			else
				talk.share = 0
				GiveBack(yours, talk.enable, talk.yawCVar, talk.pitchCVar)
			end
			-- (The same for the enemy focus: at 0 before it goes on.)
			if AimOn() then
				SetAimShare(yours, aim.share)
				Write(yours, aim.enable, "1")
			else
				aim.share = 0
				GiveBack(yours, aim.enable, aim.yawCVar, aim.pitchCVar)
			end
		end
		poller:Show()
	else
		CloseNow("Shoulder Cam off")
		poller:Hide()
		if yours then
			for cvar, value in pairs(yours) do
				if not Same(GetCVar(cvar), value) then
					ns.Log("cvar", ("Shoulder Cam: %s back to %s"):format(cvar, value))
					SetCVar(cvar, value)
				end
			end
			ns.db.shoulderCamYours = nil
		end
	end
	if UpdateFollow then UpdateFollow() end
end

-- (Picks up pauses, and the page's sliders and ticks, a moment later; the
-- offset follows your zoom every frame in between.)
local waited = 0
ns.SetOnUpdate(poller, function(_, elapsed)
	TalkTick(elapsed)
	AimTick(elapsed)
	waited = waited + elapsed
	if waited >= POLL then
		waited = 0
		ns.ApplyShoulderCam()
		return
	end
	local yours = ns.db and ns.db.shoulderCamYours
	-- (Paused but still easing out: on, till it's all the way back.)
	if paused and blend <= 0 or not yours or ns.shoulderTestHold
		or (ns.DialogueUICameraOn and ns.DialogueUICameraOn()) then
		return
	end
	local value = ShoulderValue(true)
	if math.abs((tonumber(GetCVar("test_cameraOverShoulder")) or 0) - tonumber(value)) >= OFFSET_STEP then
		Write(yours, "test_cameraOverShoulder", value)
	end
end)

-- The swap shoulders key: a button its key binding clicks (bound on the
-- Shoulder Cam page; no entry in Bindings.xml, as the page is the dev copy's).
local swap = CreateFrame("Button", ADDON_NAME .. "ShoulderSwapButton", UIParent)
swap:RegisterForClicks("AnyDown")
swap:SetScript("OnClick", function()
	if not ns.db then
		return
	end
	ns.db.shoulderCamSide = ns.db.shoulderCamSide == "left" and "right" or "left"
	ns.ApplyShoulderCam()
	if ns.RefreshOptions then ns.RefreshOptions() end
end)
local SWAP_ACTION = "CLICK " .. swap:GetName() .. ":LeftButton"

-- Frames follow you (shoulderCamFrames): with you off to one side, the cast
-- bar and the Personal Resource Display slide over with you. Where you are
-- on screen can't be read (plates can't be measured), so it's worked out:
-- the game's offset now (test_cameraOverShoulder, 0 while paused) over the
-- camera's distance, as a share of half the screen's width at its field of
-- view (ns.ShoulderViewWidth). Right shoulder: you're left of the middle.
-- Measured with your chat bubble (Run 3): it holds for a standard model.
-- shoulderCamFramesStrength scales it.
-- A frame on a nameplate stays (retail's PRD on your own plate already
-- follows you), and of a chain (cast bar on the PRD, the PRD on the cooldowns:
-- Forever, Run 1) only the first of ours moves; the rest ride along. Points are kept as the game set them and
-- given back with the slide added; when the game sets them again (its
-- layout, Edit Mode), that's taken as their place from then on. Nothing
-- moves while Edit Mode is open, nor a protected frame in a fight (one
-- that a portrait hangs on: it holds still and catches up after). The
-- player, target and focus frames aren't offered: the game locks them in
-- every fight (tested on retail, 2026-11-13: /cine debug shoulder lock).
-- Which follow is the player's pick, a setting each (shoulderCamFollow<key>,
-- all on by default); one not picked that hangs on a picked
-- one still rides along with it.
local FOLLOW_GROUPS = {
	{ key = "shoulderCamFollowCast", frames = { "PlayerCastingBarFrame", "CastingBarFrame",
		"GamepadPlayerCastingBarFrame" } },
	{ key = "shoulderCamFollowPRD", frames = { "PersonalResourceDisplayFrame", "CinematicPersonalResource" } },
	{ key = "shoulderCamFollowEssential", frames = { "EssentialCooldownViewer" } },
	{ key = "shoulderCamFollowUtility", frames = { "UtilityCooldownViewer" } },
	{ key = "shoulderCamFollowBuffIcons", frames = { "BuffIconCooldownViewer" } },
	{ key = "shoulderCamFollowBuffBars", frames = { "BuffBarCooldownViewer" } },
	-- (The proc alerts round the middle (Lava Surge's curves...): not protected.)
	{ key = "shoulderCamFollowSpellAlerts", frames = { "SpellActivationOverlayFrame" } },
}
local FOLLOW_EASE = 12     -- how quickly the frames catch up (per second; the game eases over in ~0.3 s)
local FOLLOW_MAX = 0.3     -- never more than this share of the screen's width
local FOLLOW_MIN_ZOOM = 3 -- (closer, as this: in a 2026-11-07 recording at ~1.5 yards the bar went
                           -- to where your head-top is, well past your body; first person has no side)
local followed = {}        -- frame -> { points = the game's, ours = what we put on, shift = ours in UI units }
local followShift = 0      -- the slide now (UIParent units, + right), easing to the target
-- Height (shoulderCamFramesHeight, UI units, + up): the picked frames lifted
-- together, each with its own on top (<key>Height), while the camera's over
-- your shoulder; share eases 0 to 1 and back with it. A frame riding along on
-- another gets only its own (the one it rides on brings the rest).
local followLift = { share = 0 }

local function EditModeOpen()
	local editMode = _G.EditModeManagerFrame
	return editMode and editMode.IsEditModeActive and ns.Flag(editMode:IsEditModeActive()) or false
end

-- A frame's points, or nil if any can't be read plainly (secret, restricted).
local function ReadPoints(frame)
	local ok, count = pcall(frame.GetNumPoints, frame)
	if not ok or type(count) ~= "number" or count == 0 then return nil end
	local points = {}
	for i = 1, count do
		local okPoint, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, i)
		if not okPoint or type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then
			return nil
		end
		points[i] = { point, relativeTo, relativePoint, x, y }
	end
	return points
end

local function SamePoints(a, b)
	if not (a and b) or #a ~= #b then return false end
	for i = 1, #a do
		for j = 1, 3 do if a[i][j] ~= b[i][j] then return false end end
		if math.abs(a[i][4] - b[i][4]) > 0.01 or math.abs(a[i][5] - b[i][5]) > 0.01 then return false end
	end
	return true
end

-- The frames picked now (name -> its group's setting), from FOLLOW_GROUPS'.
local FOLLOWS = {}
local function PickFollows()
	local db = ns.db
	for name in pairs(FOLLOWS) do FOLLOWS[name] = nil end
	for _, group in ipairs(FOLLOW_GROUPS) do
		if db and db[group.key] then
			for _, name in ipairs(group.frames) do FOLLOWS[name] = group.key end
		end
	end
end

-- What a frame hangs on, up its chain of anchors (first points): "plate" if
-- a nameplate (it follows you already), another picked one (it rides
-- along when that one moves: never moved twice), else nil (the screen, or a
-- frame that stays put, as Forever's PRD on EssentialCooldownViewer: Run 1).
local function Hangs(frame)
	local at = frame
	for _ = 1, 8 do
		local ok, _, to = pcall(at.GetPoint, at, 1)
		if not ok or type(to) ~= "table" or to == UIParent then return nil end
		local okName, name = pcall(to.GetName, to)
		name = okName and type(name) == "string" and name or ""
		if name:find("^NamePlate") or to.UnitFrame or to.namePlateUnitToken then return "plate" end
		if FOLLOWS[name] and to ~= frame then return to end
		at = to
	end
end

-- Whether this frame is the one to move: not on a plate, and not riding
-- along with another of ours that moves.
local function Mover(frame)
	local hangs = Hangs(frame)
	if hangs == "plate" then return false end
	if hangs then return not (Hangs(hangs) ~= "plate" and ReadPoints(hangs)) end
	return true
end

-- (shift across, lift up, in UI units. False: not moved, a protected frame in a fight.)
local function Place(frame, entry, shift, lift)
	if ns.Flag(frame:IsProtected()) and InCombatLockdown() then return false end
	lift = lift or 0
	local scale = UIParent:GetEffectiveScale() / math.max(0.01, frame:GetEffectiveScale())
	local ours = {}
	frame:ClearAllPoints()
	for i, p in ipairs(entry.points) do
		ours[i] = { p[1], p[2], p[3], p[4] + shift * scale, p[5] + lift * scale }
		frame:SetPoint(p[1], p[2] or UIParent, p[3], ours[i][4], ours[i][5])
	end
	-- (Read back: what the game reports for them, to see when it moves them.)
	entry.ours, entry.shift, entry.lift = ReadPoints(frame) or ours, shift, lift
	return true
end

local function Home(entry) return entry.shift == 0 and (entry.lift or 0) == 0 end

-- Every followed frame back where the game had it, and forgotten; with keep
-- (a set of names), all but those. One that can't move yet (protected, in a
-- fight) is kept, to go back once it can.
local function PutBack(keep)
	for frame, entry in pairs(followed) do
		if not (keep and keep[frame:GetName() or ""])
			and (Home(entry) or Place(frame, entry, 0, 0)) then
			followed[frame] = nil
		end
	end
	if not keep then followShift, followLift.share = 0, 0 end
end

-- How wide the view is: the tangent of half the field of view across the
-- screen. cameraFov is across a 16:9 screen; a wider or narrower one keeps its
-- height (Run 3, Forever: a 2.39:1 ultrawide measured 0.73-0.77 of the plain
-- 16:9 sum, which says 0.74).
function ns.ShoulderViewWidth()
	local fov = math.min(120, math.max(30, tonumber(GetCVar("cameraFov")) or 90))
	local aspect = WorldFrame:GetWidth() / math.max(1, WorldFrame:GetHeight())
	return math.tan(math.rad(fov / 2)) * aspect / (16 / 9)
end

-- With you as your own target the game puts you back in the middle by itself,
-- the offset setting untouched (2026-11-11, Forever: the log kept 2.02 while a
-- recording showed you ease to the middle over ~0.5 s): the frames go with you.
local function YouAreTarget()
	return UnitIsUnit and ns.Flag(UnitIsUnit("target", "player")) or false
end

local function TargetShift()
	local db = ns.db
	if not (db and ShoulderOn() and db.shoulderCamFrames) then return 0 end
	if YouAreTarget() then return 0 end
	local yards = tonumber(GetCVar("test_cameraOverShoulder")) or 0
	if yards == 0 then return 0 end
	local distance = math.max(FOLLOW_MIN_ZOOM, GetCameraZoom and GetCameraZoom() or 5)
	local half = UIParent:GetWidth() / 2
	local shift = -yards * ns.ShoulderModelScale() / (distance * ns.ShoulderViewWidth()) * half
		* (db.shoulderCamFramesStrength or 1)
	-- (Turned toward a target you clicked: the other way by a share of the click's x, aim above.)
	local nowX = aim.clickX and AimOn() and db.shoulderCamTargetFollow ~= false and aim.NowX()
	if nowX then
		local k = aim.share * aim.share * (3 - 2 * aim.share)
		shift = shift - aim.slide * nowX * k * half * (db.shoulderCamFramesStrength or 1)
	end
	local most = UIParent:GetWidth() * FOLLOW_MAX
	return math.max(-most, math.min(most, shift))
end

local follower = CreateFrame("Frame")
follower:Hide()
ns.SetOnUpdate(follower, function(self, elapsed)
	if EditModeOpen() then
		PutBack()
		return
	end
	local target = TargetShift()
	followShift = followShift + (target - followShift) * math.min(1, elapsed * FOLLOW_EASE)
	if math.abs(target - followShift) < 0.25 then followShift = target end
	-- (Height: in while over your shoulder, at the slide's pace.)
	local db = ns.db
	local over = db and ShoulderOn() and db.shoulderCamFrames
		and (tonumber(GetCVar("test_cameraOverShoulder")) or 0) ~= 0 and 1 or 0
	followLift.share = followLift.share + (over - followLift.share) * math.min(1, elapsed * FOLLOW_EASE)
	if math.abs(over - followLift.share) < 0.01 then followLift.share = over end
	local master = db and db.shoulderCamFramesHeight or 0
	PickFollows()
	-- (No longer picked: back on its place.)
	PutBack(FOLLOWS)
	for name, key in pairs(FOLLOWS) do
		local frame = _G[name]
		if type(frame) == "table" and frame.GetPoint then
			local entry, now = followed[frame], ReadPoints(frame)
			-- (Moved by the game since: its new place.)
			if now and (not entry or not SamePoints(now, entry.ours)) then
				entry = { points = now, ours = now, shift = 0, lift = 0 }
				followed[frame] = entry
			end
			-- (Riding along with another, or on a plate: only its own height;
			-- none: back on its own place, kept till it can go if protected in a fight.)
			local mover = Mover(frame)
			local own = db and db[key .. "Height"] or 0
			local shift = mover and followShift or 0
			local lift = ((mover and master or 0) + own) * followLift.share
			if entry and not mover and math.abs(lift) < 0.5 then
				if Home(entry) or Place(frame, entry, 0, 0) then followed[frame] = nil end
				entry = nil
			end
			if entry and (math.abs(entry.shift - shift) >= 0.5 or math.abs((entry.lift or 0) - lift) >= 0.5) then
				Place(frame, entry, shift, lift)
			end
		end
	end
	-- (Back home and nothing more wanted: stop; not while one is still out.)
	if target == 0 and followShift == 0 and followLift.share == 0 then
		PutBack()
		if not next(followed) then self:Hide() end
	end
end)

function UpdateFollow()
	if ns.db and ShoulderOn() and ns.db.shoulderCamFrames or next(followed) then
		follower:Show()
	end
end

-- For /cine debug shoulder.
function ns.GetShoulderCamDebug()
	local db = ns.db
	return {
		setting = db and db.shoulderCam, applied = db and db.shoulderCamYours ~= nil,
		shoulder = GetCVar("test_cameraOverShoulder"), centered = GetCVar("CameraKeepCharacterCentered"),
		side = db and db.shoulderCamSide, spot = db and db.shoulderCamSpot, model = ns.ShoulderModelKey(),
		scale = (ns.ShoulderModelScale()), scaleFrom = select(2, ns.ShoulderModelScale()),
		follow = db and db.shoulderCamFrames, followShift = followShift, followTarget = TargetShift(),
		followLift = followLift.share, followHeight = db and db.shoulderCamFramesHeight,
		youTarget = YouAreTarget(),
		picked = (function()
			local keys = {}
			for _, group in ipairs(FOLLOW_GROUPS) do
				if db and db[group.key] then keys[#keys + 1] = group.key:gsub("^shoulderCamFollow", "") end
			end
			return #keys > 0 and table.concat(keys, ", ") or "none"
		end)(),
		followed = (function()
			local names = {}
			for frame in pairs(followed) do names[#names + 1] = frame:GetName() or "?" end
			return #names > 0 and table.concat(names, ", ") or "none"
		end)(),
		paused = db and PauseReason() or "no", always = db and db.shoulderCamAlways, key = GetBindingKey(SWAP_ACTION) or "none",
		talkTurn = db and db.shoulderCamTalkTurn, talking = talk.on, talkShare = talk.share, talkBack = talk.back,
		targetTurn = db and db.shoulderCamTargetTurn, aimShare = aim.share, enemyTargeted = HasEnemy(), aimClickX = aim.clickX, aimNowX = aim.NowX(),
		enemyFocus = GetCVar(aim.enable), enemyYaw = GetCVar(aim.yawCVar), enemyPitch = GetCVar(aim.pitchCVar),
		focus = GetCVar(talk.enable), focusYaw = GetCVar(talk.yawCVar), focusPitch = GetCVar(talk.pitchCVar),
	}
end

-- The warning's Disable: the game has put the experimental settings back
-- itself, so the switch goes off and the rest of yours come back.
if ResetTestCvars then
	hooksecurefunc("ResetTestCvars", function()
		if ns.db and ns.db.shoulderCam then
			ns.db.shoulderCam = false
			if ns.db.shoulderCamYours then
				ns.db.shoulderCamYours.test_cameraOverShoulder = nil
			end
			ns.ApplyShoulderCam()
			ns.Print(L["Shoulder Cam turned off: the game's experimental camera warning was disabled."])
			if ns.RefreshOptions then ns.RefreshOptions() end
		end
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
-- (Going in or out: at once, not at the next poll.)
pcall(events.RegisterEvent, events, "ZONE_CHANGED_INDOORS")
pcall(events.RegisterEvent, events, "ZONE_CHANGED")
-- (Into or out of a form: the game moves you at once, so the new offset goes
-- in at once too, not at the next poll.)
pcall(events.RegisterEvent, events, "UPDATE_SHAPESHIFT_FORM")
pcall(events.RegisterUnitEvent, events, "UNIT_MODEL_CHANGED", "player")
-- (A window open with an NPC, or something to use: the talk turn.)
local TALK_EVENT = {}
for _, event in ipairs(talk.open) do
	if pcall(events.RegisterEvent, events, event) then TALK_EVENT[event] = "open" end
end
for _, event in ipairs(talk.close) do
	if pcall(events.RegisterEvent, events, event) then TALK_EVENT[event] = "close" end
end
events:SetScript("OnEvent", function(_, event)
	if TALK_EVENT[event] == "open" then
		if not talk.on then ns.LogDetail("cvar", ("Shoulder Cam: talk turn starts (%s)"):format(event)) end
		if #closing.held > 0 then
			ns.Log("shoulder", ("talk close: %d held call(s) dropped, %s opened"):format(#closing.held, event))
			closing.held = {}
		end
		-- (A new window: toward them again, from wherever the turn is.)
		talk.on, talk.closedAt, talk.back, talk.fullAt = true, nil, false, nil
	elseif TALK_EVENT[event] == "close" then
		if talk.on and not talk.closedAt then talk.closedAt = GetTime() end
	elseif event == "UNIT_MODEL_CHANGED" then
		ModelSwapped()
		ns.ApplyShoulderCam()
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- (Yourself targeted or not: the frames glide to the middle or back.)
		if AimOn() then aim.Picked() end
		if UpdateFollow then UpdateFollow() end
	else
		if event == "PLAYER_ENTERING_WORLD" then talk.on, talk.closedAt = false, nil end
		ns.ApplyShoulderCam()
	end
end)

function ns.CreateShoulderCamPanel(kit)
	if not ns.ShoulderCamUnlocked() then return end -- (no page: locked, above)
	-- (A check given its own change function saves nothing itself: this saves, then runs it.)
	local function SaveThen(key, fn) return function(value) ns.GetDB()[key] = value; fn() end end
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L["Shoulder Cam"])
	title:SetPoint("TOPLEFT", 16, -16)
	local intro = kit.PageIntro(content, title,
		L["The camera sits over your shoulder, with you to one side of the screen."])
	local switch = kit.PageSwitch(content, "shoulderCam", L["Enable Page"],
		L["On: the camera moves over your shoulder. This uses one of Blizzard's experimental " ..
		"camera settings: the game shows its experimental camera warning (Accept keeps it working). " ..
		"The game's Keep Character Centered and motion sickness options stop it, so those are turned " ..
		"off meanwhile. Off: your own settings come back."], intro, ns.ApplyShoulderCam)
	local function IfOn() return ns.Setting("shoulderCam") end
	-- (Two folder tabs: the camera's settings, built on content as before and
	-- moved onto the first tab (Adopt, below), and the frames that follow you.)
	-- (A third on Forever, which has a gamepad UI: why it's not for that yet.)
	local tabList = {
		{ L["Shoulder Cam"], L["Where the camera sits, when it turns, and when it steps back behind you."] },
		{ L["Frames"], L["Which frames slide with you as the camera sits over your shoulder."] },
	}
	if not ns.isRetail then
		tabList[3] = { L["Gamepad"], L["Playing with the gamepad UI on."] }
	end
	local tabHosts, _, TabsShown, Adopt = ns.PageTabsBelow(content, switch, tabList, "Shoulder Cam/page", nil, nil, 1)
	local stack = kit.Stack(switch, "check")

	local header = stack:Header(content, L["Show in"])
	local lastRow = ns.ShowTable(content, header, {
		opts = { quiet = true, cam = true, anyFight = true }, underHeader = true,
		{ key = ROW_KEY, label = L["Shoulder Cam"], alwaysKey = "shoulderCamAlways",
			alwaysOn = function() return ns.GetDB().shoulderCamAlways end,
			setAlways = function(value) ns.GetDB().shoulderCamAlways = value ns.ApplyShoulderCam() end,
			alwaysTip = L["Over your shoulder wherever you are. (The other columns then have nothing to add.)"],
			apply = ns.ApplyShoulderCam },
	}, L["Shoulder Cam"])
	stack:Continue(lastRow, "label")

	stack:Header(content, L["Shoulder"])
	local spot = stack:Add(kit.Slider(content, "shoulderCamSpot", L["Spot on screen"], 5, 40, 1, "%d%%", 100),
		"slider")
	kit.Tooltip(spot, L["How far off the middle of the screen you sit, as a share of the way to its edge. " ..
		"The camera moves as you zoom to keep you there, and eases you back to the middle when you zoom " ..
		"right in. 33% puts you on the line a third of the way across."])
	kit.GreyUnless(spot, IfOn)
	stack:Add(kit.Label(content, "GameFontHighlight", L["Side"]), "label")
	for _, side in ipairs({ { "right", L["Right shoulder"] }, { "left", L["Left shoulder"] } }) do
		kit.GreyUnless(stack:Add(kit.Choice(content, "shoulderCamSide", side[1], side[2],
			L["Which shoulder the camera looks over. The swap key below flips it."]), "check"), IfOn)
	end
	local keyLabel = stack:Add(kit.Label(content, "GameFontHighlight", L["Swap shoulders key"]), "label")
	local key = kit.CreateKeybindButton(content, SWAP_ACTION, 1)
	key:SetPoint("LEFT", keyLabel, "LEFT", 200, 0)

	stack:Header(content, L["Turning"])
	kit.GreyUnless(stack:Add(kit.Check(content, "shoulderCamTalkTurn", L["Turn to who you talk to"],
		L["As you talk to an NPC (or open a vendor, bank, flight master or mailbox), the camera turns " ..
		"slowly to bring them toward the middle of the screen, and glides back at the same pace as you " ..
		"close the window. " ..
		"It steps aside while Cinematic's quest or chat camera moves the view."], SaveThen("shoulderCamTalkTurn", ns.ApplyShoulderCam)), "check"), IfOn)
	local function IfTalk() return ns.Setting("shoulderCam") and ns.GetDB().shoulderCamTalkTurn end
	kit.GreyUnless(stack:Add(kit.Check(content, "shoulderCamTargetTurn", L["Turn to your target"],
		L["As you target an enemy, the camera turns slowly toward it, and glides back at the same pace " ..
		"once you clear your target or pick a friendly one. Not tried in a fight yet."],
		SaveThen("shoulderCamTargetTurn", ns.ApplyShoulderCam)), "check"), IfOn)
	local talkTime = stack:Add(kit.Slider(content, "shoulderCamTalkTime", L["Turn takes"], 0.5, 4, 0.5,
		L["%.1f sec"]), "slider")
	kit.Tooltip(talkTime, L["How long the turn toward them (or your target) takes, and the glide back."])
	kit.GreyUnless(talkTime, function()
		return ns.Setting("shoulderCam") and (ns.GetDB().shoulderCamTalkTurn or ns.GetDB().shoulderCamTargetTurn)
	end)
	local talkHold = stack:Add(kit.Slider(content, "shoulderCamTalkHold", L["Look at them for"], 0, 10, 0.5,
		L["%.1f sec"]), "slider")
	kit.Tooltip(talkHold, L["At 0 the camera stays on them till you close the window. Set a time and it " ..
		"glides back on its own after that long, the window still open."])
	kit.GreyUnless(talkHold, IfTalk)

	stack:Header(content, L["Pause"])
	kit.GreyUnless(stack:Add(kit.Check(content, "shoulderCamNotMounted", L["Not while mounted"],
		L["On a mount the camera stays straight behind you: a big mount's head fills the shot from " ..
		"the side."]), "check"), IfOn)
	kit.GreyUnless(stack:Add(kit.Check(content, "shoulderCamNotIndoors", L["Not indoors"],
		L["Inside buildings and caves the camera goes back behind you, and comes back out over your " ..
		"shoulder as you step outside. Near walls the game pushes the camera in, and with it off to " ..
		"the side it jerks."]), "check"), IfOn)
	kit.GreyUnless(stack:Add(kit.Check(content, "shoulderCamPause", L["Not during Cinematic's cameras that frame you"],
		L["While the standing-still, AFK, flight, fly-by or death camera runs, the camera goes back " ..
		"behind you, as their shots are built around you in the middle. It comes back as they end. " ..
		"The quest and chat cameras keep it."]), "check"), IfOn)
	Adopt(switch) -- (all of the above onto the first tab)

	-- The Frames tab: built on its own frame, from its top.
	local frames = tabHosts[2]
	local top = CreateFrame("Frame", nil, frames)
	top:SetSize(1, 1)
	top:SetPoint("TOPLEFT", frames, "TOPLEFT", 0, 1)
	local fstack = kit.Stack(top, "check")
	kit.GreyUnless(fstack:Add(kit.Check(frames, "shoulderCamFrames", L["Frames follow you"],
		L["The frames ticked below slide over to where you are on the screen, and " ..
		"glide back as the camera goes behind you. Edit Mode still places them: this moves them from " ..
		"there."], SaveThen("shoulderCamFrames", UpdateFollow)), "check"), IfOn)
	local function IfFollow() return ns.Setting("shoulderCam") and ns.GetDB().shoulderCamFrames end
	local FRAME_TIP = L["Slides with you. A frame placed on it in Edit Mode slides along with it, ticked or not."]
	local labels = {
		shoulderCamFollowCast = L["Cast bar"],
		shoulderCamFollowPRD = L["Personal Resource Display"],
		shoulderCamFollowEssential = L["Cooldowns: essential"],
		shoulderCamFollowUtility = L["Cooldowns: utility"],
		shoulderCamFollowBuffIcons = L["Tracked buffs: icons"],
		shoulderCamFollowBuffBars = L["Tracked buffs: bars"],
		shoulderCamFollowSpellAlerts = L["Spell alerts"],
	}
	local height = fstack:Add(kit.Slider(frames, "shoulderCamFramesHeight", L["Height (all)"], -200, 200, 5, "%+d"),
		"slider")
	kit.Tooltip(height, L["Raises (or lowers) all the ticked frames together while the camera is over your " ..
		"shoulder; they glide back down as it goes behind you. Each one's own slider, on its row, adds to this."])
	kit.GreyUnless(height, IfFollow)
	local OWN_TIP = L["This frame's own height, on top of Height (all). A frame placed on it in Edit Mode moves " ..
		"with it."]
	for _, group in ipairs(FOLLOW_GROUPS) do
		local key = group.key
		local check = fstack:Add(kit.Check(frames, key, labels[key], FRAME_TIP,
			SaveThen(key, function()
				UpdateFollow()
				kit.Refresh() -- (its height slider greys out or back)
			end)), "check", 16)
		kit.GreyUnless(check, IfFollow)
		-- (Its own height, on its row: the value to the slider's right.)
		local own = kit.Slider(frames, key .. "Height", "", -100, 100, 5, "%+d")
		own:SetWidth(120)
		own:SetPoint("LEFT", check, "LEFT", 250, 0)
		own.title:ClearAllPoints()
		own.title:SetPoint("LEFT", own, "RIGHT", 8, 0)
		kit.Tooltip(own, OWN_TIP)
		kit.GreyUnless(own, function() return IfFollow() and ns.GetDB()[key] end)
	end
	local strength = fstack:Add(kit.Slider(frames, "shoulderCamFramesStrength", L["Follow strength"], 0, 200, 5,
		"%d%%", 100), "slider")
	kit.Tooltip(strength, L["How far they slide. Where you are on the screen is worked out from the camera, " ..
		"not read: if they land short of you or past you, turn this up or down."])
	kit.GreyUnless(strength, IfFollow)
	-- (With Turn to your target, on the first tab.)
	fstack:Header(frames, L["Turning"])
	kit.GreyUnless(fstack:Add(kit.Check(frames, "shoulderCamTargetFollow", L["Frames follow the turn"],
		L["Your cast bar and Personal Resource Display slide along with you as the camera turns toward " ..
		"your target. The game doesn't say how far it turned, so this works it out from where you clicked: " ..
		"picked with Tab, they join in once your mouse passes over it. Experimental: dragging the camera " ..
		"with the mouse loses it till you pick a target again."], SaveThen("shoulderCamTargetFollow", UpdateFollow)), "check"),
		function()
			local db = ns.GetDB()
			return ns.Setting("shoulderCam") and db.shoulderCamTargetTurn and db.shoulderCamFrames
		end)

	-- The Gamepad tab (Forever): not supported at the moment. The game keeps
	-- your character centered while its gamepad UI is on, so the Shoulder Cam
	-- pauses then (PauseReason, "gamepad").
	if tabHosts[3] then
		local pad = tabHosts[3]
		local padTop = CreateFrame("Frame", nil, pad)
		padTop:SetSize(1, 1)
		padTop:SetPoint("TOPLEFT", pad, "TOPLEFT", 0, 1)
		local pstack = kit.Stack(padTop, "check")
		pstack:Header(pad, L["Not supported at the moment"])
		pstack:Note(pad, L["The Shoulder Cam doesn't work with the gamepad UI yet. While it's on, the game keeps your " ..
			"character in the middle of the screen, so the Shoulder Cam waits behind you and comes back by itself when " ..
			"you turn the gamepad UI off (Options > Gamepad (Beta) > Enable Gamepad UI)."], 440)
	end

	canvas:SetScript("OnShow", kit.PageShown(function()
		kit.Refresh()
		kit.RefreshKeybinds()
		TabsShown()
	end, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Shoulder Cam")
end
