-- Cinematic's music (the Atmosphere hub's Audio page): the music fades in
-- and out with CineMode, the combat music mute, camera music, the death song,
-- and the music volume's safety and trace. Out of Effects.lua (2026-11-22),
-- so it's left out with the rest of Atmosphere (Modules.lua): its stand-ins
-- there do nothing (ns.RestoreMusicVolume forgets your volume, as with the
-- Audio page off).
local ADDON_NAME, ns = ...
ns.Module("atmosphere", function() -- (the rest of this file: only with Atmosphere loaded, Modules.lua)
local L = ns.L

-- Music fades by ramping the music volume from 0 up to the player's own
-- volume and back. If music was already on, it's left completely alone.
ns.music = { managing = false, level = 0, volume = 1 }

-- The music volume the addon last wrote (nil while it isn't touching it). If
-- the CVar no longer matches, the player changed it in the sound settings, and
-- their change wins over any fade or mute.
local MUSIC_VOLUME_EPSILON = 0.005
local musicWritten
-- When a camera last started the addon's music this session (for music
-- fatigue). Not saved: nil after a login or /reload, so the first camera plays.
local musicStartedAt

-- Music trace (for tracking down the music volume left at 0): every write to
-- the music volume or on/off, with who made it, in the log while detailed
-- logging is on (/cine debug record). The addon's own fade steps are only
-- logged when they reach or leave 0.
local fadeWriting, lastFadeZero = false, nil

local function MusicTrace(text)
	if not ns.LogDetailOn() then
		return
	end
	ns.Log("music", ("%.1f %s | managing %s saved %s written %s"):format(GetTime(), text,
		tostring(ns.music.managing), tostring(ns.db.savedCVars and ns.db.savedCVars.Sound_MusicVolume),
		tostring(musicWritten)))
end
ns.MusicTrace = MusicTrace

-- Which music volumes may be kept as yours (2026-11-20). The game's Music
-- slider moves in 5% steps (other addons' wheels in 1%), so a volume above
-- 0 but under half a percent is never one you picked: it's a fade's step or
-- something else's leftover. A player's remembered volume stuck at
-- 0.0000186 (Forever): written by something outside Cinematic (its own
-- writes are 3 decimals), then taken as theirs while the music code stood
-- aside, put back at every login, and faded in to at every camera, so music
-- was never heard. Nor is the volume Cinematic itself last wrote news of
-- yours (own: nil once anything else writes it). A real 0 is always kept.
-- (On ns: this file's main chunk is at Lua's 200 locals.)
ns.musicKeep = { NEAR_ZERO = 0.005, DEFAULT = 0.4 }
function ns.musicKeep.NearZero(volume)
	return volume ~= nil and volume > 0 and volume < ns.musicKeep.NEAR_ZERO
end

-- Whether volume may be kept as yours (where: for the log; ownCheck: not if
-- Cinematic itself wrote it last). A refusal is logged once per value.
function ns.musicKeep.Ok(volume, where, ownCheck)
	local keep = ns.musicKeep
	if volume == nil then
		return false
	end
	local why = keep.NearZero(volume) and "near 0, no slider's value"
		or ownCheck and keep.own and math.abs(volume - keep.own) <= MUSIC_VOLUME_EPSILON and "Cinematic's own write"
	if not why then
		return true
	end
	if keep.refused ~= volume and why ~= "Cinematic's own write" then
		keep.refused = volume
		ns.Log("music", ("volume %s not kept as yours (%s, %s)"):format(tostring(volume), why, where))
	end
	return false
end

-- Your volume to fade in to or put back when the one found can't be yours:
-- the remembered one, else the game's default.
function ns.musicKeep.Yours()
	local volume = ns.db.musicVolume
	if volume and not ns.musicKeep.NearZero(volume) then
		return volume
	end
	local getDefault = (C_CVar and C_CVar.GetCVarDefault) or GetCVarDefault
	local ok, default = pcall(getDefault, "Sound_MusicVolume")
	default = ok and tonumber(default)
	return default and default > 0 and default or ns.musicKeep.DEFAULT
end

local function TraceMusicWrite(name, value)
	if name ~= "Sound_MusicVolume" and name ~= "Sound_EnableMusic" then
		return
	end
	if fadeWriting then
		if name == "Sound_MusicVolume" then ns.musicKeep.own = tonumber(value) end
		local zero = tonumber(value) == 0
		if zero == lastFadeZero then
			return
		end
		lastFadeZero = zero
		MusicTrace(("fade %s = %s"):format(name, tostring(value)))
		return
	end
	local stack = debugstack(3) or ""
	if name == "Sound_MusicVolume" then
		local ours = stack:find("AddOns/" .. ADDON_NAME .. "/", 1, true) ~= nil
		local volume = tonumber(value)
		ns.musicKeep.own = ours and volume or nil
		-- (Always logged, detailed logging or not: who wrote it.)
		if not ours and ns.musicKeep.NearZero(volume) then
			ns.Log("music", ("music volume set to %s from outside Cinematic (no slider's value) by %s"):format(
				tostring(value), stack:gsub("Interface/AddOns/", ""):gsub("\n", " < "):sub(1, 400)))
		end
	end
	stack = stack:gsub("Interface/AddOns/", ""):gsub("\n", " < ")
	MusicTrace(("SET %s = %s by %s"):format(name, tostring(value), stack:sub(1, 300)))
end

if C_CVar and C_CVar.SetCVar then
	hooksecurefunc(C_CVar, "SetCVar", TraceMusicWrite)
else
	hooksecurefunc("SetCVar", TraceMusicWrite)
end

-- Changes made outside Lua (the game itself) only show up as this event.
local traceFrame = CreateFrame("Frame")
traceFrame:RegisterEvent("CVAR_UPDATE")
traceFrame:SetScript("OnEvent", function(_, _, name, value)
	-- (Not our own fade's steps, as TraceMusicWrite leaves them out: a line
	-- each frame of a fade, in the dev copy's log, 26 KB/s, 2026-11-11.)
	if fadeWriting then return end
	if name == "Sound_MusicVolume" or name == "Sound_EnableMusic" or name == "MUSIC_VOLUME"
		or name == "ENABLE_MUSIC" then
		MusicTrace(("CVAR_UPDATE %s = %s (now %s)"):format(tostring(name), tostring(value),
			tostring(GetCVar("Sound_MusicVolume"))))
	end
end)

-- The game's Music slider moves in 5% steps. With the sound settings open, it
-- snaps each value the addon writes to the nearest step and writes that back
-- (0.524 becomes 0.5, and the first steps of a fade in become 0). That's the
-- slider, not the player: it mustn't be taken as a new volume.
local MUSIC_SLIDER_STEP = 0.05

local function IsSliderSnap(actual, written)
	local steps = actual / MUSIC_SLIDER_STEP
	return math.abs(steps - math.floor(steps + 0.5)) < 0.001
		and math.abs(actual - written) < MUSIC_SLIDER_STEP / 2 + 0.0001
end

local function SetMusicVolume(volume)
	local text = ("%.3f"):format(volume)
	musicWritten = tonumber(text)
	fadeWriting = true
	SetCVar("Sound_MusicVolume", text)
	fadeWriting = false
	-- Snapped by the slider during the write itself: that's the value now.
	local actual = tonumber(GetCVar("Sound_MusicVolume"))
	if actual and math.abs(actual - musicWritten) > MUSIC_VOLUME_EPSILON then
		MusicTrace(("snapped by the slider %.3f -> %.3f"):format(musicWritten, actual))
		musicWritten = actual
	end
end

-- Your music volume (musicVolume) is remembered: it's updated whenever you
-- change it (and, while the addon isn't touching it, follows the setting), and
-- put back at login and /reload, so a volume the addon left turned down, or one
-- something else wrote, can't stick.
function ns.RestoreMusicVolume()
	-- (The Audio page off: Cinematic doesn't handle music, so it has nothing
	-- to put back; forgotten, and kept again from the slider as it goes.)
	if not ns.PageSetting("musicInCinematic") then
		ns.db.musicVolume = nil
		return
	end
	-- Once (2026-11-20): a remembered or game volume stuck near 0 (no slider's
	-- value, see ns.musicKeep) goes back to a real one. A real 0 stays.
	local now = tonumber(GetCVar("Sound_MusicVolume"))
	if not ns.db.musicVolumeNearZeroV1 then
		ns.db.musicVolumeNearZeroV1 = true
		local keep = ns.musicKeep
		if keep.NearZero(ns.db.musicVolume) or (keep.NearZero(now) and ns.db.musicVolume == nil) then
			ns.db.musicVolume = nil
			ns.db.musicVolume = keep.Yours()
			ns.Log("music", ("your music volume was %s (no slider's value): put back to %s"):format(
				tostring(now), tostring(ns.db.musicVolume)))
		end
	end
	local volume = ns.db.musicVolume
	if volume and not (now and math.abs(now - volume) <= MUSIC_VOLUME_EPSILON) then
		MusicTrace(("RESTORE your volume %s -> %.3f"):format(tostring(now), volume))
		SetCVar("Sound_MusicVolume", ("%.3f"):format(volume))
	end
end

-- The player's new music volume, if they changed it since the addon last wrote it.
local function PlayerMusicVolume()
	if not musicWritten then
		return nil
	end
	local actual = tonumber(GetCVar("Sound_MusicVolume"))
	if actual and math.abs(actual - musicWritten) > MUSIC_VOLUME_EPSILON and IsSliderSnap(actual, musicWritten) then
		-- (A snap that came a moment after the write.)
		MusicTrace(("snapped by the slider later %.3f -> %.3f"):format(musicWritten, actual))
		musicWritten = actual
	elseif actual and math.abs(actual - musicWritten) > MUSIC_VOLUME_EPSILON
		and not ns.musicKeep.Ok(actual, "changed while Cinematic had the music") then
		-- (Near 0: no player's. What Cinematic had there goes back.)
		SetMusicVolume(musicWritten)
	elseif actual and math.abs(actual - musicWritten) > MUSIC_VOLUME_EPSILON then
		MusicTrace(("DETECTED player change %.3f -> %.3f"):format(musicWritten, actual))
		if ns.musicDebug then
			ns.Print(("music: you changed the volume %.2f -> %.2f"):format(musicWritten, actual))
		end
		musicWritten = actual
		return actual
	end
end

function ns.StopMusicNow()
	if ns.music.managing then
		ns.RestoreCVar("Sound_EnableMusic")
		ns.RestoreCVar("Sound_MusicVolume")
		ns.music.managing = false
		musicWritten = nil
	end
	ns.music.ending = nil
end

-- Music for standing still (not flagged AFK): Stand still's switch, or with
-- that event set to no camera (its switch greyed out) Go AFK's. (Each as the
-- row it goes by now on the Cameras page has it.)
local function StillMusicOn()
	if not ns.TriggerHasCamera("Still") then
		return ns.TriggerSetting("AFK", "music")
	end
	return ns.TriggerSetting("Still", "music")
end

-- Standing still or AFK, as far as music goes: the AFK camera, the wait for it
-- (standing still with the UI faded) or being flagged AFK. With that one's
-- music off (Cameras page: Go AFK's while flagged AFK, otherwise
-- StillMusicOn's), none of these brings music back from the move-on pause;
-- music already playing carries on.
local function QuietForAFK()
	if ns.Flag(UnitIsAFK("player")) then
		return not ns.TriggerSetting("AFK", "music")
	end
	local mode = ns.CameraMode and ns.CameraMode()
	return (mode == "idle" or (mode == nil and ns.stillSince ~= nil)) and not StillMusicOn()
end

-- Muting music in combat: a 0-1 level that fades down during fights and back
-- up afterwards. Music the addon plays applies it directly; the player's own
-- music gets its volume saved (crash-safe) and ducked, then restored.
local COMBAT_MUSIC_FADE = 1
-- Leaving the camera modes: none running for this long while you move. A
-- shorter gap is one camera handing over to another (vista to cozy...).
local CAM_HANDOVER = 2
-- musicOff: the player's own music switched off by the mute; managedOff: the
-- addon's cinematic music switched off by it. Kept apart so one never undoes
-- the other.
local combatMusic = { level = 1, ducking = false, original = 1, musicOff = false, managedOff = false,
	lastFightAt = -math.huge }
ns.combatMusic = combatMusic -- (Effects.lua's calm timer cuts its last fight short)

-- The volume share left after the combat/place mutes.
local function MusicDuck()
	return combatMusic.level
end

-- Music started within the fatigue time (Audio page) of the last start: a
-- camera starting music, or music coming back as a fresh track after a mute.
local function MusicFatigued()
	return ns.db.musicFatigue > 0 and musicStartedAt ~= nil
		and GetTime() - musicStartedAt < ns.db.musicFatigue * 60
end

-- Once fully faded out, music is switched off rather than left playing at
-- zero volume; switching it back on when the mute ends makes the game start a
-- fresh track (instead of resuming one halfway through) as it fades back in.
-- That's a start like any other, for music fatigue.
local function SetMuteMusicOff(flag, off)
	if off ~= combatMusic[flag] then
		combatMusic[flag] = off
		SetCVar("Sound_EnableMusic", off and 0 or 1)
		if not off then
			musicStartedAt = GetTime()
		end
	end
end

-- playerOverride: the player changed the music volume (or switched music back
-- on) during a mute. That lifts the mute until it clears by itself or a new
-- reason to mute comes up (a fight starting while you walk on, say).
local function UpdateCombatMusic(elapsed, playerOverride)
	-- Muted while fighting (if chosen) or in a place chosen under "Stop music".
	-- Only when the addon handles music at all: with "Play music in cinematic
	-- mode" off, the player's volumes are left alone (any ducking eases back).
	local handlesMusic = ns.Setting("musicInCinematic")
	local now = GetTime()
	if InCombatLockdown() or ns.Flag(UnitAffectingCombat("player")) then
		combatMusic.lastFightAt = now
	end
	-- Stays muted until the Calm Timer (calmTime) has passed since the last
	-- fight ended, so back-to-back fights don't bring the music in and out.
	-- (Stopped while its Show in row, Audio page, is off: in a fight (and
	-- the Calm Timer after) or somewhere, told apart for the player's own music.)
	local musicOff = handlesMusic and not ns.RowOnNow("music", ns.db.musicAlways, true)
	local fighting = musicOff and now - combatMusic.lastFightAt < ns.db.calmTime
	-- Music belongs to the camera modes (flying, RP walking, standing still,
	-- vista, cozy, fishing, the quest cam...): once you leave them all and move
	-- on, it fades out, and the next one starts it again (music fatigue
	-- allowing; back before it's faded right out, it fades back in). Going from one
	-- camera straight to another (vista to cozy) isn't leaving, nor is standing
	-- still (the wait for the AFK camera). It fades at the music fade time.
	-- (Any camera mode lifts the pause: vista, cozy and fish start straight away
	-- from their emote, before standing still would count. Not the AFK camera
	-- with Go AFK's music off: the music stays paused while you're away.)
	local inCam = (ns.CameraMode and ns.CameraMode() and not QuietForAFK())
		or (ns.QuestCamActive and ns.QuestCamActive())
	if inCam then
		combatMusic.camSeenAt = now
	end
	local leftCams = now - (combatMusic.camSeenAt or -math.huge) >= CAM_HANDOVER
	-- Music a camera started (managing) always ends this way: it's the scene's
	-- music, and with CineMode staying on it otherwise played on till logout.
	-- The setting is for your own music.
	if not (handlesMusic and (ns.db.musicPauseWhenMoving or ns.music.managing)) or inCam then
		combatMusic.movingPaused = false
	elseif ns.playerMoving and leftCams then
		combatMusic.movingPaused = true
		combatMusic.pauseFade = true
	end
	local blocked = musicOff and not fighting
	local moving = combatMusic.movingPaused
	-- Music the move-on pause faded right out rests until the fatigue time
	-- (Audio page) since it last started is up: a camera starting meanwhile
	-- doesn't bring it back. Then it comes back as a fresh track.
	-- (Your own music only rests with the setting on: scene music ending by
	-- itself leaves yours alone.)
	if combatMusic.rested and not moving then
		if MusicFatigued() and ns.db.musicPauseWhenMoving then
			moving = true
		else
			combatMusic.rested = false
		end
	end
	if playerOverride then
		combatMusic.override = { fighting = fighting, blocked = blocked, moving = moving }
		combatMusic.level = 1
	end
	local o = combatMusic.override
	if o and (not (fighting or blocked or moving) or (fighting and not o.fighting)
		or (blocked and not o.blocked) or (moving and not o.moving)) then
		combatMusic.override = nil
	end
	if combatMusic.override then
		fighting, blocked, moving = false, false, false
	end
	local otherMute = fighting or blocked
	local target = (otherMute or moving) and 0 or 1
	-- The move-on pause fades at its own speed, out and back in again; the
	-- other mutes use the quick fade.
	if otherMute or combatMusic.level >= 1 then
		combatMusic.pauseFade = false
	end
	local fade = combatMusic.pauseFade and ns.db.musicFadeTime or COMBAT_MUSIC_FADE
	if combatMusic.level ~= target then
		combatMusic.level = ns.Approach(combatMusic.level, target, elapsed, fade)
	end
	local silent = combatMusic.level <= 0
	local duck = MusicDuck()
	if silent and moving then
		combatMusic.rested = true
	end

	if ns.music.managing then
		if silent and moving and not otherMute then
			-- Moved on and faded right out: that's the end of it. Coming back
			-- would be a fresh track, so the next camera starts it anew, if
			-- music fatigue allows (a pause that hasn't faded out just fades
			-- back in). Your music settings go back meanwhile.
			MusicTrace("END managed music: moved on")
			ns.StopMusicNow()
			combatMusic.managedOff = false
			return
		end
		-- The addon's own music: UpdateMusic applies the level to the volume; here
		-- it's just switched off while silent (its on/off is already saved).
		SetMuteMusicOff("managedOff", silent)
		return
	end
	combatMusic.managedOff = false -- the addon's music has stopped; its on/off was restored

	-- The player's own music: save its volume and on/off, then duck it.
	if duck < 1 and (GetCVar("Sound_EnableMusic") == "1" or combatMusic.musicOff) then
		-- (Saved again if the addon's own music put the volume back meanwhile:
		-- ducking on without a saved copy would leave it turned down for good.)
		if not combatMusic.ducking or ns.db.savedCVars.Sound_MusicVolume == nil then
			ns.SaveCVar("Sound_MusicVolume")
			ns.SaveCVar("Sound_EnableMusic")
			combatMusic.original = tonumber(ns.db.savedCVars.Sound_MusicVolume) or 1
			combatMusic.ducking = true
			-- (Your music was already playing: it counts as started, so the
			-- fatigue time covers it too.)
			musicStartedAt = musicStartedAt or GetTime()
		end
		-- Fully faded out, music is switched off and the slider goes back to
		-- your own volume (it only reads lower while actually fading).
		SetMuteMusicOff("musicOff", silent)
		SetMusicVolume(combatMusic.musicOff and combatMusic.original or combatMusic.original * duck)
	elseif combatMusic.ducking and duck >= 1 then
		ns.RestoreCVar("Sound_MusicVolume")
		ns.RestoreCVar("Sound_EnableMusic")
		combatMusic.ducking, combatMusic.musicOff = false, false
		musicWritten = nil
	end
end

function ns.StopCombatMusicNow()
	if combatMusic.ducking then
		ns.RestoreCVar("Sound_MusicVolume")
		ns.RestoreCVar("Sound_EnableMusic")
		combatMusic.ducking = false
		musicWritten = nil
	end
	combatMusic.musicOff, combatMusic.managedOff, combatMusic.override = false, false, nil
	combatMusic.rested = false
	combatMusic.level = 1
end

-- The death song picked for this death (a music file ID), or nil; see SetDeathSong.
local deathSong = { file = nil, playing = false }

-- Music starts with a camera: as one starts with its music switch on, and
-- music fatigue allows. The flight, RP walk and auto-run cameras each have a
-- switch; the cozy, vista and fish cameras follow the event that started them
-- (the Cameras page's Music column, event<key>Music). The AFK camera's
-- is Go AFK's (eventAFKMusic) while flagged AFK, Stand still's (eventStillMusic)
-- when standing still started it; the quest camera's its own event's
-- (eventQuestMusic, or eventQuestGossipMusic talking about a quest). Music
-- already playing just carries on: no camera swaps in a new song.
local MUSIC_CAM = { flight = "Flight", walk = "Walk", run = "Run" } -- (their triggers)
local EVENT_MUSIC_CAMS = { cozy = true, vista = true, fish = true }

local function CameraMusicOn(mode)
	local key = ns.ActiveEvent and ns.ActiveEvent()
	-- (A camera started from its key binding is a trigger you pulled: it
	-- starts music, as it brings CineMode on.)
	if key == "Manual" and mode ~= "flight" and mode ~= "walk" and mode ~= "run" then
		return true
	end
	if mode == "idle" then
		if ns.Flag(UnitIsAFK("player")) then
			return ns.TriggerSetting("AFK", "music") or false
		end
		return StillMusicOn() or false
	end
	if EVENT_MUSIC_CAMS[mode] then
		return key ~= nil and ns.TriggerSetting(key, "music") or false
	end
	if mode == "quest" then
		return ns.TriggerSetting(ns.QuestCamEvent and ns.QuestCamEvent() or "Quest", "music") or false
	end
	return MUSIC_CAM[mode] ~= nil and ns.TriggerSetting(MUSIC_CAM[mode], "music") or false
end

-- The camera running ("flight", "walk"... or "quest"), and whether its start
-- is still waiting to start music (held until CineMode is in, then used up).
local musicCam, musicCamPending = nil, false
-- (The script of each: the same name, but standing still's is the AFK camera's.)
local MODE_SCRIPT = { idle = "afk" }

-- Death song: while the death camera runs, a song of its own plays in place of
-- the zone music, picked at random from deathSongFiles (music file IDs,
-- comma-separated). It needs game music on.
function ns.PickDeathSong()
	local files = {}
	for id in (ns.db.deathSongFiles or ""):gmatch("%d+") do
		files[#files + 1] = tonumber(id)
	end
	return files[math.random(math.max(1, #files))]
end

-- It plays straight away at your music volume, switching game music on if it's
-- off; the music manager (UpdateMusic) stands aside meanwhile, and the music
-- settings it found are put back afterwards.
function ns.SetDeathSong(on)
	-- With CineMode music off (musicInCinematic), music is never switched on:
	-- the song plays only if your game music is on already.
	local musicOn = GetCVar("Sound_EnableMusic") == "1"
	deathSong.file = on and ns.TriggerSetting("Death", "music") and (musicOn or ns.Setting("musicInCinematic"))
		and ns.PickDeathSong() or nil
	if on and ns.DeathTestLog then
		ns.DeathTestLog(("death song: %s (song option %s, game music %s)"):format(
			tostring(deathSong.file), tostring(ns.db.deathSong),
			musicOn and "on" or ns.Setting("musicInCinematic") and "off - switching it on"
				or "off, and CineMode music off: no song"))
	end
end

-- Changing the music volume while it plays is your new volume: the song plays
-- on at it, it's saved as yours straight away, and it's what you're left with
-- afterwards (UpdateMusic then sees the change and lifts any fade or mute).
local function UpdateDeathSong()
	if deathSong.file and not deathSong.playing then
		deathSong.enable, deathSong.volume = GetCVar("Sound_EnableMusic"), GetCVar("Sound_MusicVolume")
		-- Your own volume: the addon may have it faded or ducked right now.
		deathSong.written = tonumber(ns.db.savedCVars.Sound_MusicVolume or deathSong.volume) or 1
		deathSong.changed = false
		SetCVar("Sound_EnableMusic", 1)
		SetCVar("Sound_MusicVolume", ns.db.savedCVars.Sound_MusicVolume or deathSong.volume)
		-- (Counts as playing even if PlayMusic fails, so the settings found
		-- above aren't taken again from the ones just written.)
		deathSong.playing = true
		pcall(PlayMusic, deathSong.file)
		if ns.DeathTestLog then ns.DeathTestLog("death song playing") end
	elseif deathSong.file then
		local actual = tonumber(GetCVar("Sound_MusicVolume"))
		if actual and math.abs(actual - deathSong.written) > MUSIC_VOLUME_EPSILON
			and ns.musicKeep.Ok(actual, "changed during the death song") then
			if ns.musicDebug then
				ns.Print(("music: you changed the volume %.2f -> %.2f (death song)"):format(deathSong.written, actual))
			end
			deathSong.written, deathSong.changed = actual, true
			ns.db.musicVolume = actual
			if ns.db.savedCVars.Sound_MusicVolume ~= nil then
				ns.db.savedCVars.Sound_MusicVolume = tostring(actual)
				combatMusic.original = actual
				if ns.music.managing then
					ns.music.volume = actual
				end
			end
		end
	elseif deathSong.playing then
		deathSong.playing = false
		pcall(StopMusic)
		SetCVar("Sound_EnableMusic", deathSong.enable)
		SetCVar("Sound_MusicVolume", deathSong.changed and ("%.3f"):format(deathSong.written) or deathSong.volume)
	end
end

-- Logging out (or /reload) mid-song: your music settings go back first, so
-- they're saved as you had them.
function ns.StopDeathSongNow()
	deathSong.file = nil
	if deathSong.playing then
		UpdateDeathSong()
	end
end

-- Switching music on or off yourself (the Sound settings' box, the Toggle
-- Music key) while the addon has it switched for now: that's your setting, so
-- it's what comes back afterwards and at logout. (Music the addon switched on
-- for a camera used to go back off at logout even after you ticked it.)
local function MusicSwitchedByPlayer(name)
	if name ~= "Sound_EnableMusic" then
		return
	end
	local stack = debugstack(3) or ""
	if stack:find("AddOns/" .. ADDON_NAME .. "/", 1, true) then
		return -- the addon's own switch
	end
	local value = GetCVar("Sound_EnableMusic")
	MusicTrace(("PLAYER switched music %s"):format(tostring(value)))
	if ns.db and ns.db.savedCVars.Sound_EnableMusic ~= nil then
		ns.db.savedCVars.Sound_EnableMusic = value
	end
	if deathSong.playing then
		deathSong.enable = value
	end
end

if C_CVar and C_CVar.SetCVar then
	hooksecurefunc(C_CVar, "SetCVar", MusicSwitchedByPlayer)
else
	hooksecurefunc("SetCVar", MusicSwitchedByPlayer)
end

-- /cine debug music: a chat line whenever the music state changes. Levels are
-- shown as 0, "part" or 1 so a fade doesn't print every step.
local lastMusicReport
local function Bucket(level)
	return level <= 0 and "0" or level >= 1 and "1" or "part"
end

local function ReportMusic(cinematic)
	if not ns.musicDebug then
		return
	end
	local volume = tonumber(GetCVar("Sound_MusicVolume")) or -1
	local report = ("music: cine %s mode %s | managing %s level %s vol %.2f | mute %s%s%s | cam %s | duck %s | saved %s | game: music %s volume %s"):format(
		tostring(cinematic), tostring(ns.CameraMode and ns.CameraMode()),
		tostring(ns.music.managing), Bucket(ns.music.level), ns.music.volume,
		Bucket(combatMusic.level), combatMusic.movingPaused and " (moved)" or "",
		combatMusic.override and " (overridden)" or "",
		tostring(musicCam), tostring(combatMusic.ducking),
		tostring(ns.db.savedCVars.Sound_MusicVolume), GetCVar("Sound_EnableMusic"),
		volume <= 0 and "0" or volume >= (ns.music.managing and ns.music.volume or combatMusic.original) - 0.01
			and ("%.2f"):format(volume) or "fading")
	if report ~= lastMusicReport then
		lastMusicReport = report
		ns.Print(report)
	end
end

function ns.UpdateMusic(cinematic, elapsed)
	ReportMusic(cinematic)
	-- (Music in cinematic mode off, no music of ours or death song playing,
	-- your own music not muted or ducked or being watched: nothing here can do
	-- anything. Most ticks for Subtle and the like.)
	if not ns.music.managing and not deathSong.file and not deathSong.playing and combatMusic.level >= 1
		and not combatMusic.ducking and not combatMusic.musicOff and not combatMusic.managedOff
		and not combatMusic.override and not combatMusic.rested and not musicWritten
		and not ns.Setting("musicInCinematic") then
		-- (Nothing touching the volume: whatever it's set to is yours, kept
		-- for the login restore. Before, it went stale here, and a 0 kept at
		-- some point came back at every /reload: a player's report 2026-11-17.)
		-- (Not one near 0 or Cinematic's own: see ns.musicKeep.)
		local volume = ns.db.savedCVars.Sound_MusicVolume == nil and tonumber(GetCVar("Sound_MusicVolume"))
		if volume and ns.musicKeep.Ok(volume, "music left alone", true) then
			ns.db.musicVolume = volume
		end
		return
	end
	-- A camera starting (or the quest cam) may start music; switching from one
	-- camera to another counts as a start too.
	local cam = (ns.CameraMode and ns.CameraMode()) or (ns.QuestCamActive and ns.QuestCamActive() and "quest") or nil
	if cam ~= musicCam then
		-- A built-in camera ending with an End music step in your edit of its
		-- When it ends (Scripts page), with it running its own code (the dev
		-- copy's /cine script builtins off): played as its script, the script
		-- runs the step itself.
		if musicCam and ns.BuiltinEndMusicSecs and not (ns.ScriptBuiltInsOn and ns.ScriptBuiltInsOn()) then
			local secs = ns.BuiltinEndMusicSecs(MODE_SCRIPT[musicCam] or musicCam)
			if secs then ns.EndSceneMusic(secs) end
		end
		musicCam = cam
		musicCamPending = cam ~= nil and CameraMusicOn(cam)
	end
	UpdateDeathSong()
	if deathSong.file then
		return -- the death song has the music for now
	end
	local want = cinematic and ns.Setting("musicInCinematic")
	-- The player changed the music volume while the addon was fading or muting
	-- it: that's their new volume, to play at now and come back to afterwards.
	local playerVolume = PlayerMusicVolume()
	if playerVolume then
		ns.db.musicVolume = playerVolume
		ns.db.savedCVars.Sound_MusicVolume = tostring(playerVolume)
		combatMusic.original = playerVolume
		if ns.music.managing then
			ns.music.volume = playerVolume
			if want then
				ns.music.level = 1
			end
		end
	end
	if not playerVolume and ns.db.savedCVars.Sound_MusicVolume == nil then
		-- The addon isn't touching the volume: whatever it's set to is yours
		-- (not one near 0 or Cinematic's own: see ns.musicKeep).
		local volume = tonumber(GetCVar("Sound_MusicVolume"))
		if volume and ns.musicKeep.Ok(volume, "music left alone", true) then
			ns.db.musicVolume = volume
		end
	end
	local switchedOn = (combatMusic.musicOff or combatMusic.managedOff) and GetCVar("Sound_EnableMusic") == "1"
	UpdateCombatMusic(elapsed, playerVolume ~= nil or switchedOn)
	-- Only a camera starts music, and not again within the fatigue time of the
	-- last time one did. Your own music already on is left alone.
	local start = want and musicCamPending and not ns.music.managing
	if want and musicCamPending then
		musicCamPending = false
	end
	if start and GetCVar("Sound_EnableMusic") == "0" and not MusicFatigued() then
		musicStartedAt = GetTime()
		ns.SaveCVar("Sound_EnableMusic")
		ns.SaveCVar("Sound_MusicVolume")
		-- (A volume near 0 found there is no one's: it fades in to yours, and
		-- yours is what's put back afterwards. See ns.musicKeep.)
		local found = tonumber(ns.db.savedCVars.Sound_MusicVolume)
		if not ns.musicKeep.Ok(found, "found as music started") then
			ns.db.savedCVars.Sound_MusicVolume = ("%.3f"):format(ns.musicKeep.Yours())
		end
		ns.music.managing = true
		ns.music.level = 0
		ns.music.volume = tonumber(ns.db.savedCVars.Sound_MusicVolume) or 1
		MusicTrace(("START managed music, your volume %s"):format(tostring(ns.music.volume)))
		-- It fades in to your own volume, so with that at 0 nothing is heard.
		if ns.music.volume <= 0 and not ns.music.warnedSilent then
			ns.music.warnedSilent = true
			ns.Print(L["your game music volume is 0, so cinematic music can't be heard. " ..
				"Turn Music up in the game's Sound settings."])
		end
		SetMusicVolume(0)
		SetCVar("Sound_EnableMusic", 1)
	end
	if not ns.music.managing then
		return
	end

	-- (An End music step, camera scripts: out over its own seconds.)
	local ending = ns.music.ending
	local target = (want and not ending) and 1 or 0
	local duck = MusicDuck()
	if ns.music.level ~= target or duck < 1 or ns.music.combatApplied then
		ns.music.level = ns.Approach(ns.music.level, target, elapsed, ending or ns.db.musicFadeTime)
		-- (Switched off while muted: the slider shows your own volume meanwhile.)
		SetMusicVolume(combatMusic.managedOff and ns.music.volume or ns.music.volume * ns.music.level * duck)
		-- Keep writing until the mute level is back to full.
		ns.music.combatApplied = duck < 1
	end
	if ns.music.level == 0 and (not want or ending) then
		if ending then MusicTrace("END managed music: End music step") end
		ns.StopMusicNow()
	end
end

-- (Asked every tick, 28 times a second: with no volume on its way anywhere and
-- CineMode, the fight and the camera as last time, it looks only 5 times a
-- second. A volume it wrote that differs from
-- the last, a level part way, the death song or /cine debug music keep it at
-- every tick. On ns: this file's main chunk is at Lua's 200 locals.)
ns.musicPace = { elapsed = 0, every = 0.2, run = ns.UpdateMusic }
function ns.UpdateMusic(cinematic, elapsed)
	local pace = ns.musicPace
	local fight = (InCombatLockdown() or ns.Flag(UnitAffectingCombat("player"))) and true or false
	local cam = (ns.CameraMode and ns.CameraMode()) or (ns.QuestCamActive and ns.QuestCamActive() and "quest") or false
	pace.elapsed = pace.elapsed + elapsed
	if not pace.busy and pace.cinematic == cinematic and pace.fight == fight and pace.cam == cam
		and pace.elapsed < pace.every and not deathSong.file and not deathSong.playing and not ns.musicDebug then
		return
	end
	-- (This tick's own time, not the wait's: nothing was fading through it, and
	-- a fade starting now would jump by it.)
	pace.elapsed = 0
	pace.cinematic, pace.fight, pace.cam = cinematic, fight, cam
	local written = musicWritten
	pace.run(cinematic, elapsed)
	pace.busy = musicWritten ~= written or (ns.music.level > 0 and ns.music.level < 1 and ns.music.managing)
		or (combatMusic.level > 0 and combatMusic.level < 1) or ns.music.ending ~= nil
end

-- A camera script's End music step: the music a camera started fades out over
-- secs (0: at once) and ends. Your own music, not started by one, is left alone.
function ns.EndSceneMusic(secs)
	if ns.music.managing then
		ns.music.ending = math.max(0, tonumber(secs) or 0)
	end
end
end)
