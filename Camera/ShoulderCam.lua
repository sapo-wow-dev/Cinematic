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
-- Keep Character Centered and the motion sickness option go back to yours at
-- every logout and reload, and off again as the next session starts
-- (GiveBackForLogout), so Cinematic not loading again never leaves them off.
--
-- It's a held setting, not a camera: it doesn't move the view, so it doesn't
-- claim the camera lock. It goes to 0 (paused) where its Show in row's off
-- (indoors, in an instance or mounted to start with: ROW_KEY's rule) and while one of Cinematic's cameras that frame you
-- runs, unless its tick on the Cameras tab allows it (shoulderCamAllow<Cam>,
-- ALLOW_OF below: all off to start with): the standing-still ones (cozy,
-- vista, fish, AFK, teleport), the flight camera and its fly-bys, the death
-- camera, and your own, whose shots were built around you in the middle;
-- and wherever its Show in row (shoulder:cam) has it off. The quest cam and
-- Chat Cam keep it: an over-the-shoulder dialogue shot is the look they're
-- after. (Allowed, a turn round you keeps you on your spot: the offset is
-- across the camera's own view, so only their zooms move you, and the
-- offset follows those. A flight's mount scales the offset as a mount does,
-- not measured yet: the "cams" sim session.)
local _, ns = ...
ns.Module("cameras", function() -- (the rest of this file: only with Cameras loaded, Modules.lua)
local L = ns.L

-- Soft release 2026-11-13 to 2026-11-15: locked in the player copy, page and
-- all, till a tester typed /cine testshoulder. Everyone's since; kept as a
-- function for the places that asked.
function ns.ShoulderCamUnlocked()
	return true
end

-- On, and not standing aside for another addon that owns the shoulder offset
-- (DynamicCam writes it with every situation change: Support/DynamicCam.lua).
-- (demo: the welcome window's See it first test running, ns.ShoulderCamDemo
-- below: on for it with the setting off, nothing of yours changed.)
local demo
local function ShoulderOn()
	if not ns.ShoulderCamUnlocked() then return false end
	if ns.FeatureYieldedTo and ns.FeatureYieldedTo("shoulderCam") then return false end
	return demo ~= nil or ns.Setting("shoulderCam")
end

local POLL = 0.2 -- seconds between checks for a pause (mounting, a camera starting)

-- Where: its Show in row. Off there, it's paused (back behind you) as any
-- other pause. Its rule to start with: not on a mount (a big mount's head
-- fills the shot from the side) and not indoors (walls push the camera in,
-- and off to the side it jerks: DynamicCam's help says so too). Those were
-- two Pause boxes till 2026-11-13 (shoulderCamNotMounted, NotIndoors): moved
-- into the rule once (MovePauseBoxes).
local ROW_KEY = "shoulder:cam"
ns.CINE_SHOW_SETTING[ROW_KEY] = "shoulderCamAlways"
ns.RULE_DEFAULTS[ROW_KEY] = "(not indoors and not mounted) or instance" -- (since 2026-11-17, user: on in instances too)
local function MovePauseBoxes(db)
	if db.shoulderPauseMoved then return end
	db.shoulderPauseMoved = true
	local mounted, indoors = db.shoulderCamNotMounted ~= false, db.shoulderCamNotIndoors ~= false
	db.shoulderCamNotMounted, db.shoulderCamNotIndoors = nil, nil
	-- (Always ticked, as it started: the boxes were all there was. Ticks of
	-- your own: kept as they are.)
	if db.shoulderCamAlways == false then return end
	db.shoulderCamAlways = false
	db.frameRules = db.frameRules or {}
	db.frameRules[ROW_KEY] = (mounted and indoors and "not mounted and not indoors") or (mounted and "not mounted")
		or (indoors and "not indoors") or "always"
end
-- Whether its row turns it off on a mount here (as if you were mounted): a
-- mount being cast eases it out early then.
function ns.ShoulderPausedMounted()
	if ns.db.shoulderCamAlways or not (ns.RuleFactsNow and ns.RuleShows) then return false end
	local ok, off = pcall(function()
		local facts = ns.RuleFactsNow()
		local was = facts.mounted
		facts.mounted = true
		local shows = ns.RuleShows(ROW_KEY, facts)
		facts.mounted = was
		return shows == false
	end)
	return ok and off or false
end

-- Each of our cameras (its key as ns.ScriptStandIn gives it, "yours" for any
-- other script or shot) and the setting that keeps the Shoulder Cam on through
-- it. The quest cam and Chat Cam always do; the RP walk and auto-run cameras
-- play while you move, never a pause.
local ALLOW_OF = { vista = "shoulderCamAllowVista", fish = "shoulderCamAllowFish", cozy = "shoulderCamAllowCozy",
	idle = "shoulderCamAllowAFK", tele = "shoulderCamAllowTele", flight = "shoulderCamAllowFlight",
	death = "shoulderCamAllowDeath", yours = "shoulderCamAllowYours",
	-- (Always kept till 2026-11-15; a tick each since, walk and run on: user.)
	walk = "shoulderCamAllowWalk", run = "shoulderCamAllowRun", quest = "shoulderCamAllowQuest",
	chatcam = "shoulderCamAllowChat" }
local PLAYING_CAMS = { walk = true, run = true, quest = true, chatcam = true } -- (by ns.activeCam: PauseReason)
local function CameraKey(camera)
	if camera == "afk" then return "idle" end
	if camera == "script:flyby" then return "flight" end -- (a fly-by of its own: the flight camera's)
	local key = ns.ScriptStandIn and ns.ScriptStandIn(camera) or ALLOW_OF[camera] and camera
	return key or "yours"
end

local function Same(a, b)
	return a == b or (tonumber(a) ~= nil and tonumber(a) == tonumber(b))
end

-- Why it's paused now, or nil.
-- With you as your own target the game puts you back in the middle by itself,
-- the offset setting untouched (2026-11-11, Forever: the log kept 2.02 while a
-- recording showed you ease to the middle over ~0.5 s): the frames go with you.
-- It's not a setting: nothing of the camera's changes, and the offset's not
-- used at all then, even doubled (the selftarget run, 2026-11-15). So it's a
-- pause of ours ("yourself"): the offset eased out unseen, and as the target
-- goes, eased back in over shoulderCamSelfTime instead of the game's snap.
local function YouAreTarget()
	return UnitIsUnit and ns.Flag(UnitIsUnit("target", "player")) or false
end

-- (Back after: backIn.off, why its row was off at the last check; backIn.from,
-- when it came on again.)
local backIn = {}
local function PauseReason()
	local db = ns.db
	-- (Forever's gamepad UI holds Keep Character Centered on inside the game:
	-- written 0, it reads 1 at once, no code of anyone's writing it, and no
	-- setting of the 105 about the gamepad, centering or following changes
	-- that (padscan, 2026-11-13). With it on, the offset does nothing.)
	if not ns.isRetail and ns.IsGamePadOn and ns.IsGamePadOn() then
		return "gamepad"
	end
	-- (The test: wherever you are, till it eases back out at its end.)
	if demo then
		return demo.ending and "demo" or nil
	end
	MovePauseBoxes(db)
	if not db.shoulderCamAlways then
		local ok, here = pcall(ns.RowOnNow, ROW_KEY, false, true)
		if not (ok and here) then
			-- (ns.Flag: either can be secret on Forever. The likely why, for the log.)
			local why = (IsMounted and ns.Flag(IsMounted()) and "mounted")
				or (IsIndoors and ns.Flag(IsIndoors()) and "indoors") or "show in"
			backIn.off, backIn.from = why, nil
			return why
		end
		-- (Back after: its row on again, it waits shoulderCamBackAfter
		-- seconds before coming back in, user 2026-11-17: "going straight
		-- away to shoulder cam after going outside can be a bit jarring".
		-- Back off in that time, at a doorway, the wait starts over.)
		if backIn.off then
			backIn.from = GetTime()
			local wait = math.max(0, tonumber(db.shoulderCamBackAfter) or 0)
			if wait > 0 then
				ns.Log("shoulder", ("back over your shoulder in %.1f s (%s ended)"):format(wait, backIn.off))
			end
			backIn.off = nil
		end
		if backIn.from then
			if GetTime() - backIn.from < math.max(0, tonumber(db.shoulderCamBackAfter) or 0) then
				return "waiting"
			end
			backIn.from = nil
		end
	else
		backIn.off, backIn.from = nil, nil
	end
	-- (Casting a mount its row's off on: already easing out, so you're behind
	-- it by the time the mount's size comes in (it swings the offset out 2-5
	-- times: the "mounts" run). A cast that's stopped puts it back.)
	if C_MountJournal and C_MountJournal.GetMountFromSpell then
		local okCast, spell = pcall(function() return select(9, UnitCastingInfo("player")) end)
		local okMount, mount = pcall(C_MountJournal.GetMountFromSpell, okCast and spell or nil)
		if okCast and spell and okMount and ns.Flag(mount ~= nil) and ns.ShoulderPausedMounted() then
			return "mounting"
		end
	end
	if not db.shoulderCamAllowFlight and UnitOnTaxi and ns.Flag(UnitOnTaxi("player")) then
		return "flight"
	end
	if not db.shoulderCamAllowDeath and UnitIsDead and ns.Flag(UnitIsDead("player")) then
		return "dead"
	end
	local camera = ns.ActiveEvent and select(2, ns.ActiveEvent())
	if camera then
		local key = CameraKey(camera)
		if not db[ALLOW_OF[key] or ALLOW_OF.yours] then
			return camera
		end
	end
	-- (The walk, auto-run, quest and chat cameras aren't events: the camera
	-- playing now, ns.activeCam ("quest", or "script:quest" as its script).
	-- Always kept till 2026-11-15, nothing asked; the today run's quest step
	-- never paused.)
	local playing = ns.activeCam
	local playingKey = type(playing) == "string" and CameraKey(playing)
	if PLAYING_CAMS[playingKey] and not db[ALLOW_OF[playingKey]] then
		return playing
	end
	if YouAreTarget() then
		return "yourself"
	end
end

-- The offset to write: yards, negative for the left shoulder; "0" paused.
local SPOT_EASE_FROM, SPOT_EASE_TO = 1, 4 -- yards: in the middle at 1, eased out to your spot by 4
local OFFSET_MOST = 15 -- yards (DynamicCam's range too)
-- Near walls the game pulls the camera in, out of our sight (the walls run,
-- 2026-11-12: GetCameraZoom read 15.0 all through, no setting stops it), and
-- an offset sized for the full distance then threw you far to the side,
-- behind a tree or off screen (3.3 yards at 15 away). So the offset stops
-- growing: zoomed far out you sit nearer the middle than your spot, and a
-- pull-in throws you less far (right up close it still can).
-- (Counted in how far it moves you, a Dwarf's yards, so over the model's size
-- factor: capped in plain offset yards, a Night Elf held at 1.50 sat on ~12%
-- while her cat, not capped, sat on her 20% spot: each shift jumped between
-- them (the forms run, 2026-11-14).)
-- Held as a distance since 2026-11-15, not as yards of offset: the spot's
-- kept out to SPOT_HOLD yards away, the offset held past that. 1.5 yards
-- capped every spot alike, so on a wide screen (more yards to the same share)
-- past about 14% at zoom 8 the slider did nothing ("doesn't work past 20%",
-- user). SPOT_HOLD is where 1.5 yards was the cap for 20% on a 16:9 screen,
-- so that's as before; a wall's pull-in throws you the same share past your
-- spot whatever it is.
-- Held over the screen's width since 2026-11-16 (distance x view width, not
-- the distance alone): on an ultrawide (2.39, view width 1.34) the hold at
-- 7.5 yards let the offset grow a third past the old cap, a cat's 0.92 to
-- 1.24 yards at zoom 9, and the camera shook against walls ("a bit shaky
-- with walls now", user). So the cap's 1.5 yards at 20% again on any screen,
-- still growing with the slider; zoomed out on a wide screen you sit nearer
-- the middle than your spot (20% shows as ~15% there).
local SPOT_HOLD = 7.5 -- yards away (on a 16:9 screen: over the view width)
ns.SHOULDER_SPOT_HOLD = SPOT_HOLD
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
-- (Mounts change it too: each has its own key, MountNow below.)
-- (Human-3: the offset sweep, Forever, 2026-11-13. Skyborne-2 and -3, Gnome-2 and -3, NightElf-2, Dwarf-3, Human-2, Orc-2 and -3, Scourge-2 and -3, Tauren-2 and -3, Troll-2 and -3: the calibrate run, spreads 0.025 or less. NightElf-3 again, 2026-11-14: 0.88, not the 0.82 read off a recording.)
local MEASURED_SCALES = { ["Dwarf-2"] = 1, ["Dwarf-3"] = 0.82, ["Skyborne-2"] = 0.88, ["Skyborne-3"] = 0.85, ["Gnome-2"] = 0.90, ["Human-2"] = 0.94, ["Gnome-3"] = 0.84, ["NightElf-2"] = 1.00, ["NightElf-3"] = 0.88, ["Human-3"] = 0.81,
	["Orc-2"] = 1.23, ["Orc-3"] = 0.96, ["Scourge-2"] = 0.99, ["Scourge-3"] = 0.90, ["Tauren-2"] = 1.68, ["Tauren-3"] = 1.27,
	["Troll-2"] = 1.22, ["Troll-3"] = 0.95,
	-- (Druid forms, per race, both sexes alike (ScaleOf): the calibrate run
	-- in each, 2026-11-14, a Night Elf female and then male.)
	["NightElf-form1"] = 1.63, ["NightElf-form5"] = 1.76,
	-- (Form 4: 2.32 in five runs, 2.29 at 8 yards and 2.35 at 12, just over
	-- the spread a run calls good; one run said 2.20, the odd one out.)
	["NightElf-form4"] = 2.32 }
local BORROW_FORMS_FROM = "NightElf" -- (a form not measured for your race: this race's, ScaleOf)
-- bear, cat, dire bear: off the recordings till the sweep's run in them
local FORM_SCALES = { [5] = 1.70, [1] = 1.55, [8] = 1.70 }
-- Forms that keep your own model (warrior stances 17-19, shadowform 28,
-- stealth 30): read as on foot. (A Human warrior's calibrate run came back
-- "Human-2-form17", 2026-11-13.)
local SAME_MODEL = { [17] = true, [18] = true, [19] = true, [28] = true, [30] = true }
local SWAP_WAIT = 0.4 -- seconds: the longest the old form's factor is kept without the model's event
local lastForm -- (the form at the last plain read: kept if a read comes back secret)
local function FormNow()
	if not GetShapeshiftFormID then return nil end
	local ok, form = pcall(function()
		local id = GetShapeshiftFormID()
		if id == nil then return false end
		if id + 0 ~= id then return nil end -- (a secret one errors here: the last one's kept)
		return not SAME_MODEL[id] and id
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
-- (Every form since 2026-11-14: the cat's 15% each way, in and out. The
-- push is a share of the offset's change, so it goes with each form's size
-- on its own; the bear's 35% was tuned before the cap counted how far you're
-- moved, the old jump it made up for gone.)
local SWAP_PUSH, SWAP_PUSH_FOR = 0.15, 0.035
local SWAP_PUSH_OUT = 0.15
-- (Per form, where measured: the shift run, a Night Elf's cat, 2026-11-14,
-- with the cap counted in how far you're moved. In, from where you stood:
-- 35% went 1 point out as the model came, then 1-1.4 in as the push landed;
-- no push 1 out, creeping back; 15% 0.7 out and 0.2-0.3 in, the least. The
-- first frame out is the model come before any offset can follow it.)
local SWAP_PUSH_OF = { [1] = 0.15 }
local shownKnown, shownForm, swapBy, swapLed
local lastYards, boostFrom, boostUntil, boostBy = 0, nil, nil, nil -- (yards at the last frame; a push's start, end and share)
local steadyYards = 0 -- (the offset without a push: the frames that follow you go by it, TargetShift)
local pushOver = 0 -- (till when they do: the push's end and a moment more, till the setting's rewritten)
-- (Out of a form (was: the form left): no push unless one's set for that
-- form, SWAP_PUSH_OUT_OF, or the shift run's boostOut.)
-- (The cat, the shift runs, 2026-11-14, from where you stood: no push 0 and
-- -0.6; 15% +0.1 and -0.4, the least; 35% +0.6 and -0.2; 50% +1.1; 35% for
-- twice as long +1.3.)
local SWAP_PUSH_OUT_OF = { [1] = 0.15 }
local function Swapped(was)
	local knobs = ns.shoulderSwap
	if shownForm == nil then
		local by = knobs and knobs.boostOut or SWAP_PUSH_OUT_OF[was] or (was and SWAP_PUSH_OUT)
		if not by or by <= 0 then return end
		boostBy = by
		boostFrom, boostUntil = lastYards, GetTime() + (knobs and knobs.boostOutFor or SWAP_PUSH_FOR)
		pushOver = boostUntil + 0.1
		return
	end
	boostBy = knobs and knobs.boost or SWAP_PUSH_OF[shownForm] or SWAP_PUSH
	boostFrom, boostUntil = lastYards, GetTime() + (knobs and knobs.boostFor or SWAP_PUSH_FOR)
	pushOver = boostUntil + 0.1
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
			local was = shownForm
			shownForm, swapBy = form, nil
			Swapped(was)
		end
	end
	return shownForm
end
local function ModelSwapped()
	local was, now = shownForm, FormNow()
	shownKnown, shownForm, swapBy = true, now, nil
	if was ~= now then Swapped(was) end
	ns.Log("shoulder", ("model changed: form %s (was %s)"):format(tostring(shownForm), tostring(was)))
end
-- The mount you're on (C_MountJournal's mount ID), or nil. A mount is its own
-- model with its own factor, keyed "mount<ID>" whoever rides it (user,
-- 2026-11-18: players calibrate each mount till there's a table of them).
-- Looked up once per mount-up (the journal's whole list), kept till you get
-- off or the mount's display changes.
local mountKnown, mountNow
local function MountNow()
	if not (IsMounted and ns.Flag(IsMounted())) then
		mountKnown, mountNow = false, nil
		return nil
	end
	if mountKnown then return mountNow end
	mountKnown, mountNow = true, nil
	if not (C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID) then return nil end
	pcall(function()
		for _, id in ipairs(C_MountJournal.GetMountIDs()) do
			local _, _, _, active = C_MountJournal.GetMountInfoByID(id)
			if ns.Flag(active) then
				mountNow = id
				return
			end
		end
	end)
	ns.Log("shoulder", ("mount: %s"):format(tostring(mountNow or "not found in the journal")))
	return mountNow
end
local mountWatch = CreateFrame("Frame")
mountWatch:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mountWatch:SetScript("OnEvent", function() mountKnown = false end)
ns.ShoulderMountNow = MountNow
-- Mounts measured so far, mount ID -> factor (built from players' shared
-- calibrations; none yet).
local MEASURED_MOUNTS = {}

function ns.ShoulderModelKey()
	local _, race = UnitRace("player")
	local foot = ("%s-%s"):format(tostring(race), tostring(UnitSex("player")))
	local mount = MountNow()
	if mount then return ("mount%d"):format(mount), nil, foot, mount end
	local form = ModelForm()
	return form and ("%s-form%d"):format(foot, form) or foot, form, foot
end
-- The size factor for a form (nil: on foot) or a mount, and where it's from.
local function ScaleOf(form, foot, mount)
	local scales = ns.db and ns.db.shoulderCamScales
	if mount then
		local saved = scales and scales[("mount%d"):format(mount)]
		if type(saved) == "number" and saved > 0.2 then return saved, "measured here" end
		if MEASURED_MOUNTS[mount] then return MEASURED_MOUNTS[mount], "built in" end
		-- (Not measured: the rider's on-foot one, as before mounts had keys.)
		local scale, from = ScaleOf(nil, foot)
		return scale, ("%s: mount not measured"):format(from)
	end
	local key = form and ("%s-form%d"):format(foot, form) or foot
	local saved = scales and scales[key]
	if type(saved) == "number" and saved > 0.2 then return saved, "measured here" end
	if MEASURED_SCALES[key] then return MEASURED_SCALES[key], "built in" end
	if form then
		-- (A form's one model for both sexes of a race: a Night Elf male's
		-- cat 1.62 and bear 1.76, the female's 1.63 and 1.76, 2026-11-14. So
		-- the table has it once, race-formN.)
		local race = foot:match("^(.-)%-%d+$") or foot
		local both = MEASURED_SCALES[("%s-form%d"):format(race, form)]
		if both then return both, "built in, this race's" end
		-- (Not measured for this race: the Night Elf's, the one race measured
		-- so far, 2026-11-14. Closer than the race's on-foot size (a Troll in
		-- form 4 went by 0.95 for a form near 2.3) while the others wait for
		-- a druid of theirs.)
		local borrowed = MEASURED_SCALES[("%s-form%d"):format(BORROW_FORMS_FROM, form)]
		if borrowed then return borrowed, ("built in, the %s's: not measured for this race"):format(BORROW_FORMS_FROM) end
		if FORM_SCALES[form] then return FORM_SCALES[form], "estimated for this form" end
		saved = scales and scales[foot]
		if type(saved) == "number" and saved > 0.2 then return saved, "on-foot one: form not measured" end
		if MEASURED_SCALES[foot] then return MEASURED_SCALES[foot], "on-foot one: form not measured" end
	end
	return 1, "not measured"
end
-- Shifting, the model not changed yet: the old model's factor, or with an
-- early share (ns.shoulderSwap.early, the shift run's timings) part of the
-- way to the new one's offset already, the game's own ease given a head
-- start. (The offset goes as 1 / the factor, its cap too: so the share's of
-- the offset, 1/f = (1 - share)/old + share/new.)
-- (None for now. The cat, the shift runs, 2026-11-14, with its 15% push,
-- from where you stood: none early about +0.5 then -0.5 every time; a third
-- or half early +0.3 to +0.4 and -0.2 at most while the game swapped the
-- model 0.03-0.05 s after the form, but -0.9 to -1.4 at 0.06-0.07 s (the elf
-- slid in before the cat showed). That wait varies by session (0.03-0.10 s
-- that day), so a share written up front can't fit it.)
local SWAP_EARLY_OF = {} -- (form -> share, into it)
function ns.ShoulderModelScale()
	local _, form, foot, mount = ns.ShoulderModelKey()
	local scale, from = ScaleOf(form, foot, mount)
	if swapBy and not mount then
		local knobs = ns.shoulderSwap
		local coming = FormNow()
		local share = knobs and knobs.early or SWAP_EARLY_OF[coming]
		-- (Into a form only: out, the game says "no form" ~0.17 s before the
		-- model's back, and a third written then slid you from 12.5% out to
		-- 15.9% of the screen first: the shift run, 2026-11-14.)
		if share and share > 0 and coming then
			local new = ScaleOf(coming, foot)
			return 1 / ((1 - share) / scale + share / new), ("%s, %d%% of the way to the new model's"):format(from, share * 100)
		end
	end
	return scale, from
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

-- Your spot as you zoom (user 2026-11-17: "as you zoom in increase the
-- offset, as you zoom out decrease it", to keep the camera off walls, which
-- only catch it zoomed out). Spot on screen up to SPOT_NEAR yards away,
-- easing to Spot zoomed out (shoulderCamSpotFar) at Zoomed out at
-- (shoulderCamSpotFarAt) and beyond. It's a share of the screen as the near
-- one is, and the cap (SPOT_HOLD) still holds over it, so it only ever takes
-- the offset in: at its default (false: the near spot), nothing changes.
function ns.ShoulderSpotAt(distance)
	local SPOT_NEAR = 5 -- yards away
	local db = ns.db or {}
	local near = db.shoulderCamSpot or 0.2
	local far = db.shoulderCamSpotFar or near
	local farAt = math.max(SPOT_NEAR + 1, tonumber(db.shoulderCamSpotFarAt) or 15)
	local k = math.min(1, math.max(0, (distance - SPOT_NEAR) / (farAt - SPOT_NEAR)))
	return near + (far - near) * k * k * (3 - 2 * k)
end

local function SpotYards()
	local distance = SeenZoom()
	local scale = ns.ShoulderModelScale()
	local view = distance * ns.ShoulderViewWidth()
	local yards = math.min(ns.ShoulderSpotAt(distance) * view, (ns.db.shoulderCamSpot or 0.2) * SPOT_HOLD) / scale
	local k = math.min(1, math.max(0, (distance - SPOT_EASE_FROM) / (SPOT_EASE_TO - SPOT_EASE_FROM)))
	yards = math.min(OFFSET_MOST, yards * k * k * (3 - 2 * k))
	steadyYards = yards
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
-- One of our cameras' pauses: the seconds typed in its box on the Cameras
-- tab instead, out as it starts and back in as it ends (empty: BLEND_TIME).
local BLEND_TIME = 0.9
ns.SHOULDER_BLEND_TIME = BLEND_TIME
local blend, blendAt = 0, nil
local blendTime = BLEND_TIME
-- (Pauses that aren't one of our cameras: PauseReason's own words.)
local NOT_A_CAMERA = { gamepad = true, mounted = true, indoors = true, ["show in"] = true, mounting = true,
	yourself = true, demo = true, waiting = true }
local function TimeKey(key)
	return ALLOW_OF[key] and (ALLOW_OF[key]:gsub("Allow", "Time"))
end
ns.ShoulderTimeKey = TimeKey
local function PauseTime(reason)
	if reason == "yourself" then
		return math.max(0, tonumber(ns.db.shoulderCamSelfTime) or 1)
	end
	local key = reason == "dead" and "death" or reason == "flight" and "flight"
		or not NOT_A_CAMERA[reason] and CameraKey(reason)
	local seconds = key and tonumber(ns.db[TimeKey(key) or ""])
	if seconds and seconds >= 0 then return seconds end
	-- (Indoors, mounted, Show in, the gamepad: the slider's time, shoulderCamPauseTime.)
	if NOT_A_CAMERA[reason] then
		return math.max(0, tonumber(ns.db.shoulderCamPauseTime) or BLEND_TIME)
	end
	return BLEND_TIME
end
local function Blend(toward)
	local now = GetTime()
	local step = blendAt and math.min(0.25, now - blendAt) / math.max(0.01, blendTime) or 0
	-- (Resting all the way out, it's not asked every frame: no clock kept, so
	-- the way back in starts from its first frame, not with a jump.)
	blendAt = not (blend <= 0 and toward <= 0) and now or nil
	blend = toward > blend and math.min(toward, blend + step) or math.max(toward, blend - step)
	return blend * blend * (3 - 2 * blend)
end

-- (How far in the offset is, 0 to 1: the sim skips the ease's samples.)
function ns.ShoulderBlendShare() return blend end

-- Swapping shoulders: the side as -1 (left) to 1 (right), crossing over
-- shoulderCamSwapTime seconds, eased at both ends. At 0 it's the new side at
-- once, and the game's own ease takes it across (about 0.3 s). Started
-- fresh, or after a while not asked (paused all the way out), it's the side
-- at once.
local sideNow, sideAt
local function SideFactor()
	local want = ((demo and demo.side) or ns.db.shoulderCamSide) == "left" and -1 or 1
	local now = GetTime()
	local time = tonumber(ns.db.shoulderCamSwapTime) or 1.5
	if not sideNow or time <= 0 or not sideAt or now - sideAt > 0.5 then
		sideNow = want
	else
		local step = (now - sideAt) * 2 / time
		sideNow = want > sideNow and math.min(want, sideNow + step) or math.max(want, sideNow - step)
	end
	sideAt = now
	local p = (sideNow + 1) / 2
	return 2 * p * p * (3 - 2 * p) - 1
end

-- You're moving the camera: a mouse button held on it, or camera input under
-- YOURS_QUIET ago (Core.lua's PLAYER_HOLD).
-- (Your camera always wins: the way back in after the quest cam slid the view
-- sideways under a drag, "my mouse and the addon moving the camera were
-- competing", user 2026-11-15. So it waits where it got to till you let go.)
local YOURS_QUIET = 0.5
local heldForYou -- (the way back in waiting for you, for the log)
local function YouMoveCamera()
	if ns.IsMouseOnCamera and ns.IsMouseOnCamera() then return true end
	local last = ns.GetLastCameraInput and ns.GetLastCameraInput() or -math.huge
	return GetTime() - last < YOURS_QUIET
end

local function ShoulderValue(again)
	if not again then paused = PauseReason() end
	-- (A pause's time is kept as it ends, for the way back in.)
	if paused then
		blendTime = PauseTime(paused)
	elseif blend >= 1 then
		blendTime = BLEND_TIME
	end
	local toward = paused and 0 or 1
	-- (Only the way back in waits: easing out for a pause goes on.)
	local wait = toward > blend and YouMoveCamera()
	if wait ~= (heldForYou or false) then
		heldForYou = wait or nil
		ns.Log("shoulder", wait and ("coming back in waits: you're moving the camera (%d%% in)"):format(blend * 100)
			or (paused and "coming back in stopped: paused again (%d%% in)"
				or "you've let go of the camera: coming back in from %d%%"):format(blend * 100))
	end
	if wait then toward = blend end
	local k = Blend(toward)
	if k <= 0 then
		return "0"
	end
	return ("%.2f"):format(SpotYards() * k * SideFactor())
end

-- Glides (the offset, and quiet ones: the talk and target turns' strengths)
-- are logged as one line once they settle, from where to where over how long,
-- not a line a frame (user, 2026-11-16: they filled 5,000-line logs). Settled
-- = no step for GLIDE_QUIET seconds; any other Shoulder Cam CVar line, and
-- the log being saved, write the open ones first so the order stays right.
local GLIDE_QUIET = 0.3
local glides, glideTicker = {}, nil
local function FlushGlides(all)
	local now, open = GetTime(), false
	for cvar, g in pairs(glides) do
		if all or now - g.last >= GLIDE_QUIET then
			glides[cvar] = nil
			ns.Log("cvar", ("Shoulder Cam: %s %s -> %s over %.2f s (%d steps)"):format(
				cvar, g.from, g.to, g.last - g.start, g.steps))
		else
			open = true
		end
	end
	if not open and glideTicker then
		glideTicker:Cancel()
		glideTicker = nil
	end
end
local function GlideStep(cvar, from, to)
	local now = GetTime()
	local g = glides[cvar]
	if not g then
		g = { from = from, start = now, steps = 0 }
		glides[cvar] = g
	end
	g.to, g.last, g.steps = to, now, g.steps + 1
	if not glideTicker then
		glideTicker = C_Timer.NewTicker(0.1, function() FlushGlides() end)
	end
end
do -- (a glide still going as you log out or /reload)
	local saver = CreateFrame("Frame")
	saver:RegisterEvent("PLAYER_LOGOUT")
	saver:SetScript("OnEvent", function() FlushGlides(true) end)
end

local function Write(yours, cvar, value, quiet)
	local now = GetCVar(cvar)
	if now ~= nil and not Same(now, value) then
		if yours[cvar] == nil then
			yours[cvar] = now
		end
		if quiet or cvar == "test_cameraOverShoulder" then
			GlideStep(cvar, now, value)
		else
			FlushGlides(true)
			ns.Log("cvar", ("Shoulder Cam: %s %s -> %s"):format(cvar, now, value))
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
-- The question answered yes without it: the welcome window's Shoulder Cam
-- card and its See it first test say why on themselves (Welcome.lua).
function ns.ShoulderCamAgree()
	if ns.db then ns.db.shoulderCamNoticed = true end
	if asking then
		if _G.StaticPopup_Hide then _G.StaticPopup_Hide("CINEMATIC_SHOULDER_NOTICE") end
		asking = nil
		-- (Held back for the question: on now.)
		ns.ApplyShoulderCam()
	end
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
-- shoulderCamTalkIn seconds, eased (back down: shoulderCamTalkOut). While one of Cinematic's cameras holds
-- the view (the quest or chat camera) they're held where they are, and glide
-- back as the window closes (stepped down under it till 2026-11-16, so the
-- close had nothing left to turn back: user). The way back as the window closes is
-- the game's 0.2 s, a snap: closed, the focus has no one to turn to, and
-- nothing turns the camera beforehand (the "back" run, 2026-11-12: camera
-- follow didn't move it), so the close is held while they glide back down
-- (ns.ShoulderTalkClose). (A time on them before gliding back with the window
-- still open, shoulderCamTalkHold, removed 2026-11-16: user.) A new
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
	-- A held close waits this long before the glide back starts: going from
	-- one window to the next (a quest greeting to its text, Accept to the next
	-- quest), the panel's close comes first and the next window ~0.1-0.3 s
	-- after. Gliding back at once turned out and in again each time (user,
	-- 2026-11-14: "when you accept 2 quests it snaps out and in").
	swapWait = 0.4, backAt = nil, -- (when a held close's glide back starts)
	-- Accept and Complete end the talk on the game's side (QUEST_FINISHED),
	-- and the game's focus snaps back then, the next quest's window snapping
	-- it in again 0.25 s on (the log and the user, 2026-11-14). A drift back
	-- while you read (8 s) didn't help: Accept came 0.45-0.8 s in, the turn
	-- still 0.8-0.9 there. So those calls are held too (ns.ShoulderTalkClose with
	-- quick: the glide back at once, no swapWait), then they go. Over
	-- NPC turn back takes, as every close (user, 2026-11-16: "when i close the
	-- window i expect it to turn back over 3 seconds"); quickTime (0.5 s)
	-- till then. quickTime's only for walking off now.
	quickTime = 0.5, quick = false, -- (quick: a held Accept, Complete or Decline)
}

-- Seconds the turn toward them takes (shoulderCamTalkIn), and the glide back
-- (shoulderCamTalkOut), each its own slider since 2026-11-14.
local function TalkInTime() return math.max(0.1, ns.db.shoulderCamTalkIn or 3) end
local function TalkOutTime() return math.max(0.1, ns.db.shoulderCamTalkOut or 3) end

-- Turn to NPCs' Show in row (user, 2026-11-16: "turning inside can be a bit
-- much"): where it turns, not indoors or in fights to start with. Read 4 times a second,
-- as Turn to enemy's (rules aren't cheap). Its Always: shoulderCamTalkTurnAlways.
ns.SHOULDER_TALK_ROW = "shoulder:talkturn"
ns.CINE_SHOW_SETTING[ns.SHOULDER_TALK_ROW] = "shoulderCamTalkTurnAlways"
ns.RULE_DEFAULTS[ns.SHOULDER_TALK_ROW] = "not indoors and not combat"
for _, list in ipairs({ "combatShow", "worldShow", "cityShow", "bgShow", "instanceShow", "groupShow" }) do
	ns.LIST_DEFAULTS[list][ns.SHOULDER_TALK_ROW] = true
end
local talkRead = { at = -1, on = true }
local function TalkHere()
	local now = GetTime()
	if now - talkRead.at >= 0.25 then
		talkRead.at = now
		local ok, on = pcall(ns.RowOnNow, ns.SHOULDER_TALK_ROW, ns.db.shoulderCamTalkTurnAlways, true)
		talkRead.on = not ok or on and true or false
	end
	return talkRead.on
end

local function TalkOn()
	return ShoulderOn() and ns.db.shoulderCamTalkTurn and paused ~= "show in" and TalkHere()
end
-- (MultiQuestFix.lua: its cover over the game's Accept only while this is on.)
function ns.ShoulderTalkOn() return TalkOn() and true or false end

-- Who the window's with, only a living creature: a mailbox, a wanted poster,
-- a chest (their GUIDs say GameObject, or there's no "npc" at all) and the
-- dead are left alone. (Read as plain values where it can be: anything secret
-- or unreadable counts as a creature, as before.)
local function TalkingToLiving()
	local okExists, exists = pcall(UnitExists, "npc")
	if okExists and not exists and not (issecretvalue and issecretvalue(exists)) then return false, "no one" end
	local okGuid, guid = pcall(function()
		local g = UnitGUID("npc")
		return type(g) == "string" and g:match("^(%a+)") or nil
	end)
	if okGuid and guid and guid ~= "Creature" and guid ~= "Vehicle" and guid ~= "Pet" then
		return false, guid
	end
	local okDead, dead = pcall(UnitIsDeadOrGhost, "npc")
	if okDead and ns.Flag(dead) then return false, "dead" end
	return true
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
				FlushGlides(true)
				ns.Log("cvar", ("Shoulder Cam: %s back to %s"):format(cvar, yours[cvar]))
				SetCVar(cvar, yours[cvar])
			end
			yours[cvar] = nil
		end
	end
end

-- Closing slowly. Closing the panel before the glide back's done still
-- snapped the rest (user, 2026-11-12: "it glides back in .5 seconds"; the
-- game's 0.2 s). So the call that ends the conversation is held back: the
-- conversation stays open while the turn glides back at its own pace, then
-- the held call goes. Walking off ends it on the game's side: that still
-- snaps. A new window meanwhile (another NPC, the vendor after the gossip)
-- drops the held calls (the game's moved on to it; ending it would close the
-- new one). Never in a fight; a timer ends it if the glide can't finish.
-- Each is logged ("shoulder").
-- Only through Cinematic's own quest bubble (QuestTalk.lua calls
-- ns.ShoulderTalkClose for its Goodbye, Accept and Complete). Till
-- 2026-11-14 the game's own CloseGossip, CloseQuest, AcceptQuest and
-- GetQuestReward were replaced to hold them from the game's windows too,
-- which taints every bit of the game's code that calls them (the user
-- chose this over it). The game's windows close at once and snap back.
-- Every NPC window since 2026-11-16 (user: no snap anywhere): held open
-- unseen it'd still take a click (an item sold or banked, a spell bought),
-- so gameEsc.Guard covers it and keeps your bags closed till it goes.
local closing = {
	held = {}, since = nil,
	-- (Which hold a safety timer's for: an old one, its calls dropped as the
	-- next window opened, ended a later hold 0.36 s in, a snap (the log,
	-- 2026-11-14).)
	token = 0,
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

-- (A talk's end held now, for the camera's glide back: QuestTalk.lua fades
-- its bubble out at once then.)
function ns.ShoulderTalkHeld() return #closing.held > 0 end

-- The quest bubble's end of a talk (QuestTalk.lua): fn(...) now, or held
-- while the turn glides back. label: what it is, for the log; quick: Accept
-- or Complete, the quick glide back.
function ns.ShoulderTalkClose(label, fn, quick, ...)
	if type(fn) ~= "function" then return end
	if closing.passing or ns.shoulderTestHold or not (TalkOn() and talk.on and talk.share > 0.02)
		or InCombatLockdown() then
		return fn(...)
	end
	local held = closing.held
	-- (Accept clicked twice while held: once is enough.)
	for _, call in ipairs(held) do
		if call.label == label then return end
	end
	held[#held + 1] = { fn = fn, args = { ... }, n = select("#", ...), label = label }
	-- (Accept or Complete: the quick glide back, at once.)
	if quick then talk.quick, talk.back, talk.backAt = true, true, nil end
	if #held == 1 then
		closing.since = GetTime()
		if not quick then talk.backAt = GetTime() + talk.swapWait end
		closing.token = closing.token + 1
		local token = closing.token
		ns.Log("shoulder", ("talk close: %s held while the camera glides back (turn at %.2f)"):format(
			label, talk.share))
		local wait = (quick and 0 or talk.swapWait) + TalkOutTime() + 1
		C_Timer.After(wait, function()
			if closing.token == token then CloseNow("timer") end
		end)
	else
		ns.Log("shoulder", ("talk close: %s held too"):format(label))
	end
end

-- Escape in the game's own NPC windows (2026-11-15, no Quest Vision
-- needed): bound to a secure button while one's open and the talk turn is
-- on. Its /cleartarget clears your target (shoulderCamEscTarget; the game's
-- Escape would close the window first), and its PostClick closes the window
-- through the slow glide back (ns.ShoulderTalkClose), fading it out
-- meanwhile. The game's close is only called, never replaced (what tainted,
-- till 2026-11-14). With Cinematic's own dialogue up, Escape's left to it.
-- Every NPC window since 2026-11-16 (user: no snap anywhere), gossip and
-- quest text before (then a vendor too). A held window is kept from clicks
-- (gameEsc.Guard: a cover over it, your bags closed and kept closed), so
-- nothing's bought, sold, banked, sent or flown to while it fades. The
-- game's X, Goodbye, Decline and Complete Quest buttons have covers of ours over them
-- (gameEsc.Covers) that do the same, as MultiQuestFix.lua's over Accept.
-- The frame's name, the game's close call (for the log, and the call).
local GAME_TALK = {
	{ "GossipFrame", "CloseGossip", function() (C_GossipInfo and C_GossipInfo.CloseGossip or _G.CloseGossip)() end },
	{ "QuestFrame", "CloseQuest", function() CloseQuest() end },
	{ "MerchantFrame", "CloseMerchant", function() CloseMerchant() end },
	{ "ClassTrainerFrame", "CloseTrainer", function() CloseTrainer() end },
	{ "BankFrame", "CloseBankFrame", function() CloseBankFrame() end },
	{ "GuildBankFrame", "CloseGuildBankFrame", function() CloseGuildBankFrame() end },
	{ "TaxiFrame", "CloseTaxiMap", function() CloseTaxiMap() end },
	{ "FlightMapFrame", "CloseTaxiMap", function() CloseTaxiMap() end },
	{ "MailFrame", "CloseMail", function() CloseMail() end },
	{ "AuctionHouseFrame", "CloseAuctionHouse", function() C_AuctionHouse.CloseAuctionHouse() end },
	{ "AuctionFrame", "CloseAuctionHouse", function() CloseAuctionHouse() end },
	{ "PetStableFrame", "ClosePetStables", function() ClosePetStables() end },
	{ "StableFrame", "ClosePetStables", function() ClosePetStables() end },
}
local gameEsc = CreateFrame("Button", "CinematicShoulderEscapeButton", UIParent, "SecureActionButtonTemplate")
gameEsc:SetAttribute("type", "macro")
gameEsc:SetAttribute("macrotext", "")
gameEsc:RegisterEvent("PLAYER_LOGIN")
gameEsc:RegisterEvent("PLAYER_REGEN_ENABLED")
-- (Right-clicking them again while the close is held: the talk goes on,
-- ns.ShoulderTalkKeep. The window's still open, faded out, so the game
-- opens nothing new, and the close came after: user, 2026-11-15.)
pcall(gameEsc.RegisterEvent, gameEsc, "GLOBAL_MOUSE_UP")
gameEsc:SetScript("OnEvent", function(self, event, button)
	if event == "PLAYER_LOGIN" then
		-- (On key down or up as the game's action buttons are, not both: it'd go twice.)
		self:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- (Out of a fight: a binding the fight kept, with the poller stopped
		-- (the Shoulder Cam turned off in it), given back now.)
		if self.Sync then self.Sync() end
	elseif button == "RightButton" and #closing.held > 0 then
		local ok, again = pcall(function()
			return UnitExists("mouseover") and UnitIsUnit("mouseover", "npc")
		end)
		if ok and ns.Flag(again) and ns.ShoulderTalkKeep then ns.ShoulderTalkKeep("right-clicked them again") end
	end
end)
gameEsc.bound = false
-- The open NPC window: its frame, name, close call's label and the call.
local function GameTalkWindow()
	for _, entry in ipairs(GAME_TALK) do
		local frame = _G[entry[1]]
		if frame and ns.Flag(frame:IsShown()) then return frame, entry[1], entry[2], entry[3] end
	end
end
-- Your bags closed while a close is held, and closed again if one opens
-- before it goes (a bag key). (Post-hooks only: nothing of the game's replaced.)
function gameEsc.HoldBags()
	gameEsc.bagsHeld = true
	if CloseAllBags then pcall(CloseAllBags) end
	if gameEsc.bagHooks then return end
	gameEsc.bagHooks = true
	local function Shut()
		if not gameEsc.bagsHeld then return end
		if #closing.held == 0 then
			gameEsc.bagsHeld = nil
			return
		end
		ns.Log("shoulder", "talk close: a bag opened while the close is held, closed again")
		if CloseAllBags then pcall(CloseAllBags) end
	end
	for _, name in ipairs({ "OpenAllBags", "ToggleAllBags", "OpenBag", "ToggleBag", "ToggleBackpack", "OpenBackpack" }) do
		if type(_G[name]) == "function" then hooksecurefunc(name, Shut) end
	end
end
-- A cover over the held (faded) window that takes its clicks, gone once
-- nothing's held. (Ours, over it: nothing of the game's window is changed.)
local guard = CreateFrame("Frame", "CinematicShoulderTalkGuard", UIParent)
guard:EnableMouse(true)
pcall(guard.EnableMouseWheel, guard, true)
guard:SetFrameStrata("FULLSCREEN")
guard:Hide()
guard:SetScript("OnUpdate", function(self)
	if #closing.held == 0 or not (self.window and self.window:IsVisible()) then
		self:Hide()
		self.window = nil
	end
end)
function gameEsc.Guard(frame)
	guard:ClearAllPoints()
	guard:SetAllPoints(frame)
	guard.window = frame
	guard:Show()
	gameEsc.HoldBags()
end
-- The window faded out over gameEsc.fadeTime while the camera glides back;
-- its alpha back as it hides. (Our own steps: the game's UIFrameFade on its
-- frames can spread taint.)
gameEsc.fadeTime = 0.2
local function FadeGameWindow(frame)
	if not frame.cinematicEscHooked then
		frame.cinematicEscHooked = true
		frame:HookScript("OnHide", function(self)
			gameEsc.fading = nil
			self:SetAlpha(1)
		end)
	end
	gameEsc.fading = frame
	ns.SetOnUpdate(gameEsc, function(_, elapsed)
		local fading = gameEsc.fading
		if not fading then
			ns.SetOnUpdate(gameEsc, nil)
			return
		end
		local alpha = math.max(0, (fading:GetAlpha() or 1) - elapsed / gameEsc.fadeTime)
		fading:SetAlpha(alpha)
		if alpha <= 0 then ns.SetOnUpdate(gameEsc, nil) end
	end)
end
-- A close through the glide back: held (ns.ShoulderTalkClose), the window
-- faded and kept from clicks; or at once if nothing holds it (no turn, a fight).
function gameEsc.HeldClose(frame, label, close, quick)
	ns.ShoulderTalkClose(label, close, quick)
	if #closing.held > 0 then
		FadeGameWindow(frame)
		gameEsc.Guard(frame)
	end
end
-- (A popup up over it, "Sell this?" and the like: Escape's the game's, for the popup.)
function gameEsc.PopupUp()
	for i = 1, 4 do
		local popup = _G["StaticPopup" .. i]
		if popup and ns.Flag(popup:IsShown()) then return true end
	end
	return false
end
-- (MultiQuestFix.lua: the game's Accept held for the glide back, its window
-- faded and guarded the same way.)
ns.ShoulderFadeGameWindow = function(frame)
	FadeGameWindow(frame)
	if #closing.held > 0 then gameEsc.Guard(frame) end
end
gameEsc:SetScript("PostClick", function()
	local frame, name, label, close = GameTalkWindow()
	if not frame then return end
	ns.Log("shoulder", ("escape: the game's %s, closing after the glide back"):format(name))
	gameEsc.HeldClose(frame, label, close)
end)

-- Covers over the game's own close buttons (X, Goodbye, Decline): plain
-- buttons of ours on top that close through the glide back. The game's button
-- under it is lit and pressed as ours is, so it looks the same. Each found by
-- its name on either client; the ones found are logged as the window opens.
-- { path from _G (dots for keys), the call's label, the call, quick } (no
-- call: the window's own close).
local COVER_BUTTONS = {
	all = { ".CloseButton", "CloseButton", ".BorderFrame.CloseButton" },
	GossipFrame = { { "GossipFrame.GreetingPanel.GoodbyeButton" }, { "GossipFrameGreetingGoodbyeButton" } },
	QuestFrame = { { "QuestFrameGoodbyeButton" }, { "QuestFrameGreetingGoodbyeButton" }, { "QuestFrameCancelButton" },
		-- (Decline: its glide back at once, as Accept's.)
		{ "QuestFrameDeclineButton", "DeclineQuest", function() DeclineQuest() end, true },
		-- (Complete Quest: the reward taken through the glide back, as the
		-- quest bubble's Complete is; it snapped till 2026-11-16, user. Only
		-- when the game's own click would take it straight away: a reward
		-- still to pick, or gold the quest costs (the game asks first), leaves
		-- the game's button uncovered.)
		{ "QuestFrameCompleteQuestButton", "GetQuestReward", function()
			GetQuestReward(gameEsc.RewardChoice())
		end, true, function() return gameEsc.RewardReady() end } },
	ClassTrainerFrame = { { "ClassTrainerCancelButton" } },
	TaxiFrame = { { "TaxiCloseButton" } },
	MailFrame = { { "InboxCloseButton" } },
}
local function Resolve(path)
	local node = _G
	for key in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then return nil end
		node = node[key]
	end
	if type(node) ~= "table" or not node.IsObjectType then return nil end
	local ok, button = pcall(node.IsObjectType, node, "Button")
	return ok and button and node or nil
end
gameEsc.covers = {} -- [the game's button] = our cover
gameEsc.coveredFor = nil -- (the window and buttons covers were laid for, logged once)
local function Cover(target, frame, label, close, quick)
	local cover = gameEsc.covers[target]
	if not cover then
		cover = CreateFrame("Button", nil, UIParent)
		cover:RegisterForClicks("LeftButtonUp")
		cover:SetScript("OnEnter", function(self) pcall(self.target.LockHighlight, self.target) end)
		cover:SetScript("OnLeave", function(self)
			pcall(self.target.UnlockHighlight, self.target)
			pcall(self.target.SetButtonState, self.target, "NORMAL")
		end)
		cover:SetScript("OnMouseDown", function(self) pcall(self.target.SetButtonState, self.target, "PUSHED") end)
		cover:SetScript("OnMouseUp", function(self) pcall(self.target.SetButtonState, self.target, "NORMAL") end)
		cover:SetScript("OnClick", function(self)
			pcall(self.target.UnlockHighlight, self.target)
			ns.Log("shoulder", ("talk close: the game's %s, closing after the glide back"):format(self.which))
			gameEsc.HeldClose(self.frame, self.label, self.close, self.quick)
		end)
		-- (Gone with the button: never left over a closed window, taking clicks.)
		cover:SetScript("OnUpdate", function(self)
			if not self.target:IsVisible() then self:Hide() end
		end)
		cover.target = target
		gameEsc.covers[target] = cover
	end
	-- (Already over it for this window: nothing to do, every frame.)
	if cover:IsShown() and cover.frame == frame and cover.label == (label or cover.label) then return end
	cover.frame, cover.label, cover.close, cover.quick = frame, label, close, quick
	cover.which = target:GetName() or label
	cover:ClearAllPoints()
	cover:SetAllPoints(target)
	cover:SetFrameStrata(target:GetFrameStrata() or "HIGH")
	cover:SetFrameLevel((target:GetFrameLevel() or 1) + 20)
	cover:Show()
end
-- The reward the game's Complete would take: the one picked, or the only one.
function gameEsc.RewardChoice()
	local choice = _G.QuestInfoFrame and tonumber(_G.QuestInfoFrame.itemChoice) or 0
	if choice > 0 then return choice end
	local ok, choices = pcall(GetNumQuestChoices)
	return (ok and choices == 1) and 1 or 0
end
function gameEsc.RewardReady()
	local ok, ready = pcall(function()
		local choices = GetNumQuestChoices() or 0
		if choices > 0 and gameEsc.RewardChoice() == 0 then return false end
		local money = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
		return not (type(money) == "number" and money > 0)
	end)
	return ok and ready == true
end
function gameEsc.Covers(frame, name, label, close)
	local seen, laid = {}, {}
	local function Try(path, coverLabel, coverClose, quick, when)
		local target = Resolve(path)
		-- (Not now: the game's own button takes the click, our cover off it.)
		if target and when and not when() then
			local cover = gameEsc.covers[target]
			if cover and cover:IsShown() then cover:Hide() end
			return
		end
		if target and not seen[target] and ns.Flag(target:IsVisible()) then
			seen[target] = true
			Cover(target, frame, coverLabel or label, coverClose or close, quick)
			laid[#laid + 1] = path
		end
	end
	for _, suffix in ipairs(COVER_BUTTONS.all) do Try(name .. suffix) end
	for _, entry in ipairs(COVER_BUTTONS[name] or {}) do Try(entry[1], entry[2], entry[3], entry[4], entry[5]) end
	local key = name .. ":" .. table.concat(laid, ",")
	if gameEsc.coveredFor ~= key then
		gameEsc.coveredFor = key
		ns.Log("shoulder", ("covers over the game's %s buttons: %s"):format(name,
			#laid > 0 and table.concat(laid, ", ") or "none found"))
	end
end
function gameEsc.Uncover()
	for _, cover in pairs(gameEsc.covers) do cover:Hide() end
	gameEsc.coveredFor = nil
end

-- The held close called off: the window (faded out) back, the turn back
-- toward them, and the talk goes on as if Escape hadn't been pressed.
function ns.ShoulderTalkKeep(why)
	if #closing.held == 0 then return end
	closing.held = {}
	closing.token = closing.token + 1 -- (its safety timer ends nothing now)
	talk.back, talk.quick, talk.backAt, talk.fullAt = false, false, nil, nil
	local frame = gameEsc.fading
	if frame then
		gameEsc.fading = nil
		frame:SetAlpha(1)
	end
	if ns.QuestTalkKeep then ns.QuestTalkKeep() end
	ns.Log("shoulder", ("talk close: called off (%s), the talk goes on"):format(why))
end

-- (Every frame from the poller, and as the Shoulder Cam's applied: out of fights only.)
local function SyncGameEscape()
	if InCombatLockdown() then return end
	-- want: "talk" (an NPC window: the glide back), or false.
	local want, window, name, label, close = false, nil, nil, nil, nil
	if ShoulderOn() and TalkOn() and talk.on and not (ns.QuestTalkActive and ns.QuestTalkActive()) then
		window, name, label, close = GameTalkWindow()
		if window ~= nil then want = "talk" end
	end
	-- (The game's buttons covered while it's open; a button that shows later,
	-- the next quest panel's Goodbye, covered as it does. Not while held.)
	if want and #closing.held == 0 then
		gameEsc.Covers(window, name, label, close)
	elseif not want and gameEsc.coveredFor then
		gameEsc.Uncover()
	end
	-- (A popup up, "Sell this?" and the like: Escape's the game's, for it.)
	if want and gameEsc.PopupUp() then want = false end
	if want == gameEsc.bound then return end
	gameEsc.bound = want
	if want then
		gameEsc:SetAttribute("macrotext", ns.Setting("shoulderCamEscTarget") and "/cleartarget" or "")
		SetOverrideBindingClick(gameEsc, true, "ESCAPE", gameEsc:GetName())
	else
		ClearOverrideBindings(gameEsc)
	end
	ns.Log("shoulder", want and ("escape: bound for the game's %s"):format(tostring(name))
		or "escape: back to the game's")
end
gameEsc.Sync = SyncGameEscape -- (its PLAYER_REGEN_ENABLED, above)

-- Keep the shoulder when selecting yourself (shoulderCamFakeSelf, off to
-- start with; both clients). With yourself targeted the
-- game centers you and doesn't use the offset at all (selftarget and
-- selfdodge runs, 13 settings tried, none help). So while the Shoulder Cam
-- plays, selecting yourself clears your target instead: your Target Self keys
-- and a left-click on your player frame go to a secure /cleartarget button.
-- With nothing targeted, heals and buffs land on you (auto self-cast: the
-- fakeself run, Thorns, 2026-11-20). The button sits over your player frame,
-- pinned to the screen (hung on it, it'd lock it in fights: protected anchor),
-- opens your menu itself on a right-click, and counts as your frame for a
-- hover (ns.hoverStandIn, Frames.lua). (It let the right-click through to your
-- frame till 2026-11-20: your frame is toplevel, so that click brought it in
-- front of the button, and every left-click after went to it and selected
-- you: "right click the panel and then left click the frame it doesn't work",
-- user. No click reaches your frame now.) Keys and the button
-- change out of fights only: what's set as one starts holds till it ends.
-- Not with Clique (it owns clicks on unit frames): the keys only then.
-- In front of your frame: any click on your frame (toplevel) brings it in
-- front of every frame of its strata, whatever their levels, till a /reload:
-- one with the option off (to select yourself, its menu) left it in front of
-- our button once ticked, and every click selected you ("works only after a
-- reload", user 2026-11-20: mouse on PlayerFrame, our button over it at level
-- 51 to its 1). So ours is toplevel too, brought in front as it's placed, and
-- again whenever the mouse finds your frame through it (FrameInFront).
do
	local fake = CreateFrame("Button", "CinematicShoulderSelfButton", UIParent, "SecureActionButtonTemplate")
	fake:SetAttribute("*type1", "macro")
	fake:SetAttribute("*macrotext1", "/cleartarget")
	fake:SetAttribute("unit", "player")
	fake:SetAttribute("*type2", "togglemenu") -- (your menu, as your frame's right-click)
	fake:Hide()
	-- (ns.shoulderSelfHoldFront: /cine debug shoulder selffront holds this
	-- off, to show your frame in front first.)
	local function Front()
		if ns.shoulderSelfHoldFront then return false end
		if not fake:IsToplevel() then fake:SetToplevel(true) end
		fake:Raise()
		return true
	end
	-- Whether the mouse is on your frame (or a part of it) and not on ours:
	-- yours in front of ours.
	local function FrameInFront()
		local focus = ns.MouseFocus and ns.MouseFocus()
		local frame = _G.PlayerFrame
		if not (focus and frame) or focus == fake then return false end
		for _ = 1, 6 do
			if focus == frame then return true end
			focus = focus.GetParent and focus:GetParent()
			if not focus then return false end
		end
		return false
	end
	local passThrough = false -- (ns.ShoulderFakeSelfState: none since 2026-11-20, above)
	local state = { want = false, rect = "", keys = "", why = "off" }
	local ownChangeAt = -math.huge
	local IsLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
	local function Wanted()
		local db = ns.db
		if not (db and db.shoulderCamFakeSelf) then return false, "off" end
		if not ShoulderOn() then return false, "Shoulder Cam off" end
		-- ("yourself" can't be ours, but a party frame click still gets there.)
		if paused and paused ~= "yourself" then return false, "paused: " .. tostring(paused) end
		if GetCVar("autoSelfCast") == "0" then return false, "auto self-cast off" end
		return true, "on"
	end
	-- Your player frame's fade entry (Frames.lua's ns.managed), found once.
	local entry
	local function FadeEntry(frame)
		if entry and entry.frame == frame then return entry end
		entry = nil
		for _, each in ipairs(ns.managed or {}) do
			if each.frame == frame then entry = each break end
		end
		return entry
	end
	-- Where your player frame is, as a key ("" for none to cover). Faded in
	-- CineMode it's shrunk and parked off the screen, its spot saved for the
	-- hover (Frames.lua): the button stays on that spot, so it's there as the
	-- frame comes back. Following the frame, it was off the screen till its
	-- next check, and a quick click went to the game's frame: "works
	-- sometimes", user 2026-11-20 (CineMode, mouse on PlayerFrame).
	local function FrameRect()
		local frame = _G.PlayerFrame
		if not (frame and ns.Flag(frame:IsVisible()) and frame:GetLeft()) then return "" end
		if IsLoaded and ns.Flag(IsLoaded("Clique")) then return "" end
		local parked = FadeEntry(frame)
		if parked and (parked.shrunk or parked.parkedFullSize) and parked.savedRect and parked.savedRect[1]
			and parked.savedEffectiveScale then
			local left, bottom, width, height = unpack(parked.savedRect)
			local scale = parked.savedEffectiveScale / UIParent:GetEffectiveScale()
			return ("%.1f %.1f %.1f %.1f %s %d parked"):format(left * scale, bottom * scale, width * scale, height * scale,
				frame:GetFrameStrata(), frame:GetFrameLevel())
		end
		local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		return ("%.1f %.1f %.1f %.1f %s %d"):format(frame:GetLeft() * scale, frame:GetBottom() * scale,
			frame:GetWidth() * scale, frame:GetHeight() * scale, frame:GetFrameStrata(), frame:GetFrameLevel())
	end
	local function Place(rect)
		if rect == "" then
			fake:Hide()
			ns.hoverStandIn[fake] = nil
			return
		end
		local frame = _G.PlayerFrame
		local left, bottom, width, height = rect:match("^(%S+) (%S+) (%S+) (%S+)")
		fake:ClearAllPoints()
		fake:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", tonumber(left), tonumber(bottom))
		fake:SetSize(tonumber(width), tonumber(height))
		fake:SetFrameStrata(frame:GetFrameStrata())
		fake:SetFrameLevel(frame:GetFrameLevel() + 50)
		fake:SetToplevel(not ns.shoulderSelfHoldFront)
		fake:Show()
		Front()
		ns.hoverStandIn[fake] = frame
	end
	local function Sync()
		if InCombatLockdown() then return end
		local want, why = Wanted()
		if want ~= state.want or state.dirty then
			ownChangeAt = GetTime()
			ClearOverrideBindings(fake)
			local keys = {}
			if want then
				for _, key in ipairs({ GetBindingKey("TARGETSELF") }) do
					if type(key) == "string" then
						SetOverrideBindingClick(fake, true, key, fake:GetName())
						keys[#keys + 1] = key
					end
				end
			end
			state.dirty = nil
			state.keys = table.concat(keys, ", ")
		end
		local rect = want and FrameRect() or ""
		if rect ~= state.rect then
			Place(rect)
			if want and (rect == "") ~= (state.rect == "") then
				ns.Log("shoulder", "selecting yourself: player frame " .. (rect ~= "" and "covered" or "not covered"))
			elseif want and rect ~= "" then
				ns.Log("shoulder", "selecting yourself: button placed again: " .. rect)
			end
			state.rect = rect
		end
		-- (Your frame came in front of ours anyway: ours in front again.)
		if rect ~= "" and fake:IsShown() and FrameInFront() and Front() then
			ns.Log("shoulder", "selecting yourself: your player frame was in front of our button: ours brought in front")
		end
		if want ~= state.want or why ~= state.why then
			ns.Log("shoulder", ("selecting yourself: %s (%s)%s"):format(want and "clears your target" or "the game's",
				why, want and (", keys %s, player frame %s"):format(state.keys ~= "" and state.keys or "none",
					rect ~= "" and "covered" or "not covered") or ""))
			state.want, state.why = want, why
		end
	end
	-- (Targeted anyway with it on: how, for /cine log. "Not working", user
	-- 2026-11-20: targeted with the frame covered and the key ours.)
	local function Rect(frame)
		if not (frame and frame:GetLeft()) then return "none" end
		local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		return ("%.0f,%.0f %.0fx%.0f%s"):format(frame:GetLeft() * scale, frame:GetBottom() * scale,
			frame:GetWidth() * scale, frame:GetHeight() * scale, ns.Flag(frame:IsVisible()) and "" or " hidden")
			.. (" %s %d%s"):format(frame:GetFrameStrata(), frame:GetFrameLevel(),
				frame.IsToplevel and frame:IsToplevel() and " toplevel" or "")
	end
	local function SelfTargeted()
		if not (state.want and UnitExists("target") and ns.Flag(UnitIsUnit("target", "player"))) then return end
		local focus = ns.MouseFocus and ns.MouseFocus()
		local name = focus and (focus.GetDebugName and focus:GetDebugName() or focus.GetName and focus:GetName())
		local over = UnitExists("mouseover") and ns.Flag(UnitIsUnit("mouseover", "player"))
		ns.Log("shoulder", ("selecting yourself: you're targeted anyway: mouse on %s, over you %s, our button %s at %s,"
			.. " player frame at %s, keys %s, in combat %s"):format(tostring(name or "the world"), tostring(over),
			fake:IsShown() and "shown" or "hidden", Rect(fake), Rect(_G.PlayerFrame), state.keys ~= "" and state.keys or "none",
			tostring(InCombatLockdown())) .. (" | our mouse %s, clicks %s, motion %s"):format(tostring(fake:IsMouseEnabled()),
			tostring(fake.IsMouseClickEnabled and fake:IsMouseClickEnabled()),
			tostring(fake.IsMouseMotionEnabled and fake:IsMouseMotionEnabled())))
	end
	-- A stand-in target frame of you while selecting yourself cleared your
	-- target: with no target the game shows no target frame ("the target frame
	-- no longer appears", user 2026-11-20). Look only (not clickable: clicks go
	-- to the world), drawn by us from the game's own atlases where the game's
	-- target frame puts them (ns.UnitFrameRecipe, Style/UnitFrameCopy.lua), at
	-- your target frame's spot, its alpha your player frame's. A copy of the
	-- game's own frame can't work: run by an addon its code errors on Forever's
	-- secret health and mana (the standin probe). Bars take secret values, never
	-- compared. No buffs, Esc doesn't close it, the game's look (user's picks).
	-- Up when our button clears your target, down when you target anything,
	-- select yourself again, or the option's not on.
	local stand = { at = "" }
	local TargetAlpha -- (below)
	local Auras -- (below)
	local POWER_ATLAS = { MANA = "Mana", RAGE = "Rage", ENERGY = "Energy", FOCUS = "Focus",
		RUNIC_POWER = "RunicPower", INSANITY = "Insanity", MAELSTROM = "Maelstrom", FURY = "Fury", PAIN = "Pain",
		LUNAR_POWER = "LunarPower" }
	local function AtlasOK(atlas)
		return atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
	end
	local function SetAtlas(texture, atlas)
		if not atlas then return false end
		local ok, done = pcall(texture.SetAtlas, texture, atlas)
		return ok and done ~= false
	end
	-- A part where the recipe has it: false if it has no place. The recipe can
	-- mark a part hidden (retail's target frame has no level circle) or give
	-- one no place (a part read only by its side): hidden here too, or put at
	-- the built-in recipe's place. (Every part was taken to have one: the
	-- stand-in failed to build on retail and its loop was turned off, 2026-11-20.)
	-- Your power bar shows whatever the recipe says: its "hidden" is a target's
	-- with no power.
	local function Placed(e)
		return type(e) == "table" and type(e.x) == "number" and type(e.y) == "number" and type(e.w) == "number"
			and type(e.h) == "number"
	end
	-- (Besides a place: a text by its anchor point {anchor = {point, x, y}}, art
	-- units from the art's top-left, no width; or one whose side alone is known
	-- {onBar}, on the health bar's top edge on that side, as the Unit Frames
	-- preview puts it. The built-in recipe's place is WoW Forever's layout: on
	-- retail it'd put the name on the level, so a part with nothing there stays
	-- where it was. The recipe's own owner, 2026-11-20.)
	local function Spot(f, region, entry, role)
		if type(entry) == "table" and entry.hidden and role ~= "power" and role ~= "powerMask" then
			region:Hide()
			return false
		end
		local anchor = type(entry) == "table" and type(entry.anchor) == "table" and entry.anchor
		if anchor and type(anchor[2]) == "number" and type(anchor[3]) == "number" then
			region:ClearAllPoints()
			region:SetPoint(anchor[1] or "TOPLEFT", f, "TOPLEFT", anchor[2], -anchor[3])
			if region.Show then region:Show() end
			return true
		end
		if type(entry) == "table" and entry.onBar and stand.health then
			local right = entry.justify == "RIGHT"
			region:ClearAllPoints()
			region:SetPoint(right and "BOTTOMRIGHT" or "BOTTOMLEFT", stand.health, right and "TOPRIGHT" or "TOPLEFT", 0, 2)
			if region.Show then region:Show() end
			return true
		end
		local base = role and not ns.isRetail and ns.UNIT_FRAME_RECIPES and ns.UNIT_FRAME_RECIPES.TARGET
		local spot = Placed(entry) and entry or (base and Placed(base[role]) and base[role]) or nil
		if not spot then return false end
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", f, "TOPLEFT", spot.x, -spot.y)
		region:SetSize(spot.w, spot.h)
		if region.Show then region:Show() end
		return true
	end
	-- (A bar's fill only once the bar has its texture: masking none errored and
	-- left the stand-in half built, no name or level, the first game run.)
	local function Mask(f, region, entry, owner)
		if not (region and Placed(entry) and entry.atlas) then return end
		local mask = (owner or f):CreateMaskTexture()
		Spot(f, mask, entry)
		if SetAtlas(mask, entry.atlas) then pcall(region.AddMaskTexture, region, mask) end
		return mask
	end
	-- Built once, the first time it's needed (the recipe's read by then); kept
	-- only once it's all built (a half-built one is dropped, made again). Its
	-- parts carry the game's target frame's names (unit, healthbar, manabar,
	-- name, portrait, TargetFrameContainer.FrameTexture and PortraitMask,
	-- TargetFrameContent.TargetFrameContentMain.ReputationColor): Style's unit
	-- frames dress it as your target frame (UnitStyle.lua's TARGET list), so
	-- it wears your theme, as the real one of you would.
	-- (Each part's place in the recipe as a key: a part is put in its place
	-- again only when its key changes. Put back each time it came up, it undid
	-- what a theme had made of it, the level badge (made once, as the frame's
	-- first dressed), the parts probe, 2026-11-20.)
	local SPOT_ROLES = { "art", "reaction", "portrait", "portraitMask", "health", "healthMask", "power", "powerMask",
		"circle", "name", "level" }
	local function SpotKey(e)
		if type(e) ~= "table" then return "-" end
		if e.hidden then return "h" end
		local anchor = type(e.anchor) == "table" and e.anchor or {}
		return ("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"):format(tostring(e.x), tostring(e.y), tostring(e.w), tostring(e.h),
			tostring(e.justify), tostring(e.onBar), tostring(e.atlas), tostring(e.size), tostring(anchor[1]),
			tostring(anchor[2]), tostring(anchor[3]))
	end
	-- (The level by the side of the game's box it's justified to, as wide as
	-- its words: in the game's box, 11 wide, "10" read "..."; in a box widened
	-- to 36 the words sat at its edge, so a theme's badge, centering the box
	-- on its ring, put the level beside the ring, the 2026-11-21 run.)
	local function PlaceLevel(f, recipe)
		local level = Placed(recipe.level) and recipe.level
			or (not ns.isRetail and ns.UNIT_FRAME_RECIPES and Placed(ns.UNIT_FRAME_RECIPES.TARGET.level)
				and ns.UNIT_FRAME_RECIPES.TARGET.level)
		if not level then return end
		local justify = level.justify or "RIGHT"
		local x = justify == "RIGHT" and level.x + level.w or justify == "CENTER" and level.x + level.w / 2 or level.x
		stand.level:ClearAllPoints()
		stand.level:SetSize(0, 0)
		stand.level:SetPoint(justify == "CENTER" and "CENTER" or justify, f, "TOPLEFT", x, -(level.y + level.h / 2))
		stand.level:SetJustifyH(justify)
	end
	local function Build()
		if stand.frame then return stand.frame end
		local recipe = ns.UnitFrameRecipe and ns.UnitFrameRecipe("TARGET")
		if not (recipe and recipe.art and recipe.health and recipe.power) then return nil end
		local f = CreateFrame("Frame", "CinematicShoulderSelfTarget", UIParent)
		-- (A place from the start, moved to your target frame's as it comes up: a
		-- theme dresses it as it's made, and with no place its sides can't be
		-- told, so its level badge went on the portrait's other corner, for
		-- good, the 2026-11-21 run.)
		f:SetPoint("CENTER", UIParent, "CENTER")
		stand.recipe = recipe
		f:SetSize(recipe.art.w, recipe.art.h)
		f:EnableMouse(false)
		f:Hide()
		f.unit = "player"
		local holder = CreateFrame("Frame", nil, f)
		holder:SetAllPoints()
		local art = holder:CreateTexture(nil, "BACKGROUND", nil, 2)
		Spot(f, art, recipe.art, "art")
		SetAtlas(art, recipe.art.atlas)
		holder.FrameTexture = art
		f.TargetFrameContainer = holder
		stand.art, stand.holder = art, holder
		local main = {}
		f.TargetFrameContent = { TargetFrameContentMain = main }
		if recipe.reaction then
			-- (Over the frame art, as the game's strip is (its content over its
			-- container): under it, the art's dark band dulled ours, the
			-- side-by-side run, 2026-11-21.)
			local over = CreateFrame("Frame", nil, f)
			over:SetAllPoints()
			over:SetFrameLevel(holder:GetFrameLevel() + 1)
			stand.reaction = over:CreateTexture(nil, "BACKGROUND", nil, 0)
			Spot(f, stand.reaction, recipe.reaction, "reaction")
			SetAtlas(stand.reaction, recipe.reaction.atlas)
			main.ReputationColor = stand.reaction
		end
		-- (On the holder, as the game's portrait is on its container: a theme's
		-- bridge from the bars runs in under a portrait that isn't the frame's
		-- own, to its middle; on the frame it stopped at its edge, 1 wide, the
		-- parts probe, 2026-11-20. Under the frame art, as the game's.)
		stand.portrait = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
		Spot(f, stand.portrait, recipe.portrait, "portrait")
		holder.PortraitMask = Mask(f, stand.portrait, recipe.portraitMask, holder)
		f.portrait = stand.portrait
		stand.health = CreateFrame("StatusBar", nil, f)
		-- (Its numbers, in the game's bar text font, over its middle: Numbers.)
		stand.health.cineNumbers = stand.health:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
		stand.health.cineNumbers:SetPoint("CENTER", stand.health, "CENTER", 0, 0)
		stand.health.cineNumbers:Hide()
		-- (By the game's name for a bar's numbers too: Style sizes them to fit
		-- the bar, and a slab theme moves them to its end or hides them, as on
		-- the game's frame. As cineNumbers alone it didn't, the side-by-side
		-- run, 2026-11-21: ours centered and one size on every bar.)
		stand.health.TextString = stand.health.cineNumbers
		Spot(f, stand.health, recipe.health, "health")
		pcall(stand.health.SetStatusBarTexture, stand.health, recipe.health.atlas)
		stand.healthMask = Mask(f, stand.health:GetStatusBarTexture(), recipe.healthMask)
		f.healthbar = stand.health
		stand.power = CreateFrame("StatusBar", nil, f)
		stand.power.cineNumbers = stand.power:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
		stand.power.cineNumbers:SetPoint("CENTER", stand.power, "CENTER", 0, 0)
		stand.power.cineNumbers:Hide()
		stand.power.TextString = stand.power.cineNumbers
		Spot(f, stand.power, recipe.power, "power")
		pcall(stand.power.SetStatusBarTexture, stand.power, recipe.power.atlas)
		-- (Masked only by a mask the recipe read: a guessed one showed a strip in
		-- the bar's middle, the first themed run 2026-11-20.)
		stand.powerMask = Mask(f, stand.power:GetStatusBarTexture(), recipe.powerMask)
		f.manabar = stand.power
		-- (Both bars over the frame art, as the game's are (its bars above its
		-- container): at the art's own level ours could draw under it, the
		-- side-by-side probe, 2026-11-21.)
		stand.health:SetFrameLevel(holder:GetFrameLevel() + 1)
		-- (The power bar one over the health bar, as the game's: its top edge's
		-- line draws over the health bar's bottom; level with it, ours lost
		-- that line, the probe, 2026-11-21.)
		stand.power:SetFrameLevel(holder:GetFrameLevel() + 2)
		local top = CreateFrame("Frame", nil, f)
		top:SetAllPoints()
		top:SetFrameLevel(stand.health:GetFrameLevel() + 2)
		local circle
		if recipe.circle then
			-- (In the game's layer for it, OVERLAY: the probe, 2026-11-21.)
			circle = top:CreateTexture(nil, "OVERLAY", nil, 0)
			Spot(f, circle, recipe.circle, "circle")
			SetAtlas(circle, recipe.circle.atlas)
			main.LevelBackgroundCircle = circle
			stand.circle = circle
		end
		stand.name = top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		Spot(f, stand.name, recipe.name, "name")
		stand.name:SetJustifyH(recipe.name.justify or "CENTER")
		f.name = stand.name
		stand.level = top:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
		-- (At the recipe's size, as the game's: the template's own read smaller.)
		local file, _, flags = stand.level:GetFont()
		if file and recipe.level.size then pcall(stand.level.SetFont, stand.level, file, recipe.level.size, flags) end
		main.LevelText = stand.level
		-- (Your PvP flag by the portrait, as the game's target frame of you shows
		-- it: missing on ours, the side-by-side run 13 (a flagged character).
		-- Under the game's names, so the Show in rows reach it: Looks.)
		-- (The game draws it as PvpBackgroundIcon, a small circle in your
		-- faction's art, OVERLAY: its PvpIcon stays hidden, run 15's listing.)
		stand.pvp = top:CreateTexture(nil, "OVERLAY", nil, 0)
		stand.pvp:Hide()
		f.TargetFrameContent.TargetFrameContentContextual = { PvpBackgroundIcon = stand.pvp }
		PlaceLevel(f, recipe)
		stand.spotKeys = {}
		for _, role in ipairs(SPOT_ROLES) do stand.spotKeys[role] = SpotKey(recipe[role]) end
		stand.frame = f
		return f
	end
	-- Every part where the recipe has it now: as it comes up, the recipe read
	-- again (ns.UnitFrameRecipe: a part read off the game's target frame
	-- replaces its built-in guess; the target's power bar was one, so the
	-- stand-in's mana bar was too wide and unmasked: "mana frame looks off",
	-- user 2026-11-20). A mask the recipe has now is made once.
	local function Respot()
		local f = stand.frame
		local recipe = ns.UnitFrameRecipe and ns.UnitFrameRecipe("TARGET")
		if not (f and recipe and recipe.art and recipe.health and recipe.power) then return end
		stand.recipe = recipe
		-- (Only the parts whose place changed: SpotKey.)
		local keys, done = stand.spotKeys or {}, {}
		local function Changed(role)
			local key = SpotKey(recipe[role])
			if keys[role] == key then return false end
			keys[role], done[#done + 1] = key, role
			return true
		end
		stand.spotKeys = keys
		if Changed("art") then f:SetSize(recipe.art.w, recipe.art.h) end
		for _, pair in ipairs({ { stand.art, "art" }, { stand.reaction, "reaction" }, { stand.portrait, "portrait" },
			{ stand.holder and stand.holder.PortraitMask, "portraitMask" }, { stand.health, "health" },
			{ stand.healthMask, "healthMask" }, { stand.power, "power" }, { stand.powerMask, "powerMask" },
			{ stand.circle, "circle" }, { stand.name, "name" } }) do
			local region = pair[1]
			if (pair[2] == "art" and done[1] == "art") or (pair[2] ~= "art" and Changed(pair[2])) then
				if region then Spot(f, region, recipe[pair[2]], pair[2]) end
			end
		end
		if not stand.powerMask and recipe.powerMask then
			stand.powerMask = Mask(f, stand.power:GetStatusBarTexture(), recipe.powerMask)
		end
		if Changed("level") then PlaceLevel(f, recipe) end
		if #done > 0 then ns.LogDetail("shoulder", "selecting yourself: parts put in place again: " .. table.concat(done, ", ")) end
	end
	-- (The target's power bar still the recipe's guess: after a target change,
	-- out of a fight, the recipe's read asked for once the game's frame has
	-- drawn it, a target with power or not: the read keeps what it can see.)
	local powerAsked = 0
	local function AskPowerRead()
		local recipe = stand.recipe
		if not (recipe and recipe.power and recipe.power.guess) or InCombatLockdown() then return end
		if GetTime() - powerAsked < 2 or not UnitExists("target") then return end
		powerAsked = GetTime()
		C_Timer.After(0.5, function()
			if ns.UnitFrameRecipe and not InCombatLockdown() then
				local again = ns.UnitFrameRecipe("TARGET")
				stand.recipe = again or stand.recipe
				if again and again.power and not again.power.guess then
					ns.Log("shoulder", "selecting yourself: the target power bar's place read off the game's frame")
				end
			end
		end)
	end
	stand.AskPowerRead = AskPowerRead
	-- Your health and power on it, as they change (secret ones too: only the
	-- bars take them). Nothing of its look: that's Looks' and your theme's.
	-- Each bar's numbers, "now / most", as the game's target frame shows
	-- them: always with your status text on, else while the mouse is on it
	-- (the 2026-11-21 run's screenshot: "593 / 593" on the game's, nothing on
	-- ours). Set by the game's own text call, which takes values hidden in
	-- fights; where even that won't, no numbers, and the log says so.
	local function Numbers(bar, now, most)
		local text = bar and bar.cineNumbers
		if not text then return end
		local always = GetCVar and GetCVar("statusText") == "1"
		if not (always or stand.hover) then text:Hide() return end
		-- (With the game's thousands separators: "1,318", as its numbers; ours
		-- read "1318", the side-by-side run 13. Its own formatter, which takes
		-- a hidden value too; where it won't, the plain number.)
		local function Grouped(v)
			local okG, out = pcall(BreakUpLargeNumbers or tostring, v)
			if okG and out ~= nil then return out end
			return v
		end
		local ok = pcall(text.SetFormattedText, text, "%s / %s", Grouped(now), Grouped(most))
		text:SetShown(ok)
		if not ok and not stand.numbersLogged then
			stand.numbersLogged = true
			ns.Log("shoulder", "selecting yourself: the bars' numbers can't be shown (their values hidden)")
		end
		stand.numbersShown = ok
	end
	-- (Each bar's numbers where the game centers its own, off its bar's middle:
	-- its health text hangs on the bar holder, higher than the bar's middle,
	-- so ours sat 2.5 units low, the side-by-side run 10. Read off the game's
	-- anchor once, only while both sit at the game's own centered spot: a slab
	-- theme puts them at the bar's end. With health on it the anchor is
	-- secret too (comparing it errored, the side-by-side run 11): then the
	-- bar's holder's middle, where the game hangs it.)
	local function Secret(v) return issecretvalue and issecretvalue(v) end
	local function PlainNumbers(...)
		for i = 1, select("#", ...) do
			local v = select(i, ...)
			if type(v) ~= "number" or Secret(v) then return false end
		end
		return true
	end
	local function TextSpot(bar, gameBar)
		stand.textSpots = stand.textSpots or {}
		if stand.textSpots[bar] or InCombatLockdown() then return end
		local text, game = bar and bar.cineNumbers, type(gameBar) == "table" and gameBar.TextString
		if not (text and type(game) == "table" and game.GetPoint) then return end
		local okMine, mine = pcall(text.GetPoint, text, 1)
		if not (okMine and type(mine) == "string" and not Secret(mine) and mine == "CENTER") then return end
		local okB, bx, by = pcall(gameBar.GetCenter, gameBar)
		if not (okB and PlainNumbers(bx, by)) then return end
		local ok, point, to, relative, x, y = pcall(game.GetPoint, game, 1)
		local dx, dy, from
		if ok and not (Secret(point) or Secret(relative) or Secret(to) or Secret(x) or Secret(y)) then
			if not (point == "CENTER" and relative == "CENTER" and type(to) == "table" and to.GetCenter) then return end
			local okC, tx, ty = pcall(to.GetCenter, to)
			if not (okC and PlainNumbers(tx, ty, x, y)) then return end
			dx, dy, from = tx + x - bx, ty + y - by, "its anchor"
		else
			local holder = gameBar.GetParent and gameBar:GetParent()
			local okH, hx, hy = pcall(function() return holder:GetCenter() end)
			if not (okH and PlainNumbers(hx, hy)) then return end
			dx, dy, from = hx - bx, hy - by, "its bar holder (the anchor's secret)"
			if math.abs(dx) > 6 or math.abs(dy) > 6 then return end
		end
		stand.textSpots[bar] = { dx, dy }
		text:ClearAllPoints()
		text:SetPoint("CENTER", bar, "CENTER", dx, dy)
		ns.LogDetail("shoulder", ("selecting yourself: numbers placed as the game's, %+.1f,%+.1f off the bar's middle, from %s"):format(
			dx, dy, from))
	end
	stand.TextSpot = TextSpot
	local function Values()
		local f = stand.frame
		if not (f and f:IsShown()) then return end
		local real = _G.TargetFrame
		-- (Guarded: a value of the game's turning out secret must never stop the frame's bars.)
		pcall(TextSpot, stand.health, real and real.healthbar)
		pcall(TextSpot, stand.power, real and real.manabar)
		local health, healthMost = UnitHealth("player"), UnitHealthMax("player")
		local power, powerMost = UnitPower("player"), UnitPowerMax("player")
		pcall(stand.health.SetMinMaxValues, stand.health, 0, healthMost)
		pcall(stand.health.SetValue, stand.health, health)
		pcall(stand.power.SetMinMaxValues, stand.power, 0, powerMost)
		pcall(stand.power.SetValue, stand.power, power)
		Numbers(stand.health, health, healthMost)
		Numbers(stand.power, power, powerMost)
	end
	stand.Values = Values
	-- Its look in the game's way (portrait, name, level, the name strip's color,
	-- the power bar's art), then your theme over it, as the game sets your
	-- target frame's and Style dresses it after. As it comes up, and when one of
	-- those changes; not with each health change (that'd undo the theme's colors).
	-- (Your PvP flag: the game's art for it (free-for-all, or your faction's),
	-- where the game's target frame has its own, read off it while it can be
	-- (its place, from its frame art's top-left), kept for when it can't.)
	local function Pvp()
		local icon = stand.pvp
		if not icon then return end
		local function Yes(v) return v == true and not (issecretvalue and issecretvalue(v)) end
		local atlas
		local okF, ffa = pcall(UnitIsPVPFreeForAll, "player")
		local okP, flagged = pcall(UnitIsPVP, "player")
		local okG, faction = pcall(UnitFactionGroup, "player")
		if okF and Yes(ffa) then
			atlas = "UI-HUD-UnitFrame-SmallCircle-FFA"
		elseif okP and Yes(flagged) and okG and (faction == "Alliance" or faction == "Horde") then
			atlas = "UI-HUD-UnitFrame-SmallCircle-" .. faction
		end
		local game = _G.TargetFrame
		local content = game and type(game.TargetFrameContent) == "table" and game.TargetFrameContent
		local context = content and type(content.TargetFrameContentContextual) == "table" and content.TargetFrameContentContextual
		local theirs = context and type(context.PvpBackgroundIcon) == "table" and context.PvpBackgroundIcon
		local holder = game and type(game.TargetFrameContainer) == "table" and game.TargetFrameContainer
		local art = holder and holder.FrameTexture
		if theirs and art and not InCombatLockdown() then
			-- (In the art's own units: the icon has a scale of its own. Taken
			-- as it was, ours stood 1.25 times too big and off the frame, the
			-- side-by-side run 16.)
			local ok, l, t, w, h, al, at, ps, as = pcall(function()
				return theirs:GetLeft(), theirs:GetTop(), theirs:GetWidth(), theirs:GetHeight(), art:GetLeft(), art:GetTop(),
					theirs:GetEffectiveScale(), art:GetEffectiveScale()
			end)
			local plain = ok
			for _, v in ipairs(ok and { l, t, w, h, al, at, ps, as } or {}) do
				if type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then plain = false end
			end
			if plain and w > 1 and h > 1 and as > 0 then
				stand.pvpSpot = { (l * ps - al * as) / as, (at * as - t * ps) / as, w * ps / as, h * ps / as }
			end
		end
		local spot = stand.pvpSpot
		if not (atlas and spot and AtlasOK(atlas)) then icon:Hide() return end
		icon:SetAtlas(atlas)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", stand.frame, "TOPLEFT", spot[1], -spot[2])
		icon:SetSize(spot[3], spot[4])
		icon:Show()
	end
	local function Looks()
		local f = stand.frame
		if not (f and f:IsShown()) then return end
		pcall(Pvp)
		pcall(SetPortraitTexture, stand.portrait, "player")
		stand.name:SetText(UnitName("player"))
		stand.level:SetText(UnitLevel("player"))
		if stand.reaction then
			local ok, r, g, b = pcall(UnitSelectionColor, "player")
			if ok and r then pcall(stand.reaction.SetVertexColor, stand.reaction, r, g, b) end
		end
		local _, token = UnitPowerType("player")
		local name = POWER_ATLAS[token or ""]
		local atlas = name and ("UI-HUD-UnitFrame-Target-PortraitOn-Bar-" .. name)
		local fill
		if AtlasOK(atlas) then
			pcall(stand.power.SetStatusBarTexture, stand.power, atlas)
			fill = stand.power:GetStatusBarTexture()
			if fill then fill:SetDesaturated(false) end
			stand.power:SetStatusBarColor(1, 1, 1)
		else
			-- (No art of its own: the mana bar's, grey, in the game's color for it.)
			pcall(stand.power.SetStatusBarTexture, stand.power, stand.recipe.power.atlas)
			fill = stand.power:GetStatusBarTexture()
			if fill then fill:SetDesaturated(true) end
			local color = _G.PowerBarColor and _G.PowerBarColor[token or ""]
			if type(color) == "table" and type(color.r) == "number" then
				stand.power:SetStatusBarColor(color.r, color.g, color.b)
			end
		end
		stand.health:SetStatusBarColor(1, 1, 1)
		Values()
		if ns.RefreshUnitStyle then ns.RefreshUnitStyle() end
	end
	local LOOK_EVENTS = { UNIT_DISPLAYPOWER = true, UNIT_PORTRAIT_UPDATE = true, UNIT_LEVEL = true, UNIT_FACTION = true }
	-- Where the game's target frame art is (its top-left, in its own units) and
	-- its effective scale; from the art when the frame has a place, else the
	-- frame's top-left plus the offset last seen.
	local function TargetSpot()
		local frame = _G.TargetFrame
		if not frame then return nil end
		local container = type(frame.TargetFrameContainer) == "table" and frame.TargetFrameContainer
		local art = container and container.FrameTexture
		local left, top = art and art:GetLeft(), art and art:GetTop()
		local fl, ft = frame:GetLeft(), frame:GetTop()
		if left and top and fl and ft then
			stand.offset = { left - fl, top - ft }
			if ns.db then ns.db.shoulderSelfTargetOffset = stand.offset end
			return left, top, art:GetEffectiveScale()
		end
		local offset = stand.offset or (ns.db and ns.db.shoulderSelfTargetOffset) or { 0, 0 }
		if fl and ft then return fl + offset[1], ft + offset[2], frame:GetEffectiveScale() end
	end
	local function PlaceStand()
		local left, top, scale = TargetSpot()
		if not left then return false end
		-- (The side-by-side test's: under or over the game's frame of you.)
		top = top + (stand.beside or 0)
		local key = ("%.1f %.1f %.3f"):format(left, top, scale)
		if key ~= stand.at then
			stand.at = key
			local f = stand.frame
			f:SetScale(scale / UIParent:GetEffectiveScale())
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		end
		return true
	end
	local function StandDown(why)
		if not (stand.frame and stand.frame:IsShown()) then return end
		stand.frame:Hide()
		stand.events:UnregisterAllEvents()
		ns.Log("shoulder", "selecting yourself: stand-in target frame down (" .. why .. ")")
	end
	local function StandUp()
		if not (Build() and PlaceStand()) then
			ns.Log("shoulder", "selecting yourself: no stand-in target frame (no recipe, or no target frame spot)")
			return
		end
		stand.frame:Show()
		for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
			"UNIT_DISPLAYPOWER", "UNIT_PORTRAIT_UPDATE", "UNIT_LEVEL", "UNIT_FACTION" }) do
			stand.events:RegisterUnitEvent(event, "player")
		end
		stand.alpha = nil
		Respot()
		stand.frame:SetAlpha(TargetAlpha())
		Looks()
		Auras()
		ns.Log("shoulder", "selecting yourself: stand-in target frame up at " .. stand.at)
	end
	stand.events = CreateFrame("Frame")
	stand.events:SetScript("OnEvent", function(_, event) ns.Guard(LOOK_EVENTS[event] and Looks or Values) end)
	-- (Your Target Self key or a left-click: our button's click, after it ran.)
	-- (A select-yourself click, after it cleared your target: our button's, or
	-- a party or raid frame of you that's set up the same way, below.)
	-- (Selected again while it's up: it stays up, as the game keeps you
	-- targeted when you click yourself again. It toggled till 2026-11-21:
	-- the menu button's secure toggle and this one went out of step, so
	-- clicking on made it blink on and off, up with no menu button, so Esc
	-- couldn't put it away (user report).)
	local function SelectedYourself(_, mouse)
		if mouse ~= "LeftButton" or not state.want then return end
		stand.selects = (stand.selects or 0) + 1
		if not (stand.frame and stand.frame:IsShown()) and not UnitExists("target") then
			ns.Guard(StandUp)
		end
	end
	fake:HookScript("OnClick", SelectedYourself)
	stand.SelectedYourself = SelectedYourself
	-- Your target frame's fade (Frames.lua's entry for it): while the stand-in
	-- is up the show rules count you as your own target (ns.ShoulderSelfTargetUp),
	-- so this is what your target frame would have. 1 with none (not faded).
	-- (Your player frame's till 2026-11-20: faded in CineMode, it hid the
	-- stand-in while your real target frame of you shows.)
	-- (Looked up each time, a few times a second: an entry kept would stay
	-- after its page went off.)
	function TargetAlpha()
		local frame = _G.TargetFrame
		for _, each in ipairs(ns.managed or {}) do
			if each.frame == frame then return tonumber(each.alpha) or 1 end
		end
		return 1
	end
	-- Your buffs, then your debuffs, under it as the game's target frame of you
	-- has them (user 2026-11-20): copies of the game's own buff and debuff
	-- icons (BuffFrame and DebuffFrame's auraFrames), picture and stack count
	-- set straight from theirs, so Forever's secret ones in fights draw too
	-- (as ns.MirrorBuffs' copies do, Frames.lua); each at its icon's own alpha
	-- (the game pulses one about to end). No timer swirl: its times are
	-- secret in fights. Sizes in the stand-in's own units, read off the game's
	-- plain target frame of you (selfframe runs 2026-11-20): 20 square, 4
	-- apart, 5 to a row, from 56 down the art (just under the bars, 52 touched:
	-- the art's lower part is clear), 2 in; debuffs on a row of their own
	-- after. (27, 6 and under the whole art till then, read off a themed one:
	-- too big, too low.)
	-- (AURA_TOP: the first row's top under the art's, measured on the game's
	-- target frame of you, the same in all 17 themes: 58.7; at 56 ours touched
	-- the frame's edge, at 59.5 it sat a pixel low, the side-by-side runs,
	-- 2026-11-21.)
	local AURA_BIG, AURA_SMALL, AURA_GAP, AURA_ROW_WIDE, AURA_MOST, AURA_TOP, AURA_LEFT = 21, 17, 3, 122, 20, 58.7, 5
	-- (With the target frame's Buffs on Top (Edit Mode; frame.buffsOnTop), the
	-- first row's bottom this far under the art's top, the rows going up from
	-- it, the icons sharing their bottom edge: measured off the game's in the
	-- side-by-side runs' shots, 2026-11-21 (4.8 sat a pixel high; its row's
	-- place can't be read on Forever, rule
	-- forever.targetframe.aura-container-place-secret). Lifted more over a
	-- theme's name plate, as Style lifts the game's (UnitAuraLift.lua): in Fel
	-- ours sat 3 units under it.)
	local AURA_ON_TOP = 5.6
	-- (Sizes since the parts probe, 2026-11-20, measured off the game's target
	-- frame of you in its screenshot: your own auras 21 square, others' 17, 3
	-- apart, from 5 in, a row as wide as 122 (Blizzard's own numbers); 20, 4
	-- and 2 till then.)
	-- What the game says of an aura, read out of fights by its aura id and
	-- kept for fights, where it won't say: whether it's yours or your pet's
	-- (its size), whether you cast it yourself and could cast it (its place:
	-- Order). Not known: yours, cast by you.
	local facts = {}
	local function Plain(v) return type(v) == "number" and not (issecretvalue and issecretvalue(v)) end
	local function Facts(info)
		local id = info and info.auraInstanceID
		if not Plain(id) then return nil, nil end
		local read = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
		if facts[id] == nil and read and not InCombatLockdown() then
			local ok, data = pcall(read, "player", id)
			if ok and type(data) == "table" then
				local function Flag(v) if type(v) == "boolean" and not (issecretvalue and issecretvalue(v)) then return v end end
				local source = data.sourceUnit
				local byYou, mine
				if type(source) == "string" and not (issecretvalue and issecretvalue(source)) then
					local okUnit, same = pcall(UnitIsUnit, "player", source)
					byYou = okUnit and same == true
					-- (Big when you or your pet cast it, as the game's: "from a
					-- player" is any player's, so a mage's Arcane Intellect on
					-- you drew big on ours, small on the game's, 2026-11-21.)
					local owns = UnitIsOwnerOrControllerOfUnit
					local okPet, pet = pcall(owns or UnitIsUnit, owns and "player" or "pet", source)
					mine = byYou or (okPet and pet == true)
				elseif source == nil then
					byYou, mine = false, false
				end
				facts[id] = { yours = mine, byYou = byYou, canApply = Flag(data.canApplyAura) }
			end
		end
		return facts[id], id
	end
	local function Yours(info)
		local fact = Facts(info)
		return not (fact and fact.yours == false)
	end
	-- (The game's target frame's order, Blizzard's own for auras: the ones you
	-- cast first, then ones you could cast, then the order you got them in.
	-- Your aura list's order put your pet's Blood Pact before your own, the
	-- 2026-11-21 run's screenshots. Where it can't be told of each: the list.)
	local function Order(list, first)
		local keyed = {}
		for i = first, #list do
			local fact, id = Facts(list[i].buttonInfo)
			if not (fact and fact.byYou ~= nil and id) then return false end
			keyed[#keyed + 1] = { button = list[i], byYou = fact.byYou, canApply = fact.canApply == true, id = id }
		end
		table.sort(keyed, function(a, b)
			if a.byYou ~= b.byYou then return a.byYou end
			if a.canApply ~= b.canApply then return a.canApply end
			return a.id < b.id
		end)
		for k, each in ipairs(keyed) do list[first + k - 1] = each.button end
		return true
	end
	-- The game's buff or debuff icons with an aura on them, in the target
	-- frame's order (Order; the buff bar sorts its own way: the parts probe). Not a weapon enchant's (the target frame shows none);
	-- not an empty slot (the probe found six on the debuff bar, copied as
	-- blank squares you could hover).
	local function ShownIcons(frame, list)
		local icons = type(frame) == "table" and frame.auraFrames
		if type(icons) ~= "table" then return end
		local first = #list + 1
		for i = 1, #icons do
			local button = icons[i]
			local ok, shown = pcall(button.IsShown, button)
			local info = type(button.buttonInfo) == "table" and button.buttonInfo or nil
			if ok and (shown == true or (issecretvalue and issecretvalue(shown))) and type(button.Icon) == "table"
				and info and button.hasValidInfo ~= false and info.auraType ~= "TempEnchant"
				and (info.texture ~= nil or info.index ~= nil or info.auraInstanceID ~= nil) then
				list[#list + 1] = button
			end
		end
		if Order(list, first) then return end
		-- (Else by index where every one says it, plainly; else as the bar has them.)
		local ordered = true
		for i = first, #list do
			if not Plain(list[i].buttonInfo.index) then ordered = false break end
		end
		if ordered then
			local part = {}
			for i = first, #list do part[#part + 1] = list[i] end
			table.sort(part, function(a, b) return a.buttonInfo.index < b.buttonInfo.index end)
			for k, button in ipairs(part) do list[first + k - 1] = button end
		end
	end
	-- Its time left, as the game's target frame of you shows it: a swirl, set
	-- from the game's icon's own end time and length, the dark part the time
	-- gone (reversed, as the game's: the parts probe; forward, a long buff
	-- came out nearly all dark). Where its times are hidden (in fights on
	-- Forever, after an aura changes, every buff's), the icon plain: the game
	-- still draws its swirl there, which an addon can't; no countdown text, the
	-- game shows none on a target frame (user 2026-11-20). A buff with no time
	-- has none. Set again only when its icon or its times change: set each
	-- look, the swirl would start over.
	local function Timer(copy, button)
		local info = type(button.buttonInfo) == "table" and button.buttonInfo or nil
		local ends, length = info and info.expirationTime, info and info.duration
		local hidden = issecretvalue and (issecretvalue(ends) or issecretvalue(length)) or false
		local timed = not hidden and type(ends) == "number" and ends > 0 and type(length) == "number" and length > 0
		local key = hidden and "hidden" or (timed and (ends .. "/" .. length) or "none")
		if copy.timerOf == button and copy.timerKey == key then return end
		copy.timerOf, copy.timerKey = button, key
		if timed and copy.Swirl.SetCooldownFromExpirationTime
			and pcall(copy.Swirl.SetCooldownFromExpirationTime, copy.Swirl, ends, length) then
			copy.Swirl:Show()
			copy.timer = "swirl"
			return
		end
		copy.Swirl:Hide()
		copy.timer = hidden and "hidden" or "none"
	end
	local function CopyIcon(copy, button)
		pcall(function() copy.Icon:SetTexture(button.Icon:GetTexture()) end)
		-- (The whole icon, its own edge too, as the target frame shows it: the
		-- buff bar's crop it was copied from cut the edge off, the side-by-side
		-- run, 2026-11-21. "bar": the buff bar's, for that run's A/B shot.)
		if stand.iconCrop == "bar" then
			pcall(function() copy.Icon:SetTexCoord(button.Icon:GetTexCoord()) end)
		else
			copy.Icon:SetTexCoord(0, 1, 0, 1)
		end
		local count = type(button.Count) == "table" and button.Count
		copy.Count:SetShown(count and true or false)
		if count then pcall(function() copy.Count:SetText(count:GetText()) end) end
		-- (A border on debuffs only, and only where the game shows one: every
		-- buff had one, the parts probe.)
		local border = copy.harmful and type(button.DebuffBorder) == "table" and button.DebuffBorder
		if border then
			local ok, up = pcall(border.IsShown, border)
			if not (ok and up == true) then border = nil end
		end
		copy.Border:SetShown(border and true or false)
		if border then
			pcall(function() copy.Border:SetTexture(border:GetTexture()) end)
			pcall(function() copy.Border:SetTexCoord(border:GetTexCoord()) end)
			pcall(function() copy.Border:SetVertexColor(border:GetVertexColor()) end)
		end
		-- (Full: the buff bar pulses one about to end, the target frame's don't;
		-- copied, ours went dim, the side-by-side run, 2026-11-21.)
		copy:SetAlpha(1)
		Timer(copy, button)
	end
	-- Its tooltip on hover, as the game's target frame's buffs have: the game's
	-- own for that buff, by its aura id, else by its place in your auras (the
	-- icon's index, plain in fights on Forever); a weapon enchant has neither:
	-- no tooltip. How it was shown, left on
	-- the copy for the tests: "aura id", "index" or "none". Never the game's
	-- buff icon's own hover script: that puts the tooltip by your buff bar.
	local function ShowTip(copy)
		local tip, button = _G.GameTooltip, copy.source
		if not (tip and button) then return end
		local info = type(button.buttonInfo) == "table" and button.buttonInfo or {}
		local filter = copy.harmful and "HARMFUL" or "HELPFUL"
		local id, index = info.auraInstanceID, info.index
		-- (Each way tried in turn, and what it did, for the tests and the log:
		-- the first run fell through all of them, unlogged, 2026-11-20.)
		local tries = {}
		local function Try(name, ...)
			local fn = tip[name]
			if type(fn) ~= "function" then tries[#tries + 1] = name .. " missing" return false end
			tip:SetOwner(copy, "ANCHOR_BOTTOMRIGHT", 15, -25)
			local ok, err = pcall(fn, tip, ...)
			local lines = ok and tip:NumLines() or 0
			tries[#tries + 1] = ("%s %s"):format(name, ok and (tostring(lines) .. " lines") or ("error " .. tostring(err)))
			return ok and type(lines) == "number" and lines > 0
		end
		local how = "none"
		if id ~= nil and Try(copy.harmful and "SetUnitDebuffByAuraInstanceID" or "SetUnitBuffByAuraInstanceID", "player", id, filter) then
			how = "aura id"
		elseif id ~= nil and Try("SetUnitAuraByAuraInstanceID", "player", id, filter) then
			how = "aura id"
		elseif index ~= nil and Try(copy.harmful and "SetUnitDebuff" or "SetUnitBuff", "player", index, filter) then
			how = "index"
		elseif index ~= nil and Try("SetUnitAura", "player", index, filter) then
			how = "index"
		end
		if how == "none" then
			tip:Hide()
			tries[#tries + 1] = ("its info: aura id %s, index %s"):format(tostring(id ~= nil), tostring(index ~= nil))
		else
			tip:Show()
		end
		copy.tipHow, copy.tipAt = how, GetTime()
		stand.tipHow, stand.tipShownAt = how, GetTime()
		stand.tipTries = table.concat(tries, "; ")
		if how == "none" or not copy.tipLogged then
			copy.tipLogged = true
			ns.Log("shoulder", ("selecting yourself: buff tooltip %s (%s)"):format(how, stand.tipTries))
		end
	end
	local function HideTip(copy)
		local tip = _G.GameTooltip
		if tip and tip:GetOwner() == copy then tip:Hide() end
		copy.tipAt = nil
	end
	local function AuraCopy(i)
		stand.auras = stand.auras or {}
		local copy = stand.auras[i]
		if not copy then
			copy = CreateFrame("Frame", nil, stand.frame)
			copy:SetSize(AURA_BIG, AURA_BIG)
			copy.Icon = copy:CreateTexture(nil, "ARTWORK")
			copy.Icon:SetAllPoints()
			copy.Border = copy:CreateTexture(nil, "OVERLAY")
			copy.Border:SetPoint("TOPLEFT", -1, 1)
			copy.Border:SetPoint("BOTTOMRIGHT", 1, -1)
			-- (A size up from the small one: the game's "3" stood a quarter
			-- taller, the side-by-side run 13; its aura buttons can't be read.)
			copy.Count = copy:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
			copy.Count:SetPoint("BOTTOMRIGHT", 2, -1)
			-- (The swirl without its own numbers, as the game's target frame's.)
			copy.Swirl = CreateFrame("Cooldown", nil, copy, "CooldownFrameTemplate")
			copy.Swirl:SetAllPoints()
			if copy.Swirl.SetHideCountdownNumbers then copy.Swirl:SetHideCountdownNumbers(true) end
			if copy.Swirl.SetReverse then copy.Swirl:SetReverse(true) end
			copy.Swirl:Hide()
			-- (Hover only: a click goes on through, to the world under it.)
			if copy.SetMouseMotionEnabled then
				copy:SetMouseMotionEnabled(true)
				if copy.SetMouseClickEnabled then copy:SetMouseClickEnabled(false) end
			else
				copy:EnableMouse(true)
			end
			copy:SetScript("OnEnter", function(self) ns.Guard(function() ShowTip(self) end) end)
			copy:SetScript("OnLeave", function(self) ns.Guard(function() HideTip(self) end) end)
			stand.auras[i] = copy
		end
		return copy
	end
	-- Its icons in rows under the bars, as the game lays them: each its size,
	-- a row as wide as AURA_ROW_WIDE, the next row under the row's biggest;
	-- debuffs on a row of their own after the buffs.
	function Auras()
		local f = stand.frame
		if not (f and f:IsShown()) then return end
		local buffs, debuffs = {}, {}
		ShownIcons(_G.BuffFrame, buffs)
		ShownIcons(_G.DebuffFrame, debuffs)
		local art = stand.recipe.art
		local frame = _G.TargetFrame
		local onTop = frame and frame.buffsOnTop == true
		stand.buffsOnTop = onTop
		-- (top: the row's edge nearest the frame, from the art's top: its top
		-- under the frame, its bottom over it.)
		local lift = onTop and ns.UnitAuraLiftNow and ns.UnitAuraLiftNow(frame) or 0
		if type(lift) ~= "number" or (issecretvalue and issecretvalue(lift)) then lift = 0 end
		stand.auraLift = lift
		local n, top = 0, onTop and AURA_ON_TOP - lift or AURA_TOP
		local step = onTop and -1 or 1
		for _, list in ipairs({ buffs, debuffs }) do
			local x, tallest = 0, 0
			for _, button in ipairs(list) do
				if n >= AURA_MOST then break end
				local size = Yours(button.buttonInfo) and AURA_BIG or AURA_SMALL
				if x > 0 and x + size > AURA_ROW_WIDE then
					top, x, tallest = top + step * (tallest + AURA_GAP), 0, 0
				end
				n = n + 1
				local copy = AuraCopy(n)
				copy.source, copy.harmful, copy.size = button, list == debuffs, size
				copy:SetSize(size, size)
				copy:ClearAllPoints()
				copy:SetPoint(onTop and "BOTTOMLEFT" or "TOPLEFT", f, "TOPLEFT", art.x + AURA_LEFT + x, -(art.y + top))
				CopyIcon(copy, button)
				copy:Show()
				-- (Its tooltip, while up, set again once a second: the time left.)
				if type(copy.tipAt) == "number" and GetTime() - copy.tipAt >= 1 and copy:IsMouseOver() then ShowTip(copy) end
				x, tallest = x + size + AURA_GAP, math.max(tallest, size)
			end
			if x > 0 then top = top + step * (tallest + AURA_GAP) end
		end
		for i = n + 1, #(stand.auras or {}) do stand.auras[i]:Hide() end
		stand.auraCount = n
	end
	-- (Each check: down when it's not wanted; its place and its alpha.)
	local function StandTick()
		local f = stand.frame
		if not (f and f:IsShown()) then return end
		if not stand.beside then
			if not state.want then return StandDown("option not on: " .. tostring(state.why)) end
			if UnitExists("target") then return StandDown("you targeted something") end
		end
		PlaceStand()
		local alpha = TargetAlpha()
		if alpha ~= stand.alpha then
			stand.alpha = alpha
			ns.LogDetail("shoulder", ("selecting yourself: stand-in alpha %.2f (your target frame's)"):format(alpha))
		end
		f:SetAlpha(alpha)
		-- (The game redraws its icons on the same aura change as us: copied each
		-- check, a few times a second, not on the event, which can come first.)
		Auras()
	end
	function ns.ShoulderSelfTargetUp() return stand.frame ~= nil and stand.frame:IsShown() end
	-- (The tests: how many times you've selected yourself with the option on.)
	function ns.ShoulderSelfTargetSelects() return stand.selects or 0 end
	stand.Tick = StandTick
	-- (The side-by-side test, /cine debug shoulder selfpair: up with you
	-- targeted, the game's frame of you on screen too, moved by down (in the
	-- target frame's units, minus = lower), redressed each call (a theme
	-- just put on). nil: down. Gives whether it's up.)
	-- (The side-by-side test's A/B: its icons cut as the buff bar's ("bar") or
	-- whole (nil); copied again on its next check.)
	function ns.ShoulderSelfTargetIconCrop(mode) stand.iconCrop = mode end
	function ns.ShoulderSelfTargetBeside(down)
		stand.beside = down
		stand.at = nil
		if down == nil then
			StandDown("the side-by-side test ended")
			return false
		end
		if stand.frame and stand.frame:IsShown() then
			PlaceStand()
			Respot()
			Looks()
			Auras()
		else
			StandUp()
		end
		return stand.frame ~= nil and stand.frame:IsShown()
	end
	function ns.ShoulderSelfTargetFrame() return stand.frame end
	-- (The tests: how many icon copies it shows, and how many of the game's
	-- buff and debuff icons are shown, capped as it caps them.)
	function ns.ShoulderSelfTargetAuras()
		local buffs, debuffs = {}, {}
		ShownIcons(_G.BuffFrame, buffs)
		ShownIcons(_G.DebuffFrame, debuffs)
		return stand.auraCount or 0, math.min(AURA_MOST, #buffs + #debuffs)
	end
	-- (The tests: how its last buff tooltip was shown, and whether one of its
	-- icons owns the game's tooltip now.)
	function ns.ShoulderSelfTargetTip()
		local tip, owned = _G.GameTooltip, false
		for i = 1, stand.auraCount or 0 do
			if tip and tip:IsShown() and tip:GetOwner() == stand.auras[i] then owned = true end
		end
		return stand.tipHow or "none", owned, tip and tip:IsShown() and tip:NumLines() or 0, stand.tipShownAt or 0,
			stand.tipTries or "none"
	end
	-- (The tests: whether its bars' numbers show now, and the health one's text.)
	function ns.ShoulderSelfTargetNumbers()
		local text = stand.health and stand.health.cineNumbers
		return text ~= nil and text:IsShown(), text and text:GetText()
	end
	-- (The tests: its icon copies now, and how many are up.)
	function ns.ShoulderSelfTargetAuraCopies() return stand.auras or {}, stand.auraCount or 0 end
	-- (The tests: how many of its icons show their time as a swirl, how many
	-- are plain with their times hidden (a fight), and how many have none.)
	function ns.ShoulderSelfTargetTimers()
		local count = { swirl = 0, hidden = 0, none = 0 }
		for i = 1, stand.auraCount or 0 do
			local kind = stand.auras[i] and stand.auras[i].timer or "none"
			count[kind] = (count[kind] or 0) + 1
		end
		return count.swirl, count.hidden, count.none
	end
	-- Your menu on a right-click of it, as the game's target frame of you has
	-- ("what right click is supposed to look like", user 2026-11-20). The
	-- stand-in itself takes no clicks: a secure button of its own, at its spot
	-- (pinned to the screen, not hung on it: that'd lock the stand-in in
	-- fights), right-click your menu, left-click nothing. Shown and hidden by
	-- the game's secure code, so in fights too: a select-yourself click (our
	-- button's, wrapped) puts it up or away as it does the stand-in, and a real
	-- target puts it away (an attribute driver). Placed, and armed (cineon:
	-- the option on, the stand-in built), out of fights only.
	-- Esc puts it away, as Esc clears the game's target of you ("esc does not
	-- clear the target frame when it is me", user 2026-11-20): while the menu
	-- button's up it holds Esc (bound in its secure show, let go in its hide:
	-- in fights too), an Esc click hides it, and its hide takes the stand-in
	-- down. (While it's up Esc closes it first, before any open window.)
	local menu = CreateFrame("Button", "CinematicShoulderSelfTargetMenu", UIParent,
		"SecureActionButtonTemplate, SecureHandlerAttributeTemplate, SecureHandlerShowHideTemplate")
	menu:SetAttribute("_onshow", [[ self:SetBindingClick(true, "ESCAPE", "CinematicShoulderSelfTargetMenu", "Escape") ]])
	menu:SetAttribute("_onhide", [[ self:ClearBindings() ]])
	menu:SetAttribute("unit", "player")
	menu:SetAttribute("*type2", "togglemenu")
	menu:Hide()
	menu:SetAttribute("_onattributechanged", [[
		if name == "state-hastarget" and tostring(value) == "1" then self:Hide() end
	]])
	if _G.RegisterAttributeDriver then _G.RegisterAttributeDriver(menu, "state-hastarget", "[@target,exists] 1; 0") end
	menu:WrapScript(menu, "OnClick", [[
		if button == "Escape" then
			self:Hide()
			return false
		end
	]])
	-- (Your tooltip on hovering it, where the game puts a unit's, as hovering
	-- the game's target frame of you shows it: the parts probe, 2026-11-20,
	-- found ours showed none.)
	menu:HookScript("OnEnter", function(self)
		ns.Guard(function()
			local tip = _G.GameTooltip
			if not tip then return end
			if _G.GameTooltip_SetDefaultAnchor then
				_G.GameTooltip_SetDefaultAnchor(tip, self)
			else
				tip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
			end
			tip:SetUnit("player")
			tip:Show()
			-- (And the bars' numbers while the mouse is on it.)
			stand.hover = true
			if stand.Values then stand.Values() end
		end)
	end)
	menu:HookScript("OnLeave", function(self)
		local tip = _G.GameTooltip
		if tip and tip:GetOwner() == self then tip:Hide() end
		stand.hover = false
		if stand.Values then ns.Guard(stand.Values) end
	end)
	menu:HookScript("OnHide", function()
		-- (Esc, a real target, or a select again: the stand-in goes with it.)
		if stand.frame and stand.frame:IsShown() then StandDown("its menu button put away (Esc or a target)") end
	end)
	-- (Up on each select, never put away by one: as the frame, above.)
	local MENU_ON_SELECT = [[
		if button ~= "LeftButton" then return end
		if owner:GetAttribute("cineon") then
			owner:Show()
		end
	]]
	menu:WrapScript(fake, "OnClick", MENU_ON_SELECT)
	local function SyncMenu()
		if InCombatLockdown() then return end
		local on = state.want and Build() ~= nil
		if menu:GetAttribute("cineon") ~= (on or nil) then menu:SetAttribute("cineon", on or nil) end
		-- (Up only with the stand-in: put away with it, once out of a fight.)
		if menu:IsShown() and not (stand.frame and stand.frame:IsShown()) then menu:Hide() end
		if not on then return end
		local left, top, scale = TargetSpot()
		if not left then return end
		local key = ("%.1f %.1f %.3f"):format(left, top, scale)
		if key ~= stand.menuAt then
			stand.menuAt = key
			local k = scale / UIParent:GetEffectiveScale()
			menu:ClearAllPoints()
			menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * k, top * k)
			menu:SetSize(stand.recipe.art.w * k, stand.recipe.art.h * k)
			menu:SetFrameStrata(stand.frame:GetFrameStrata())
			menu:SetFrameLevel(stand.frame:GetFrameLevel() + 20)
		end
	end
	stand.SyncMenu = SyncMenu
	-- Yourself in the party and raid frames too (user 2026-11-20): a left-click
	-- there clears your target as on your player frame. The game's party and
	-- raid frames can't change who they show in a fight (protected: it waits for
	-- the fight's end; the partyself probe, retail follower dungeon, saw none
	-- change), so the frame showing you is set up out of fights, as click-cast
	-- addons set up unit frames: its left-click a /cleartarget macro (the exact
	-- key and the wildcard: the game asks "type1" before "*type1"), its old
	-- ones kept and put back when it's no longer you or the option's not on.
	-- Its click puts the stand-in and its menu button up or away, as ours does.
	-- Right-click and everyone else's frames stay the game's. Not with Clique.
	local PARTY_KEYS = { "*type1", "type1", "*macrotext1", "macrotext1" }
	local armedParty, partyHooked, partyClock = {}, {}, 0
	local function PartyFrames()
		local list = {}
		for i = 1, 5 do list[#list + 1] = _G["CompactPartyFrameMember" .. i] end
		for i = 1, 40 do list[#list + 1] = _G["CompactRaidFrame" .. i] end
		for g = 1, 8 do
			for m = 1, 5 do list[#list + 1] = _G["CompactRaidGroup" .. g .. "Member" .. m] end
		end
		return list
	end
	local function PartyUnit(frame)
		local ok, unit = pcall(frame.GetAttribute, frame, "unit")
		unit = ok and unit or frame.unit
		return type(unit) == "string" and unit or nil
	end
	local function PartyName(frame)
		return frame.GetName and frame:GetName() or "?"
	end
	local function ArmParty(frame)
		local kept = {}
		for _, key in ipairs(PARTY_KEYS) do kept[key] = frame:GetAttribute(key) or false end
		armedParty[frame] = kept
		for _, key in ipairs({ "*type1", "type1" }) do frame:SetAttribute(key, "macro") end
		for _, key in ipairs({ "*macrotext1", "macrotext1" }) do frame:SetAttribute(key, "/cleartarget") end
		pcall(menu.WrapScript, menu, frame, "OnClick", MENU_ON_SELECT)
		if not partyHooked[frame] then
			partyHooked[frame] = true
			frame:HookScript("OnClick", function(self, mouse)
				if armedParty[self] then SelectedYourself(self, mouse) end
			end)
		end
		ns.Log("shoulder", "selecting yourself: party frame covered: " .. PartyName(frame))
	end
	local function DisarmParty(frame)
		for key, value in pairs(armedParty[frame] or {}) do frame:SetAttribute(key, value or nil) end
		pcall(menu.UnwrapScript, menu, frame, "OnClick")
		armedParty[frame] = nil
		ns.Log("shoulder", "selecting yourself: party frame back to the game's: " .. PartyName(frame))
	end
	-- (Out of fights, about once a second: the frames showing you now set up,
	-- any no longer you, or with the option off, put back.)
	local function SyncParty(elapsed)
		partyClock = partyClock + (elapsed or 1)
		if partyClock < 1 or InCombatLockdown() then return end
		partyClock = 0
		local mine = {}
		if state.want and not (IsLoaded and ns.Flag(IsLoaded("Clique"))) then
			for _, frame in ipairs(PartyFrames()) do
				if type(frame) == "table" and frame.IsVisible and ns.Flag(frame:IsVisible()) then
					local unit = PartyUnit(frame)
					if unit and ns.Flag(UnitIsUnit(unit, "player")) then mine[frame] = true end
				end
			end
		end
		for frame in pairs(armedParty) do
			if not mine[frame] then DisarmParty(frame) end
		end
		for frame in pairs(mine) do
			if not armedParty[frame] then ArmParty(frame) end
		end
	end
	stand.SyncParty = SyncParty
	function stand.PartyArmed() return next(armedParty) ~= nil end
	function ns.ShoulderSelfPartyFrames()
		local names = {}
		for frame in pairs(armedParty) do names[#names + 1] = PartyName(frame) end
		table.sort(names)
		return names
	end
	function ns.ShoulderSelfTargetMenu() return menu end
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("PLAYER_LOGIN")
	watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	watcher:RegisterEvent("UPDATE_BINDINGS")
	watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
	watcher:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_TARGET_CHANGED" then
			if UnitExists("target") and not stand.beside then StandDown("you targeted something") end
			ns.Guard(stand.AskPowerRead)
			return ns.Guard(SelfTargeted)
		elseif event == "PLAYER_LOGIN" then
			-- (On key down or up as the game's action buttons are, not both: it'd go twice.)
			fake:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
			-- (The stand-in's menu button as our button: on mouse up only, its
			-- right-click opened no menu, the first selfwhere run 2026-11-20.)
			menu:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
		elseif event == "UPDATE_BINDINGS" then
			-- (Ours fire it too: only yours, a key bound again, counts.)
			if GetTime() - ownChangeAt > 0.5 then state.dirty = true end
			return
		end
		ns.Guard(Sync)
		ns.Guard(stand.SyncMenu)
		ns.Guard(stand.SyncParty, 1)
	end)
	local clock = 0
	ns.FeatureLoop(watcher, ns.Profiled("Shoulder Cam self select", function(_, elapsed)
		clock = clock + elapsed
		if clock < 0.25 then return end
		clock = 0
		Sync()
		stand.Tick()
		stand.SyncMenu()
		stand.SyncParty(0.25)
	end), function()
		return ns.db and ns.db.shoulderCamFakeSelf or state.want or state.rect ~= ""
			or (stand.frame and stand.frame:IsShown())
			-- (Till a party frame set up is put back: off, the loop'd stop first.)
			or stand.PartyArmed()
	end)
	-- (The run and test commands: what it's doing now.)
	function ns.ShoulderFakeSelfState()
		return { want = state.want, why = state.why, keys = state.keys, covered = state.rect ~= "", rect = state.rect,
			passThrough = passThrough, button = fake }
	end
end

-- Turn to your target (shoulderCamTargetTurn, off by default). The game's
-- enemy focus (test_cameraTargetFocusEnemy...) turns the camera toward an
-- enemy you target, but out of combat at fixed strengths it does nothing: it
-- moves only while its strengths are changing, and holds the turn after the
-- target's gone till they come back down (the "enemy" map run, retail dummy,
-- 2026-11-12, Tools/shoulder-test-plan.md). So, as with the talk turn, it's on
-- with them at 0, eased up to the game's own (aim.yaw, aim.pitch) over
-- shoulderCamTalkTime while an enemy's targeted, and down again over
-- a time of its own (shoulderCamTargetBack) once it isn't: a slow turn there and a glide back. In a fight it's
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

-- (A dead one isn't: you target those to loot them, 2026-11-13.)
local function HasEnemy()
	return UnitExists("target") and ns.Flag(UnitCanAttack("player", "target"))
		and not ns.Flag(UnitIsDeadOrGhost("target")) or false
end

-- The game's soft enemy target, held on while the camera's turned (user,
-- 2026-11-16: "yes"). Esc clears your target and the game drops its turn at
-- once, a snap, whatever the strengths (the "soft" run, Forever trial 2:
-- kept full, gone by 0.2 s). With the soft target on that enemy, the turn
-- stays on it after the clear (Forever trial 2: still turned 1.2 s on), and
-- eases back with the strengths (retail tank dummy, same day). Clearing a
-- target can't be held (protected), so this is the only way to a glide.
-- Raised to these only where yours are lower, given back once the glide's
-- done (or a fight turns it back with the target kept: no glide to hold).
-- In those 1.5 s, attacks with no target can go to the soft one.
aim.soft = { SoftTargetEnemy = 3, SoftTargetEnemyArc = 2, SoftTargetEnemyRange = 45 }
-- And the game's outlines off meanwhile (user, 2026-11-17: "yes, try it"):
-- the soft enemy gets an outline on its body, and no setting hides just that
-- one (Forever's outline CVars: only the fade times are per kind), so it's the
-- Graphics menu's Outline Mode, every outline (your target's, mouseover's)
-- gone while held. Set to exactly these, not raised; given back with the rest.
aim.outline = { OutlineEngineMode = 0, RAIDOutlineEngineMode = 0 }
local function SoftHold(yours, on)
	-- SoftTarget CVars are protected in fights: a SetCVar there isn't an
	-- error pcall catches but an ADDON_ACTION_BLOCKED, once a frame (680 in
	-- 8 s, Forever 2026-11-16). Not touched in fights; given back after.
	if InCombatLockdown() then
		if not on and not aim.softSaid then
			for _, set in ipairs({ aim.soft, aim.outline }) do
				for cvar in pairs(set) do
					if yours[cvar] ~= nil then
						aim.softSaid = true
						ns.Log("cvar", "Shoulder Cam: soft target given back once the fight ends")
						break
					end
				end
			end
		end
		return
	end
	for cvar, want in pairs(aim.outline) do
		local now = GetCVar(cvar)
		if now == nil then
			-- (Not on this client.)
		elseif on then
			if not Same(now, want) then
				if yours[cvar] == nil then yours[cvar] = now end
				-- (A graphics setting: timed, for any hitch it costs.)
				local start = debugprofilestop()
				local ok = pcall(SetCVar, cvar, tostring(want))
				ns.Log("cvar", ("Shoulder Cam: %s %s -> %s, no outline on the soft target (%.1f ms)%s"):format(cvar,
					now, want, debugprofilestop() - start, ok and "" or " (refused)"))
			end
		elseif yours[cvar] ~= nil then
			local back = yours[cvar]
			local start = debugprofilestop()
			local ok = pcall(SetCVar, cvar, back)
			local took = debugprofilestop() - start
			if ok and Same(GetCVar(cvar), back) then
				yours[cvar] = nil
				ns.Log("cvar", ("Shoulder Cam: %s back to %s (%.1f ms)"):format(cvar, back, took))
			elseif not aim.softSaid then
				aim.softSaid = true
				ns.Log("cvar", ("Shoulder Cam: %s back to %s refused: tried again"):format(cvar, back))
			end
		end
	end
	for cvar, want in pairs(aim.soft) do
		local now = GetCVar(cvar)
		if now == nil then
			-- (Not on this client.)
		elseif on then
			if (tonumber(now) or 0) < want then
				if yours[cvar] == nil then yours[cvar] = now end
				local ok = pcall(SetCVar, cvar, tostring(want))
				ns.Log("cvar", ("Shoulder Cam: %s %s -> %s, the soft target for the glide back%s"):format(cvar, now,
					want, ok and "" or " (refused)"))
			end
		elseif yours[cvar] ~= nil then
			-- (Refused: it's tried again each frame, out of fights.)
			local back = yours[cvar]
			local ok = pcall(SetCVar, cvar, back)
			if ok and Same(GetCVar(cvar), back) then
				yours[cvar] = nil
				ns.Log("cvar", ("Shoulder Cam: %s back to %s"):format(cvar, back))
			elseif not aim.softSaid then
				aim.softSaid = true
				ns.Log("cvar", ("Shoulder Cam: %s back to %s refused (in a fight %s): tried again"):format(cvar, back,
					tostring(InCombatLockdown())))
			end
		end
	end
	if on then aim.softSaid = nil end
end
-- Turn to your target's Show in row (Frames.lua's rows): where it turns, and
-- whether in fights. Every place and fights ticked to start with (it turned
-- everywhere before); Not in fights, a box till 2026-11-13, is its Combat
-- tick now. Read 4 times a second (rules aren't cheap). Its Always
-- (shoulderCamTargetTurnAlways, on to start with, 2026-11-14) turns it
-- everywhere; the row had no Always column before, so an Always set by its
-- rule (cineShow) wasn't seen, its ticks all off: it never turned.
ns.SHOULDER_TURN_ROW = "shoulder:targetturn"
ns.CINE_SHOW_SETTING[ns.SHOULDER_TURN_ROW] = "shoulderCamTargetTurnAlways"
-- (Out of fights to start with, its Always off: user, 2026-11-15; and not indoors, 2026-11-16.)
ns.RULE_DEFAULTS[ns.SHOULDER_TURN_ROW] = "not indoors and not combat"
for _, list in ipairs({ "combatShow", "worldShow", "cityShow", "bgShow", "instanceShow", "groupShow" }) do
	ns.LIST_DEFAULTS[list][ns.SHOULDER_TURN_ROW] = true
end
local turnRead = { at = -1, on = true }
local function TurnHere()
	local now = GetTime()
	if now - turnRead.at >= 0.25 then
		turnRead.at = now
		if ns.db.shoulderCamTargetTurnNoFight then -- (the old box, once)
			ns.db.combatShow[ns.SHOULDER_TURN_ROW] = false
			ns.db.shoulderCamTargetTurnNoFight = nil
		end
		local ok, on = pcall(ns.RowOnNow, ns.SHOULDER_TURN_ROW, ns.db.shoulderCamTargetTurnAlways, true)
		turnRead.on = not ok or on and true or false
	end
	return turnRead.on
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
	local ok, focus = pcall(ns.MouseFocus)
	if not ok or focus == nil or focus == WorldFrame then return true end
	if not ns.Reachable(focus) then return true end
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
	-- (Its Show in row off here, e.g. Combat unticked in a fight: as if none
	-- were targeted, so it glides back, and turns again after.)
	local enemy = HasEnemy() and TurnHere()
	-- (The turn in and the glide back each their own time since 2026-11-16,
	-- as the NPC turn's: one time for both before.)
	local step = elapsed / math.max(0.1, (enemy and ns.db.shoulderCamTalkTime or ns.db.shoulderCamTargetBack) or 3)
	if enemy ~= aim.had then
		aim.had = enemy
		ns.Log("shoulder", ("target turn: %s (target %s, attackable %s; enemy focus %s, turn %s, tilt %s, share %.2f)"):format(
			enemy and "an enemy targeted, turning to it"
				or HasEnemy() and ("an enemy targeted but its Show in row is off here (%s), gliding back"):format(
					InCombatLockdown() and "in a fight" or "not here")
				or ("no enemy, gliding back (soft target %s)"):format(
					select(2, pcall(function() return tostring(ns.Flag(UnitExists("softenemy"))) end)) or "?"),
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
		-- (Gone back for a fight with the target kept: its click kept for after.)
		if aim.share == 0 and not HasEnemy() then aim.clickX = nil end
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
	-- (The soft target: on while turned to an enemy; kept through the glide
	-- after a clear; off once it's all the way back, or with the target kept
	-- but the turn going back (a fight, its row off): nothing to hold then.)
	-- (Its own box, shoulderCamSoftGlide: off, the soft target's never touched.)
	if enemy and ns.db.shoulderCamSoftGlide then
		aim.softHeld = true
	elseif HasEnemy() or aim.share <= 0 or not ns.db.shoulderCamSoftGlide then
		aim.softHeld = nil
	end
	SoftHold(yours, aim.softHeld)
	SetAimShare(yours, aim.share)
end

-- Every frame while the Shoulder Cam's on.
local function TalkTick(elapsed)
	local yours = ns.db and ns.db.shoulderCamYours
	if not (yours and TalkOn()) or ns.shoulderTestHold or (ns.DialogueUICameraOn and ns.DialogueUICameraOn()) then
		CloseNow("talk turn off")
		return
	end
	-- (The last window closed talk.grace ago: glide back from wherever the turn
	-- is, and it's over once it's all the way back. Dropped to 0 at once
	-- before, a snap: after Accept the game closes the quest itself
	-- (QUEST_FINISHED with the close still held), and 0.6 s on the glide back
	-- was cut off at 0.61 s held (the log, 2026-11-14).)
	if talk.on and talk.closedAt and GetTime() - talk.closedAt >= talk.grace then
		if talk.share <= 0 then
			talk.on, talk.closedAt = false, nil
		elseif not talk.back then
			talk.back, talk.backAt = true, nil
		end
	end
	if not talk.on then
		talk.share, talk.back, talk.fullAt, talk.backAt = 0, false, nil, nil
		talk.quick, talk.heldByCam = false, nil
	else
		-- (A held close with no new window after talk.swapWait: the glide back.)
		if talk.backAt and GetTime() >= talk.backAt then
			talk.back, talk.backAt = true, nil
		end
		local holder = ns.CameraHolder and ns.CameraHolder("talk")
		-- (Walking off with the window open: glide back now, at the quick
		-- pace. The game ends the talk once you're out of reach, and its
		-- 0.2 s snap then has nothing left to undo (user, 2026-11-15: "it
		-- will just instantly snap back"). Stopped with it still open: back
		-- toward them.)
		local ok, away = pcall(function() return GetUnitSpeed("player") > 0 end)
		away = ok and away == true
		if away ~= (talk.walkingOff or false) then
			talk.walkingOff = away
			ns.LogDetail("cvar", away and "Shoulder Cam: talk turn glides back, walking off"
				or "Shoulder Cam: stopped, talk turn back toward them")
		end
		-- (One of our cameras holding the view (the quest or chat camera): the
		-- turn's held where it is till the window closes, then glides back at
		-- NPC turn back takes. Stepped down under it before, so the window
		-- closed with nothing left to turn back (user, 2026-11-16: "Hold till
		-- close").)
		local held = holder ~= nil and holder ~= "you" -- (a plain true/false: nil ~= false logged every frame)
		if held ~= (talk.heldByCam or false) then
			talk.heldByCam = held
			ns.LogDetail("cvar", held and ("Shoulder Cam: talk turn held at %.2f, the %s camera has the view"):format(
				talk.share, tostring(holder)) or "Shoulder Cam: talk turn free again")
		end
		if talk.back or away then
			local time = away and talk.quickTime or TalkOutTime()
			talk.share = math.max(0, talk.share - elapsed / time)
		elseif not held then
			talk.share = math.min(1, talk.share + elapsed / TalkInTime())
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
			else
				talk.share = 0
				GiveBack(yours, talk.enable, talk.yawCVar, talk.pitchCVar)
			end
			-- (The same for the enemy focus: at 0 before it goes on.)
			if AimOn() then
				SetAimShare(yours, aim.share)
				Write(yours, aim.enable, "1")
			else
				aim.share, aim.softHeld = 0, nil
				GiveBack(yours, aim.enable, aim.yawCVar, aim.pitchCVar)
				SoftHold(yours, false)
			end
		end
		poller:Show()
	else
		CloseNow("Shoulder Cam off")
		SyncGameEscape() -- (off: Escape the game's again)
		poller:Hide()
		if yours then
			-- (The soft target and outlines are protected in fights: a SetCVar
			-- there is an ADDON_ACTION_BLOCKED. Kept in yours and given back as
			-- the fight ends, not dropped: the game saves them, so they'd stay
			-- yours no more for good. Audit 2026-11-22.)
			local fight = InCombatLockdown()
			local left = false
			for cvar, value in pairs(yours) do
				if Same(GetCVar(cvar), value) then
					yours[cvar] = nil
				elseif fight and (aim.soft[cvar] ~= nil or aim.outline[cvar] ~= nil) then
					left = true
				else
					ns.Log("cvar", ("Shoulder Cam: %s back to %s"):format(cvar, value))
					SetCVar(cvar, value)
					yours[cvar] = nil
				end
			end
			if left then
				ns.Log("cvar", "Shoulder Cam off in a fight: soft target given back once the fight ends")
				aim.offWaiter = aim.offWaiter or CreateFrame("Frame")
				aim.offWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
				aim.offWaiter:SetScript("OnEvent", function(self)
					self:UnregisterAllEvents()
					if not ShoulderOn() then ns.ApplyShoulderCam() end
				end)
			else
				ns.db.shoulderCamYours = nil
			end
		end
	end
	if UpdateFollow then UpdateFollow() end
end

-- (Picks up pauses, and the page's sliders and ticks, a moment later; the
-- offset follows your zoom every frame in between.)
local waited = 0
-- The welcome window's See it first test (ShowMe.lua's "shoulder"): the
-- Shoulder Cam on for a few seconds whatever its setting, wherever you are:
-- it eases in over your shoulder, swaps sides once (at Swap takes' pace),
-- then eases back out ("demo", a pause) and stops. Nothing saved changes:
-- the side swaps on the demo's own, and with the setting off your camera
-- settings come back after as they do whenever it goes off (a reload in the
-- middle too: shoulderCamYours). Picking it is the one-time question's yes.
local DEMO_IN, DEMO_SWAP_AT, DEMO_OUT_AT = 0.9, 2.2, 5.2 -- seconds from the start
function ns.ShoulderCamDemoBlocked()
	if InCombatLockdown() then return L["Not in a fight: try it once the fight ends."] end
	if not ns.isRetail and ns.IsGamePadOn and ns.IsGamePadOn() then
		return L["Shoulder Cam is paused while the gamepad UI is on: the game keeps your character centered in it."]
	end
	if ns.FeatureYieldedTo and ns.FeatureYieldedTo("shoulderCam") then
		return L["Another addon (DynamicCam) is running a shoulder camera, so the Shoulder Cam stays off."]
	end
end
function ns.ShoulderCamDemo()
	if demo or ns.ShoulderCamDemoBlocked() or not ns.db then return false end
	if ns.ShoulderCamAgree then ns.ShoulderCamAgree() end
	-- (Always the right shoulder first, the default, then the left: user,
	-- 2026-11-15. Your own side's untouched, and back after if it's on.)
	demo = { side = "right", swapTo = "left", began = GetTime() }
	ns.Log("shoulder", "demo: starts (the welcome window's test)")
	ns.ApplyShoulderCam()
	return true
end
function ns.ShoulderCamDemoRunning() return demo ~= nil end
-- (Ended early, Stop: eased out as at its end.)
function ns.StopShoulderCamDemo()
	-- (With the Shoulder Cam on anyway: no glide out and back in, just back
	-- to your side at Swap takes' pace: the first run, 2026-11-15.)
	if demo and ns.Setting("shoulderCam") then
		demo = nil
		ns.Log("shoulder", "demo: done, back to your side")
		ns.ApplyShoulderCam()
		return
	end
	if demo and not demo.ending then
		demo.ending = true
		ns.ApplyShoulderCam()
	end
end
local function DemoTick()
	if not demo then return end
	local at = GetTime() - demo.began
	if not demo.swapped and at >= DEMO_SWAP_AT then
		demo.swapped, demo.side = true, demo.swapTo
	end
	if not demo.ending and at >= DEMO_OUT_AT then
		ns.StopShoulderCamDemo()
		if not demo then return end
	end
	-- (All the way back out, or stuck past its time: done.)
	if demo.ending and (blend <= 0 or at >= DEMO_OUT_AT + 4) then
		demo = nil
		ns.Log("shoulder", "demo: done")
		ns.ApplyShoulderCam()
	end
end
ns.SHOULDER_DEMO_SECONDS = DEMO_OUT_AT + DEMO_IN + 1

ns.SetOnUpdate(poller, function(_, elapsed)
	SyncGameEscape()
	DemoTick()
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

-- The swap shoulders key: a button its key binding clicks, bound on the
-- Shoulder Cam page or in the game's Key Bindings (Bindings.xml, since
-- 2026-11-15). Its name's fixed, as Bindings.xml names it (the dev copy's
-- was CinematicDevShoulderSwapButton before: bound again once there).
ns.OnLanguage(function()
	_G["BINDING_NAME_CLICK CinematicShoulderSwapButton:LeftButton"] = L["Swap shoulders (Shoulder Cam)"]
end)
local swap = CreateFrame("Button", "CinematicShoulderSwapButton", UIParent)
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
ns.ShoulderSwapButton = swap -- (ShoulderCamTest.lua's "today" run presses it)

-- The on/off key (Bindings.xml CINEMATIC_SHOULDERCAM, 2026-11-16): flips the
-- page's Enable switch, as clicking it does (the one-time question included).
local TOGGLE_ACTION = "CINEMATIC_SHOULDERCAM"
ns.OnLanguage(function()
	_G.BINDING_NAME_CINEMATIC_SHOULDERCAM = L["Toggle Shoulder Cam"]
end)
function Cinematic_ToggleShoulderCam() -- luacheck: ignore 111 (the key binding's global)
	local db = ns.db
	if not db or not ns.ShoulderCamUnlocked() then return end
	db.shoulderCam = not db.shoulderCam
	ns.ApplyShoulderCam()
	ns.Print((db.shoulderCam and L["%s on"] or L["%s off"]):format(L["Shoulder Cam"]))
	if ns.RefreshOptions then ns.RefreshOptions() end
end

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
	-- (The swing timers, main hand, off hand and ranged: Edit Mode's, often
	-- chained one under the other, so the first slides the rest.)
	{ key = "shoulderCamFollowSwing", frames = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame",
		"SwingTimerRangedFrame" } },
	{ key = "shoulderCamFollowEssential", frames = { "EssentialCooldownViewer" } },
	{ key = "shoulderCamFollowUtility", frames = { "UtilityCooldownViewer" } },
	{ key = "shoulderCamFollowBuffIcons", frames = { "BuffIconCooldownViewer" } },
	{ key = "shoulderCamFollowBuffBars", frames = { "BuffBarCooldownViewer" } },
	-- (The proc alerts round the middle (Lava Surge's curves...): not protected.)
	{ key = "shoulderCamFollowSpellAlerts", frames = { "SpellActivationOverlayFrame" } },
	-- (The game's loss of control alert, "Feared 1.5 seconds": user, 2026-11-18.)
	{ key = "shoulderCamFollowLossOfControl", frames = { "LossOfControlFrame" } },
	-- (The game's floating combat text about you, "-26", "<3 Combo Points>":
	-- user, 2026-11-18. No frame to move: the game places each message
	-- itself as it climbs, so it's slid as it's placed, below.)
	{ key = "shoulderCamFollowCombatText", frames = {} },
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
-- (align: the PRD lined up with the cast bar, 0-1, eased: on while Frames
-- follow you is, paused too: user, 2026-11-15, "it's switching back" on a mount.)
local followLift = { share = 0, align = 0 }

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

-- Whether a frame's points are still these (as ReadPoints gave them), read
-- without making a table: the follower asks every frame.
local function StillAt(frame, points)
	if not points then return false end
	local ok, count = pcall(frame.GetNumPoints, frame)
	if not ok or count ~= #points then return false end
	for i = 1, count do
		local okPoint, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, i)
		local want = points[i]
		if not okPoint or point ~= want[1] or relativeTo ~= want[2] or relativePoint ~= want[3]
			or type(x) ~= "number" or type(y) ~= "number"
			or math.abs(x - want[4]) > 0.01 or math.abs(y - want[5]) > 0.01 then
			return false
		end
	end
	return true
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

-- A frame's middle across the screen, in UI units from the screen's middle
-- (nil: can't be read). Taken as the game places it (an entry's homeX).
local function CenterX(frame)
	local ok, x = pcall(frame.GetCenter, frame)
	if not ok or type(x) ~= "number" or (issecretvalue and issecretvalue(x)) then return nil end
	return x * frame:GetEffectiveScale() / UIParent:GetEffectiveScale() - UIParent:GetWidth() / 2
end

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
	if not keep then followShift, followLift.share, followLift.align = 0, 0, 0 end
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

local function TargetShift()
	local db = ns.db
	if not (db and ShoulderOn() and db.shoulderCamFrames) then return 0 end
	if YouAreTarget() then return 0 end
	local yards = tonumber(GetCVar("test_cameraOverShoulder")) or 0
	if yards == 0 then return 0 end
	-- (A shift's push past the new offset is for the game's ease, which it
	-- cancels: on screen you hardly move. Read as written, it slid the PRD a
	-- point the other way as you shifted, running: the moving shift run,
	-- 2026-11-14. So the push is left out here, and a moment past its end: the
	-- setting still held it for a frame then, and the PRD hopped 0.3.)
	if GetTime() < pushOver and steadyYards > 0 then
		yards = yards < 0 and -steadyYards or steadyYards
	end
	-- (The camera as it glides, as the offset follows it (SeenZoom): the
	-- zoom's end at once put the PRD where it'd be at zoom 4 while you were
	-- still small at 15, "prdcheck", Forever, 2026-11-13.)
	local distance = math.max(FOLLOW_MIN_ZOOM, SeenZoom())
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

-- Where you are across the screen while the camera's over your shoulder
-- (UIParent units, + right), for Text on You (SelfTextStyle.lua): the
-- frames' slide, without Frames follow you's tick or the turn to a target.
function ns.ShoulderYouShift()
	local db = ns.db
	if not (db and ShoulderOn()) or YouAreTarget() then return 0 end
	local yards = tonumber(GetCVar("test_cameraOverShoulder")) or 0
	if yards == 0 then return 0 end
	if GetTime() < pushOver and steadyYards > 0 then
		yards = yards < 0 and -steadyYards or steadyYards
	end
	local distance = math.max(FOLLOW_MIN_ZOOM, SeenZoom())
	local shift = -yards * ns.ShoulderModelScale() / (distance * ns.ShoulderViewWidth()) * (UIParent:GetWidth() / 2)
		* (db.shoulderCamFramesStrength or 1)
	local most = UIParent:GetWidth() * FOLLOW_MAX
	return math.max(-most, math.min(most, shift))
end

local CAST_BAR_NAMES ={ "PlayerCastingBarFrame", "CastingBarFrame", "GamepadPlayerCastingBarFrame" }
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
	-- (Height: in while over your shoulder, at the slide's pace. Crossing to
	-- the other shoulder the offset's 0 at the middle: still over it then.)
	local db = ns.db
	local swapping = sideNow and math.abs(sideNow) < 1 and blend > 0
	local over = db and ShoulderOn() and db.shoulderCamFrames
		and ((tonumber(GetCVar("test_cameraOverShoulder")) or 0) ~= 0 or swapping) and 1 or 0
	followLift.share = followLift.share + (over - followLift.share) * math.min(1, elapsed * FOLLOW_EASE)
	if math.abs(over - followLift.share) < 0.01 then followLift.share = over end
	local master = db and db.shoulderCamFramesHeight or 0
	PickFollows()
	-- (No longer picked: back on its place.)
	PutBack(FOLLOWS)
	-- The cast bar's own place across (moved by itself, not riding on the
	-- PRD): the PRD lines up under it, wherever the layout has the PRD
	-- across (retail's own layout: 410 UI units to the left, 2026-11-15:
	-- "it should be in line with the cast bar"). Kept while Frames follow
	-- you is on, the camera behind you too (followLift.align).
	local alignTo = db and ShoulderOn() and db.shoulderCamFrames and 1 or 0
	followLift.align = followLift.align + (alignTo - followLift.align) * math.min(1, elapsed * FOLLOW_EASE)
	if math.abs(alignTo - followLift.align) < 0.01 then followLift.align = alignTo end
	local castX
	if FOLLOWS.PlayerCastingBarFrame or FOLLOWS.CastingBarFrame then
		for _, name in ipairs(CAST_BAR_NAMES) do
			local bar = _G[name]
			local barEntry = type(bar) == "table" and followed[bar]
			if barEntry and barEntry.homeX and Mover(bar) then
				castX = barEntry.homeX
				break
			end
		end
	end
	for name, key in pairs(FOLLOWS) do
		local frame = _G[name]
		if type(frame) == "table" and frame.GetPoint then
			local entry = followed[frame]
			-- (Moved by the game since: its new place. Read into a table only then.)
			if not (entry and StillAt(frame, entry.ours)) then
				local now = ReadPoints(frame)
				if now and (not entry or not SamePoints(now, entry.ours)) then
					entry = { points = now, ours = now, shift = 0, lift = 0, homeX = CenterX(frame) }
					followed[frame] = entry
				end
			end
			-- (Riding along with another, or on a plate: only its own height;
			-- none: back on its own place, kept till it can go if protected in a fight.)
			local mover = Mover(frame)
			local own = db and db[key .. "Height"] or 0
			local shift = mover and followShift or 0
			if mover and castX and key == "shoulderCamFollowPRD" and entry and entry.homeX then
				shift = shift + (castX - entry.homeX) * followLift.align
			end
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
	if target == 0 and followShift == 0 and followLift.share == 0 and followLift.align == 0 then
		PutBack()
		if not next(followed) then self:Hide() end
	end
end)

function UpdateFollow()
	if ns.db and ShoulderOn() and ns.db.shoulderCamFrames or next(followed) then
		follower:Show()
	end
end

-- The game's floating combat text (Blizzard_CombatText, loaded when it's
-- turned on): each message is a text on its CombatText frame that the game
-- places again every frame as it climbs, with a secret place in fights (and
-- a secret text: the amount). Each one's SetPoint is followed, and how it's
-- then moved is ns.CombatTextFollow.method:
--   "sum"    put again with the slide added to the game's x, y (not when secret)
--   "adjust" AdjustPointsOffset by the slide (the game sums it)
--   "stand"  hung on a stand-in over the game's frame, slid (hid the text: Forever, 2026-11-18)
--   ("frame" and "table", moving the game's frame or its places, are only tried by /cine debug cttest.)
-- nil: not moved. "adjust" is the one that works (/cine debug cttest,
-- Dev/CombatTextTest.lua, Forever 2026-11-18: every place secret even out of
-- a fight, so "sum" never could; the frame and table ways moved nothing, the
-- texts hang on WorldFrame and there's no COMBAT_TEXT_LOCATIONS).
do
	local hooked, busy = {}, false
	local follow = { method = "adjust", normal = "adjust", stats = {} }
	ns.CombatTextFollow = follow
	function follow.ResetStats()
		follow.stats = { seen = 0, slid = 0, secret = 0, skipped = 0, err = nil, anchor = nil }
	end
	follow.ResetStats()
	local function Offset()
		if follow.testShift then return follow.testShift, 0 end
		local db = ns.db
		if not (db and db.shoulderCamFrames and db.shoulderCamFollowCombatText) or EditModeOpen() then return 0, 0 end
		local lift = ((db.shoulderCamFramesHeight or 0) + (db.shoulderCamFollowCombatTextHeight or 0)) * followLift.share
		return followShift, lift
	end
	local function Secret(v) return issecretvalue and issecretvalue(v) end
	local function AnchorName(to)
		if to == nil then return "none" end
		if to == WorldFrame then return "WorldFrame" end
		if to == UIParent then return "UIParent" end
		if to == _G.CombatText then return "CombatText" end
		local ok, name = pcall(function() return to.GetName and to:GetName() end)
		return ok and name and not Secret(name) and tostring(name) or "other"
	end
	-- (One invisible stand-in per frame the game hangs texts on.)
	local stands = {}
	local function Stand(over)
		if type(over) ~= "table" or not over.GetObjectType then return end
		local stand = stands[over]
		if not stand then
			stand = CreateFrame("Frame", nil, UIParent)
			stand.over = over
			stands[over] = stand
		end
		return stand
	end
	local function Slid(text, point, relativeTo, relativePoint, x, y)
		if busy then return end
		local stats = follow.stats
		stats.seen = stats.seen + 1
		-- (SetPoint(point, x, y): no frame named.)
		if type(relativeTo) == "number" or Secret(relativeTo) then
			relativeTo, relativePoint, x, y = nil, nil, relativeTo, relativePoint
		end
		stats.anchor = AnchorName(relativeTo)
		local secret = Secret(x) or Secret(y)
		if secret then stats.secret = stats.secret + 1 end
		local method = follow.method
		if method ~= "sum" and method ~= "adjust" and method ~= "stand" then return end
		if type(point) ~= "string" then return end
		-- (Never on a secret place: our move taints the text's place, and the
		-- game then compares its secret bottom with the next message's and
		-- errors, "compare local 'lowestMessage'", CombatText.lua:364, Forever
		-- dungeon 2026-11-19. Taint alone is harmless here: no protected call.)
		if secret then
			stats.skipped = stats.skipped + 1
			return
		end
		local shift, lift = Offset()
		if math.abs(shift) < 0.5 and math.abs(lift) < 0.5 then return end
		local scale = UIParent:GetEffectiveScale() / math.max(0.01, text:GetEffectiveScale())
		local ok, err = true, nil
		busy = true
		if method == "sum" then
			if secret or type(x) ~= "number" or type(y) ~= "number" then
				stats.skipped = stats.skipped + 1
				busy = false
				return
			end
			ok, err = pcall(text.SetPoint, text, point, relativeTo or text:GetParent(), relativePoint or point,
				x + shift * scale, y + lift * scale)
		elseif method == "adjust" then
			ok, err = pcall(text.AdjustPointsOffset, text, shift * scale, lift * scale)
		else
			local stand = Stand(relativeTo or text:GetParent())
			if stand then
				stand:ClearAllPoints()
				stand:SetPoint("TOPLEFT", stand.over, "TOPLEFT", shift, lift)
				stand:SetPoint("BOTTOMRIGHT", stand.over, "BOTTOMRIGHT", shift, lift)
				ok, err = pcall(text.SetPoint, text, point, stand, relativePoint or point, x, y)
			end
		end
		busy = false
		stats.slid = stats.slid + 1
		if not ok then stats.err = Secret(err) and "secret" or tostring(err) end
	end
	-- (Every text on it, hooked once; looked at again as it loads and as you
	-- take a hit, for a client that makes more as they're needed.)
	function follow.HookTexts()
		local frame = _G.CombatText
		if type(frame) ~= "table" or not frame.GetRegions then return 0 end
		local count = 0
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetObjectType and region:GetObjectType() == "FontString" then
				count = count + 1
				if not hooked[region] then
					hooked[region] = true
					hooksecurefunc(region, "SetPoint", Slid)
				end
			end
		end
		return count
	end
	function follow.Hooked(region) return hooked[region] or false end
	local watch = CreateFrame("Frame")
	watch:RegisterEvent("ADDON_LOADED")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:RegisterUnitEvent("UNIT_COMBAT", "player")
	watch:SetScript("OnEvent", function() ns.Guard(follow.HookTexts) end)
end

-- For /cine debug shoulder.
function ns.GetShoulderCamDebug()
	local db = ns.db
	return {
		setting = db and db.shoulderCam, applied = db and db.shoulderCamYours ~= nil,
		shoulder = GetCVar("test_cameraOverShoulder"), centered = GetCVar("CameraKeepCharacterCentered"),
		side = db and db.shoulderCamSide, spot = db and db.shoulderCamSpot, model = ns.ShoulderModelKey(),
		spotFar = db and db.shoulderCamSpotFar, spotFarAt = db and db.shoulderCamSpotFarAt,
		spotNow = db and ns.ShoulderSpotAt(GetCameraZoom and GetCameraZoom() or 8),
		backAfter = db and db.shoulderCamBackAfter,
		backIn = backIn.from and math.max(0, (tonumber(db and db.shoulderCamBackAfter) or 0) - (GetTime() - backIn.from)) or nil,
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
		talkTurn = db and db.shoulderCamTalkTurn, talking = talk.on, talkShare = talk.share, talkBack = talk.back, talkQuick = talk.quick,
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

-- Logging out or reloading: Keep Character Centered and the motion sickness
-- option go back to yours as the game saves them, and come off again as the
-- next session starts (the offset's written fresh each session anyway). So
-- they're never left off by Cinematic not loading again (disabled,
-- uninstalled, a crash before then aside). yours keeps them meanwhile.
local ACCESSIBILITY = { "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement" }
local function GiveBackForLogout()
	local yours = ns.db and ns.db.shoulderCamYours
	if not yours then return end
	for _, cvar in ipairs(ACCESSIBILITY) do
		if yours[cvar] ~= nil and not Same(GetCVar(cvar), yours[cvar]) then
			SetCVar(cvar, yours[cvar])
		end
	end
	-- (The soft target too: a logout mid-glide mustn't keep it on.)
	for _, set in ipairs({ aim.soft, aim.outline }) do
		for cvar in pairs(set) do
			-- (Refused, in a fight: kept, given back at the next login's
			-- ApplyShoulderCam rather than dropped. Audit 2026-11-22.)
			if yours[cvar] ~= nil and not InCombatLockdown() and pcall(SetCVar, cvar, yours[cvar])
				and Same(GetCVar(cvar), yours[cvar]) then
				yours[cvar] = nil
			end
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
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
	if event == "PLAYER_LOGOUT" then
		GiveBackForLogout()
		return
	end
	if TALK_EVENT[event] == "open" then
		local living, why = TalkingToLiving()
		if not living then
			ns.LogDetail("cvar", ("Shoulder Cam: no talk turn (%s: %s)"):format(event, tostring(why)))
			return
		end
		if not talk.on then ns.LogDetail("cvar", ("Shoulder Cam: talk turn starts (%s)"):format(event)) end
		if #closing.held > 0 then
			ns.Log("shoulder", ("talk close: %d held call(s) dropped, %s opened"):format(#closing.held, event))
			closing.held = {}
		end
		-- (A new window: toward them again, from wherever the turn is.)
		talk.on, talk.closedAt, talk.back, talk.fullAt, talk.backAt, talk.quick = true, nil, false, nil, nil, false
	elseif TALK_EVENT[event] == "close" then
		if talk.on and not talk.closedAt then talk.closedAt = GetTime() end
	elseif event == "UNIT_MODEL_CHANGED" then
		ModelSwapped()
		ns.ApplyShoulderCam()
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- (Yourself targeted or not: the pause for it at once, not at the next
		-- poll (the game's own full offset for a moment first), and the frames.)
		if AimOn() then aim.Picked() end
		ns.ApplyShoulderCam()
	else
		if event == "PLAYER_ENTERING_WORLD" then talk.on, talk.closedAt = false, nil end
		ns.ApplyShoulderCam()
	end
end)

function ns.CreateShoulderCamPanel(kit)
	if not ns.ShoulderCamUnlocked() then return end -- (no page: locked, above)
	-- (A check given its own change function saves nothing itself: this saves, then runs it.)
	-- (Saved, then the page refreshed: a control greyed by another one follows
	-- it at once.)
	local function SaveThen(key, fn)
		return function(value)
			ns.GetDB()[key] = value
			fn()
			if ns.RefreshOptions then ns.RefreshOptions() end
		end
	end
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L["Shoulder Cam"])
	title:SetPoint("TOPLEFT", 16, -16)
	local intro = kit.PageIntro(content, title,
		L["The camera sits over your shoulder, with you to one side of the screen."])
	-- An Experimental notice, as Combat Text Style's (not a gate: the page
	-- works as ever), at the user's ask (2026-11-20): the offset is one of the
	-- game's test settings, and the rest (the self-select button, the pauses,
	-- frames that follow you) fills in round it. Skull: the raid marker's.
	local skull = content:CreateTexture(nil, "ARTWORK")
	skull:SetSize(20, 20)
	skull:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)
	skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
	local warnTitle = kit.Label(content, "GameFontNormalLarge", L["Experimental"])
	warnTitle:SetPoint("LEFT", skull, "RIGHT", 6, 0)
	warnTitle:SetTextColor(1, 0.25, 0.2)
	local warnText = kit.Label(content, "GameFontHighlightSmall",
		L["Shoulder Cam uses some experimental Blizzard features, as well as some hacks to fill in the gaps."])
	warnText:SetPoint("TOPLEFT", skull, "BOTTOMLEFT", 0, -6)
	warnText:SetWidth(520)
	warnText:SetJustifyH("LEFT")
	local switch = kit.PageSwitch(content, "shoulderCam", L["Enable Page"],
		L["Moves the camera over your shoulder, using one of Blizzard's experimental camera settings."], warnText, function()
			ns.ApplyShoulderCam()
			-- (No profile offered any more: the camera works on any profile, and
			-- the Follow HUD tab puts the frames that follow you on yours.)
		end)
	local function IfOn() return ns.PageSetting("shoulderCam") end
	-- (Three folder tabs: the camera's settings, built on content as before and
	-- moved onto the first tab (Adopt, below), the frames that follow you, and
	-- which of our cameras it stays on through.)
	-- (A fourth on Forever, which has a gamepad UI: why it's not for that yet.)
	local tabList = {
		{ L["Shoulder Cam"], L["Where the camera sits, when it turns, and when it steps back behind you."] },
		{ L["Follow HUD"], L["Which frames slide with you while the camera is over your shoulder."],
			flip = "shoulderCamFrames" }, -- (a right-click: Frames follow you)
		{ L["Cameras"], L["Which of Cinematic's cameras keep the Shoulder Cam on while they play."] },
	}
	if not ns.isRetail then
		tabList[4] = { L["Gamepad"], L["Why the Shoulder Cam pauses while the gamepad UI is on."] }
	end
	-- (Last: measuring your race, sex and form, ShoulderCalibrate.lua.)
	tabList[#tabList + 1] = { L["Calibrate"], L["Measure where you sit for your race, sex and form, and share it."] }
	local calibrateTab = #tabList
	local tabHosts, _, TabsShown, Adopt = ns.PageTabsBelow(content, switch, tabList, "Shoulder Cam/page", nil, nil, 1)
	local stack = kit.Stack(switch, "check", true)

	local header = stack:Header(content, L["Show in"])
	local lastRow = ns.ShowTable(content, header, {
		opts = { quiet = true, cam = true, anyFight = true }, underHeader = true,
		{ key = ROW_KEY, label = L["Shoulder Cam"], alwaysKey = "shoulderCamAlways",
			alwaysOn = function() return ns.GetDB().shoulderCamAlways end,
			setAlways = function(value) ns.GetDB().shoulderCamAlways = value ns.ApplyShoulderCam() end,
			alwaysTip = L["Over your shoulder everywhere, so the other columns don't matter."],
			apply = ns.ApplyShoulderCam },
	}, L["Shoulder Cam"])
	stack:Continue(lastRow, "label")

	stack:Header(content, L["Shoulder"])
	-- The on/off key (user 2026-11-16), the same binding as the Keybinds page's
	-- row: an inline row, its button in the sliders' column. Never greyed: it's
	-- how the camera comes on.
	local toggleKey = kit.CreateKeybindButton(content, TOGGLE_ACTION, 1)
	toggleKey.inlineName = L["Toggle Shoulder Cam"]
	stack:Add(toggleKey, "dropdown")
	-- (One tick for the side, user 2026-11-15: ticked over the left shoulder.)
	local left = kit.Check(content, "shoulderCamSide", L["Left shoulder"],
		L["Puts the camera over your left shoulder instead of your right."], function(value)
			ns.GetDB().shoulderCamSide = value and "left" or "right"
			ns.ApplyShoulderCam()
		end)
	left.Refresh = function(self) self:SetChecked(ns.GetDB().shoulderCamSide == "left") end
	kit.GreyUnless(stack:Add(left, "check"), IfOn)
	-- (The swap key on the tick's line, user 2026-11-15.)
	local key = kit.CreateKeybindButton(content, SWAP_ACTION, 1)
	key:SetPoint("LEFT", left, "LEFT", 200, 0)
	local spot = stack:Add(kit.Slider(content, "shoulderCamSpot", L["Spot on screen"], 5, 40, 1, "%d%%", 100),
		"slider")
	kit.Tooltip(spot, L["How far from the middle of the screen you sit."])
	kit.GreyUnless(spot, IfOn)
	-- (Scale with zoom, user 2026-11-17: nearer the middle zoomed out, where walls catch the camera.)
	-- (Unset, false: it follows Spot on screen, so one moved there stays as it was zoomed out too.)
	local spotFar = stack:Add(kit.Slider(content, { key = "shoulderCamSpotFar",
		get = function() return ns.db.shoulderCamSpotFar or ns.db.shoulderCamSpot or 0.2 end,
		set = function(value) ns.db.shoulderCamSpotFar = value end }, L["Spot zoomed out"], 0, 40, 1, "%d%%", 100),
		"slider")
	kit.Tooltip(spotFar, L["How far from the middle you sit when zoomed out. Set it lower than Spot on screen to keep the camera from catching on walls, which only happens zoomed out."])
	kit.GreyUnless(spotFar, IfOn)
	local spotFarAt = stack:Add(kit.Slider(content, "shoulderCamSpotFarAt", L["Zoomed out at"], 8, 30, 1,
		L["%d yards"]), "slider")
	kit.Tooltip(spotFarAt, L["The camera distance where you reach Spot zoomed out. Between 5 yards and this distance, you slide from Spot on screen to Spot zoomed out."])
	kit.GreyUnless(spotFarAt, IfOn)
	local swapTime = stack:Add(kit.Slider(content, "shoulderCamSwapTime", L["Swap takes"], 0, 3, 0.1,
		L["%.1f sec"]), "slider")
	kit.Tooltip(swapTime, L["How long the camera takes to swap to your other shoulder."])
	kit.GreyUnless(swapTime, IfOn)
	-- (Above its slider, user 2026-11-20. On retail too since its tests there:
	-- the party frames, the stand-in, its buffs, 2026-11-20.)
	do
		local fakeSelf = stack:Add(kit.Check(content, "shoulderCamFakeSelf", L["Keep the shoulder when selecting yourself"],
			L["Selecting yourself clears your target instead, so the camera stays over your shoulder. Heals and buffs still land on you."]),
			"check")
		kit.GreyUnless(fakeSelf, IfOn)
		-- A red "!" after its name, what it can't do in its tip (as the minimap's
		-- workaround tick, Options.lua): the target frame of you it shows is our
		-- own copy, so it looks like the game's or one of our themes, not
		-- another addon's frames (user 2026-11-20).
		local warn = CreateFrame("Frame", nil, content)
		warn:SetSize(16, 18)
		warn:SetPoint("LEFT", fakeSelf.Text or fakeSelf.text or fakeSelf, "RIGHT", 6, 0)
		local bang = warn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		bang:SetPoint("CENTER")
		bang:SetText("!")
		bang:SetTextColor(1, 0.3, 0.25)
		warn:EnableMouse(true)
		kit.Tooltip(warn, L["Shows our own copy of your target frame, so it matches only the game's look or a Cinematic theme."])
		fakeSelf.warnMark = warn
	end
	local selfTime = stack:Add(kit.Slider(content, "shoulderCamSelfTime", L["Back from targeting yourself"], 0, 3,
		0.1, L["%.1f sec"]), "slider")
	kit.Tooltip(selfTime, L["How long the camera takes to go back over your shoulder after you stop targeting yourself."])
	kit.GreyUnless(selfTime, IfOn)
	local pauseTime = stack:Add(kit.Slider(content, "shoulderCamPauseTime", L["Off and on again takes"], 0, 3,
		0.1, L["%.1f sec"]), "slider")
	kit.Tooltip(pauseTime, L["How long the camera takes to move behind you when the Shoulder Cam pauses, and back."])
	kit.GreyUnless(pauseTime, IfOn)
	-- (A wait before coming back in, user 2026-11-17: straight back on stepping outside was jarring.)
	local backAfter = stack:Add(kit.Slider(content, "shoulderCamBackAfter", L["Back after"], 0, 10, 0.5,
		L["%.1f sec"]), "slider")
	kit.Tooltip(backAfter, L["How long the Shoulder Cam waits to come back over your shoulder after you step outside or get off your mount. Going back in or mounting again during the wait starts it over."])
	kit.GreyUnless(backAfter, IfOn)

	-- Turn to NPCs and Turn to your target: Show in rows, each one's box before
	-- the name (on at all), Combat and the places after (where it turns). (Turn
	-- to NPCs a plain tick till 2026-11-16: user, "turning inside can be a bit much".)
	local turningHeader = stack:Header(content, L["Turning"])
	local function IfTalk() return ns.PageSetting("shoulderCam") and ns.GetDB().shoulderCamTalkTurn end
	local talkRow = ns.ShowTable(content, turningHeader, {
		opts = { anyFight = true }, underHeader = true, layout = ns.GRID_PLACE_COMBAT_EDIT_LAYOUT,
		{ key = ns.SHOULDER_TALK_ROW, label = L["Turn to NPCs you talk to"], showKey = "shoulderCamTalkTurn",
			alwaysKey = "shoulderCamTalkTurnAlways",
			alwaysOn = function() return ns.GetDB().shoulderCamTalkTurnAlways end,
			setAlways = function(value) ns.GetDB().shoulderCamTalkTurnAlways = value talkRead.at = -1 end,
			alwaysTip = L["Turns to who you talk to everywhere, so the other columns don't matter."],
			showTip = L["The camera turns toward the NPC you talk to while their window is open."],
			showChanged = function() if ns.ApplyShoulderCam then ns.ApplyShoulderCam() end end,
			apply = function() talkRead.at = -1 end,
			tip = L["Where the camera turns toward who you talk to."] },
	}, "Shoulder Cam")
	stack:Continue(talkRow, "label")
	-- (Under it, indented: Escape in a talk window, the game's or Cinematic's own, 2026-11-15.)
	local escTarget = stack:Add(kit.Check(content, "shoulderCamEscTarget", L["Clear target on Esc while interacting with an NPC"],
		L["Escape clears your target and closes an NPC's window in one press."]), "check", 16)
	kit.GreyUnless(escTarget, IfTalk)
	-- (Dev copy only, a test: MultiQuestFix.lua, user 2026-11-15.)
	if ns.isDev then
		local multiQuest = stack:Add(kit.Check(content, "shoulderCamMultiQuestFix", L["Multi Quest fix"],
			L["Dev test: at a quest giver with more quests, Accept clears your target first."]), "check", 16)
		kit.GreyUnless(multiQuest, IfTalk)
	end
	-- (The NPC turn's times with it, under its ticks: under Turn to enemy till
	-- 2026-11-16, they read as its own.)
	local talkIn = stack:Add(kit.Slider(content, "shoulderCamTalkIn", L["NPC turn takes"], 0.5, 4, 0.5,
		L["%.1f sec"]), "slider")
	kit.Tooltip(talkIn, L["How long the turn toward who you talk to takes as the window opens."])
	kit.GreyUnless(talkIn, IfTalk)
	local talkOut = stack:Add(kit.Slider(content, "shoulderCamTalkOut", L["NPC turn back takes"], 0.5, 4, 0.5,
		L["%.1f sec"]), "slider")
	kit.Tooltip(talkOut, L["How long the camera takes to glide back over your shoulder after you close the window."])
	kit.GreyUnless(talkOut, IfTalk)
	-- Turn to enemy, under them: its own table, back out at the header's
	-- edge, with no column headings of its own (the NPC row's above say them).
	local turnTop = CreateFrame("Frame", nil, content)
	turnTop:SetSize(1, 1)
	turnTop:SetPoint("LEFT", turningHeader, "LEFT")
	turnTop:SetPoint("TOP", stack.last.stackSpot or stack.last, "BOTTOM", 0, (ns.GRID_KIT.headingHeight or 24) - 4)
	local turnRow = ns.ShowTable(content, turnTop, {
		opts = { anyFight = true }, underHeader = true, noHeadings = true, layout = ns.GRID_PLACE_COMBAT_EDIT_LAYOUT,
		{ key = ns.SHOULDER_TURN_ROW, label = L["Turn to enemy"], showKey = "shoulderCamTargetTurn",
			alwaysKey = "shoulderCamTargetTurnAlways",
			alwaysOn = function() return ns.GetDB().shoulderCamTargetTurnAlways end,
			setAlways = function(value) ns.GetDB().shoulderCamTargetTurnAlways = value turnRead.at = -1 end,
			alwaysTip = L["Turns to your target everywhere, in fights too."],
			showTip = L["The camera turns slowly toward the enemy you target."],
			showChanged = function() if ns.ApplyShoulderCam then ns.ApplyShoulderCam() end end,
			apply = function() turnRead.at = -1 end,
			tip = L["Where the camera turns toward your target."] },
	}, "Shoulder Cam")
	stack:Continue(turnRow, "label")
	local talkTime = stack:Add(kit.Slider(content, "shoulderCamTalkTime", L["Enemy turn takes"], 0.5, 4, 0.5,
		L["%.1f sec"]), "slider")
	kit.Tooltip(talkTime, L["How long the turn toward your target takes."])
	local function IfTurn() return ns.PageSetting("shoulderCam") and ns.GetDB().shoulderCamTargetTurn end
	kit.GreyUnless(talkTime, IfTurn)
	local turnBack = stack:Add(kit.Slider(content, "shoulderCamTargetBack", L["Enemy turn back takes"], 0.5, 4, 0.5,
		L["%.1f sec"]), "slider")
	kit.Tooltip(turnBack, L["How long the camera takes to glide back after you clear your target."])
	kit.GreyUnless(turnBack, IfTurn)
	-- (The soft target trick, SoftHold: its own box so it can be turned off. User, 2026-11-16.)
	local softGlide = stack:Add(kit.Check(content, "shoulderCamSoftGlide", L["Glide back when you clear your target"],
		L["Glides back instead of snapping when you clear your target, briefly using soft enemy targeting."]), "check", 16)
	kit.GreyUnless(softGlide, IfTurn)

	Adopt(switch) -- (all of the above onto the first tab)

	-- The Frames tab: built on its own frame, from its top.
	local frames = tabHosts[2]
	local top = CreateFrame("Frame", nil, frames)
	top:SetSize(1, 1)
	top:SetPoint("TOPLEFT", frames, "TOPLEFT", 0, 1)
	local fstack = kit.Stack(top, "check", true)
	-- (Dev only for now: setting the Follow HUD up on the profile, FollowHud.lua.)
	if ns.BuildFollowHudSetup then ns.BuildFollowHudSetup(frames, fstack, kit) end
	local followCheck = fstack:Add(kit.Check(frames, "shoulderCamFrames", L["Frames follow you"],
		L["The ticked frames slide over to where you are on the screen."], SaveThen("shoulderCamFrames", UpdateFollow)), "check")
	kit.GreyUnless(followCheck, IfOn)
	local function IfFollow() return ns.PageSetting("shoulderCam") and ns.GetDB().shoulderCamFrames end
	-- (Under it, indented: it adds to it, with Turn to enemy on the first tab. Beside it till
	-- 2026-11-15, it read as a choice between the two: user.)
	local turnFollow = kit.Check(frames, "shoulderCamTargetFollow", L["Frames follow the turn"],
		L["Your cast bar and Personal Resource Display slide along as the camera turns to your target."], SaveThen("shoulderCamTargetFollow", UpdateFollow))
	fstack:Add(turnFollow, "check", 16)
	kit.GreyUnless(turnFollow, function()
		local db = ns.GetDB()
		return ns.PageSetting("shoulderCam") and db.shoulderCamTargetTurn and db.shoulderCamFrames
	end)
	local FRAME_TIP = L["Slides with you."]
	local labels = {
		shoulderCamFollowCast = L["Cast bar"],
		shoulderCamFollowPRD = L["Personal Resource Display"],
		shoulderCamFollowSwing = L["Swing timers"],
		shoulderCamFollowEssential = L["Cooldowns: essential"],
		shoulderCamFollowUtility = L["Cooldowns: utility"],
		shoulderCamFollowBuffIcons = L["Tracked buffs: icons"],
		shoulderCamFollowBuffBars = L["Tracked buffs: bars"],
		shoulderCamFollowSpellAlerts = L["Spell alerts"],
		shoulderCamFollowLossOfControl = L["Loss of control"],
		shoulderCamFollowCombatText = L["Floating combat text"],
	}
	local height = fstack:Add(kit.Slider(frames, "shoulderCamFramesHeight", L["Height (all)"], -200, 200, 5, "%+d"),
		"slider")
	kit.Tooltip(height, L["Raises or lowers all the ticked frames while the camera is over your shoulder."])
	kit.GreyUnless(height, IfFollow)
	-- (Its own line under Height (all), each with its name: user, 2026-11-15.)
	local strength = fstack:Add(kit.Slider(frames, "shoulderCamFramesStrength", L["Follow strength"], 0, 200, 5,
		"%d%%", 100), "slider")
	kit.Tooltip(strength, L["How far the frames slide; adjust it if they land short of you or past you."])
	kit.GreyUnless(strength, IfFollow)
	local OWN_TIP = L["This frame's own height, added to Height (all)."]
	-- (Floating combat text: not on WoW Forever, where it can never move: the
	-- game's text has a secret place there, even out of a fight (engine rule
	-- forever.combattext.copy-secret-words). Your text beside you is the Style
	-- hub's Text on You page now. Retail keeps the row, untested there.)
	local function RowShown(key) return ns.isRetail or key ~= "shoulderCamFollowCombatText" end
	ns.ShoulderFollowRowShown = RowShown -- (Tools/offline/selftextpage.lua)
	for _, group in ipairs(FOLLOW_GROUPS) do
		local key = group.key
		if RowShown(key) then
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
	end

	-- Beside each camera's tick: the seconds it takes to go back behind you as
	-- that camera starts, and back over your shoulder as it ends. Empty: the
	-- usual time (shown greyed in it). Greyed while ticked: no pause then.
	local TIME_TIP = L["How many seconds the camera takes to move behind you for this camera. Leave it empty to use %s."]:format(BLEND_TIME)
	local function TimeBox(parent, check, timeKey, allowKey)
		kit.RecordKey(parent, timeKey)
		local box = ns.SkinEditBox(CreateFrame("EditBox", nil, parent, "InputBoxTemplate"))
		box:SetSize(40, 20)
		box:SetAutoFocus(false)
		box:SetMaxLetters(5)
		box:SetJustifyH("RIGHT")
		box:SetPoint("LEFT", check, "LEFT", 250, 0)
		box.settingKey, box.searchLabel = timeKey, L["Transition"]
		local unit = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		unit:SetPoint("LEFT", box, "RIGHT", 4, 0)
		unit:SetText(L["sec"])
		local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		hint:SetPoint("RIGHT", box, "RIGHT", -2, 0)
		hint:SetText(tostring(BLEND_TIME))
		local function Now()
			local seconds = tonumber(ns.GetDB()[timeKey])
			return seconds and tostring(seconds) or ""
		end
		local function Save(self)
			local typed = self:GetText():match("^%s*(.-)%s*$")
			local seconds = tonumber(typed)
			if typed == "" then
				ns.GetDB()[timeKey] = false
			elseif seconds and seconds >= 0 then
				ns.GetDB()[timeKey] = math.min(30, seconds)
			end
			self:SetText(Now())
		end
		box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
		box:SetScript("OnEscapePressed", function(self)
			self.cancelled = true
			self:ClearFocus()
		end)
		box:SetScript("OnEditFocusLost", function(self)
			if self.cancelled then
				self.cancelled = nil
				self:SetText(Now())
			else
				Save(self)
			end
		end)
		box:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
		local setEnabled = box.SetEnabled
		function box.SetEnabled(self, enabled)
			if setEnabled then setEnabled(self, enabled) end
			local alpha = enabled and 1 or 0.5
			self:SetAlpha(alpha)
			unit:SetAlpha(alpha)
		end
		box.Refresh = function(self)
			if not self:HasFocus() then self:SetText(Now()) end
		end
		kit.Tooltip(box, TIME_TIP)
		kit.AddControl(box)
		kit.GreyUnless(box, function(db) return IfOn() and not db[allowKey] end)
		return box
	end

	-- The Cameras tab: a tick each for the cameras it stays on through (ALLOW_OF).
	local cams = tabHosts[3]
	local camTop = CreateFrame("Frame", nil, cams)
	camTop:SetSize(1, 1)
	camTop:SetPoint("TOPLEFT", cams, "TOPLEFT", 0, 1)
	local cstack = kit.Stack(camTop, "check", true)
	local allowHead = cstack:Header(cams, L["Allow the Shoulder Cam"])
	cstack:Note(cams, L["When unticked, the camera moves behind you while that camera plays and comes back over your " ..
		"shoulder when it ends. When ticked, it stays over your shoulder and you keep your spot on the " ..
		"screen as the camera turns around you."],
		440)
	local ALLOW_TIP = L["Keeps the camera over your shoulder while this camera plays."]
	local timeHead
	for _, row in ipairs({
		{ "shoulderCamAllowVista", L["Vista camera"] },
		{ "shoulderCamAllowFish", L["Fish camera"] },
		{ "shoulderCamAllowCozy", L["Cozy camera"] },
		{ "shoulderCamAllowAFK", L["AFK camera"] },
		{ "shoulderCamAllowTele", L["Tele camera"], L["Your Hearthstone and teleports."] },
		{ "shoulderCamAllowFlight", L["Flight camera"], L["Flight paths and their fly-bys."] },
		{ "shoulderCamAllowDeath", L["Death camera"], L["While you're dead, until you release."] },
		{ "shoulderCamAllowWalk", L["Walk camera"] },
		{ "shoulderCamAllowRun", L["Auto-run camera"] },
		{ "shoulderCamAllowQuest", L["Quest camera"], L["While you talk to a quest giver."] },
		{ "shoulderCamAllowChat", L["Chat camera"] },
		{ "shoulderCamAllowYours", L["Your own cameras"], L["Your scripts and shots, and cameras started from " ..
			"the camera wheel or a key."] },
	}) do
		local key = row[1]
		local check = kit.Check(cams, key, row[2], row[3] and (ALLOW_TIP .. " " .. row[3]) or ALLOW_TIP,
			SaveThen(key, ns.ApplyShoulderCam))
		kit.GreyUnless(cstack:Add(check, "check"), IfOn)
		local box = TimeBox(cams, check, (key:gsub("Allow", "Time")), key)
		if not timeHead then -- (the column's name, over its first box)
			timeHead = kit.Label(cams, "GameFontNormal", L["Transition"])
			-- (Level with the section's header: the note's between it and the rows.)
			timeHead:SetPoint("TOP", allowHead, "TOP", 0, 0)
			timeHead:SetPoint("LEFT", box, "LEFT", -4, 0)
		end
	end

	-- The Gamepad tab (Forever): not supported at the moment. The game keeps
	-- your character centered while its gamepad UI is on, so the Shoulder Cam
	-- pauses then (PauseReason, "gamepad").
	if ns.BuildShoulderCalibrateTab then ns.BuildShoulderCalibrateTab(tabHosts[calibrateTab], kit) end

	if tabHosts[4] and calibrateTab ~= 4 then
		local pad = tabHosts[4]
		local padTop = CreateFrame("Frame", nil, pad)
		padTop:SetSize(1, 1)
		padTop:SetPoint("TOPLEFT", pad, "TOPLEFT", 0, 1)
		local pstack = kit.Stack(padTop, "check", true)
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
end) -- (ns.Module "cameras")
