-- Death Vision (Visions, World): while the death camera runs, the world dims
-- and goes cold and dark edges close in (the death screen), and the Death
-- card shows a moment after (the banner); its page. Out of Atmosphere/Tint.lua
-- (2026-11-21), so it's left out with the rest of Visions (Modules.lua): the
-- tint calls in only while it's here (ns.CreateDeathScreen, ns.UpdateDeathVision,
-- ns.DeathScreenBusy).
local ADDON_NAME, ns = ...
ns.Module("visions", function() -- (the rest of this file: only with Visions loaded, Modules.lua)
local L = ns.L
local T = ns.TintParts -- (the tint's own helpers: Tint.lua)
local Approach, CreateVignette, SetVignette, SetGradient = T.Approach, T.CreateVignette, T.SetVignette, T.SetGradient
local db -- (the saved settings, from login: ns.CreateDeathScreen)

-- Death screen: while the death camera runs, the world goes dim and cold and a
-- heavy vignette closes in. Its own overlay, beside the tint and under the UI
-- (so the release button stays clear). Fades in slowly, clears quickly (or,
-- released to a spirit healer's wave, over the wait).
local DEATH_COLOR = { 0.6, 0.63, 0.75 } -- multiply: dimmer, drained toward grey-blue
local DEATH_VIGNETTE = 0.95             -- edge darkness at full strength
local DEATH_VIGNETTE_START = 0.1        -- fraction of the screen each edge covers as it starts
                                        -- creeping in (at full: deathVignetteSize)
local DEATH_FADE_IN, DEATH_FADE_OUT = 3, 1 -- seconds (the wash; the vignette's creep: deathVignetteTime)
local deathFrame, deathWash, deathEdges
local deathLevel, deathCreep = 0, 0

local function CreateDeathScreen()
	deathFrame = CreateFrame("Frame", nil, UIParent)
	ns.CoverWorld(deathFrame)
	deathFrame:SetFrameStrata("BACKGROUND")
	local tint = T.Frame() -- (nil with Atmosphere left out: the tint's level, 0)
	deathFrame:SetFrameLevel(tint and tint:GetFrameLevel() or 0) -- (under the letterbox, like the tint)
	deathFrame:EnableMouse(false)
	ns.AddOverlay(deathFrame)
	deathWash = deathFrame:CreateTexture(nil, "BACKGROUND")
	deathWash:SetAllPoints()
	deathWash:SetColorTexture(1, 1, 1, 1)
	deathWash:SetBlendMode("MOD")
	deathEdges = CreateVignette(deathFrame)
	deathFrame:Hide()
end

-- level: the wash; creep: the vignette, which darkens and closes in slowly
-- (eased, so it starts gently and settles).
-- The edges drift in and out a little meanwhile, on top of the creep: two
-- slow waves of different lengths, so it never quite repeats. In shares of
-- the screen, at full creep (less as they clear, none once clear).
local DEATH_DRIFT = 0.03
local DEATH_DRIFT_PERIODS = { 7, 11.3 } -- seconds
local deathWashColor = { 1, 1, 1, 1 }

local function ApplyDeathScreen(level, creep)
	local s = level * db.deathScreenStrength
	local c = creep * creep * (3 - 2 * creep)
	local v = c * db.deathScreenStrength
	local t = GetTime() * 2 * math.pi
	local drift = (0.6 * math.sin(t / DEATH_DRIFT_PERIODS[1]) + 0.4 * math.sin(t / DEATH_DRIFT_PERIODS[2]))
		* DEATH_DRIFT * c
	local size = DEATH_VIGNETTE_START + (db.deathVignetteSize - DEATH_VIGNETTE_START) * c + drift
	for i = 1, 3 do
		deathWashColor[i] = 1 - (1 - DEATH_COLOR[i]) * s
	end
	SetGradient(deathWash, "VERTICAL", deathWashColor, deathWashColor)
	SetVignette(deathEdges, size, DEATH_VIGNETTE * v)
	deathFrame:SetShown(level > 0 or creep > 0)
end

-- Seconds until the area spirit healer's next wave resurrects you (a ghost in
-- its circle), or 0.
local function WaveTimeLeft()
	if not (GetAreaSpiritHealerTime and ns.Flag(UnitIsGhost("player"))) then
		return 0
	end
	local ok, left = pcall(function()
		local t = GetAreaSpiritHealerTime()
		return type(t) == "number" and t > 0 and t or 0
	end)
	return ok and left or 0
end

-- Clearing: waiting on a wave, the screen lifts over the wait, landing as you
-- come back; otherwise (a res, a corpse run) quickly.
local function DeathFadeOut(current, wave)
	return wave > 0 and current > 0 and wave / current or DEATH_FADE_OUT
end

-- Released, the vignette stays (closing all the way in, if you released
-- before it had) and lifts slowly, then fast at the end: waiting on a wave,
-- over the wait (fast for its last WAVE_FAST seconds); on a corpse run, as you
-- near your body (fast within CORPSE_FAST yards, gone by CORPSE_NEAR; full
-- where you came back, however far that is). Where your body lies: your own
-- position while dead (saved here), or after a reload the game's corpse
-- marker on the map.
local LIFT_KNEE = 0.8       -- share of the dark still there as the fast part starts
local WAVE_SLOW, WAVE_FAST = 30, 5 -- seconds left: starts lifting, then fast
local WAVE_LAST = 1         -- seconds left: the wave's bringing you back
local WAVE_EASE = 0.5       -- the fast part's curve (see Lift)
local CORPSE_FAST, CORPSE_NEAR = 80, 30 -- yards: fast from here, gone by here
                            -- (about where you can come back to life)
local CORPSE_CHECK = 0.25   -- seconds between checks
local CORPSE_FOLLOW = 1     -- seconds the vignette takes to follow a change as you walk
                            -- (closing in, never faster than deathVignetteTime)
local corpse = { checkedAt = 0 }

-- How much dark is left (0-1) with value (seconds or yards) still to go:
-- full at far, LIFT_KNEE at knee, none at near. ease under 1 keeps more of it
-- through the fast part, gone right at near (the edges shrink and fade
-- together, so a straight line looked gone well before the end: tested).
local function Lift(value, far, knee, near, ease)
	if value >= knee then
		local slow = far > knee and math.min(1, (value - knee) / (far - knee)) or 1
		return LIFT_KNEE + (1 - LIFT_KNEE) * slow
	end
	return LIFT_KNEE * math.max(0, (value - near) / (knee - near)) ^ (ease or 1)
end

local function Number(value)
	if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
		return value
	end
end

local function PlayerPosition()
	local ok, y, x, _, instance = pcall(UnitPosition, "player")
	if ok and Number(y) and Number(x) then
		return x, y, instance
	end
end

-- From the game's corpse marker: both on the map you're on, its size in yards.
local function CorpseDistanceFromMap()
	if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and C_Map and C_Map.GetBestMapForUnit) then
		return nil, "no corpse API"
	end
	local ok, distance = pcall(function()
		local map = C_Map.GetBestMapForUnit("player")
		local body = map and C_DeathInfo.GetCorpseMapPosition(map)
		local me = body and C_Map.GetPlayerMapPosition(map, "player")
		local width, height = C_Map.GetMapWorldSize(map)
		if not (me and Number(body.x) and Number(body.y) and Number(me.x) and Number(me.y)
			and Number(width) and Number(height) and width > 0) then
			return nil
		end
		return math.sqrt(((body.x - me.x) * width) ^ 2 + ((body.y - me.y) * height) ^ 2)
	end)
	return ok and distance or nil, ok and (distance and "map" or "not on this map") or "error"
end

-- Yards to your body, and where that came from; nil if unknown.
local function CorpseDistance()
	local x, y, instance = PlayerPosition()
	if corpse.x and x and instance == corpse.instance then
		return math.sqrt((x - corpse.x) ^ 2 + (y - corpse.y) ^ 2), "saved"
	end
	return CorpseDistanceFromMap()
end

-- Your body's whereabouts unknown (you died in a dungeon, or the game won't
-- say): it's as if it were FAKE_DISTANCE yards off, the vignette lifting
-- evenly (no fast part) with the ground you cover; where your position isn't
-- known either, with time, at a run.
local FAKE_DISTANCE = 1000 -- yards
local FAKE_SPEED = 7       -- yards a second, with no position to go by
local FAKE_JUMP = 30       -- yards in one check: a teleport (the graveyard), not walked

local function FakeCorpseRun()
	local now = GetTime()
	local x, y, instance = PlayerPosition()
	local walked = 0
	if x and corpse.fakeX and instance == corpse.fakeInstance then
		walked = math.sqrt((x - corpse.fakeX) ^ 2 + (y - corpse.fakeY) ^ 2)
		if walked > FAKE_JUMP then walked = 0 end
	elseif not x and corpse.fakeAt then
		walked = (now - corpse.fakeAt) * FAKE_SPEED
	end
	corpse.fakeX, corpse.fakeY, corpse.fakeInstance, corpse.fakeAt = x, y, instance, now
	corpse.walked = (corpse.walked or 0) + walked
	return math.max(0, 1 - corpse.walked / FAKE_DISTANCE)
end

-- The vignette while waiting on a wave (nil: no wave). The game counts the
-- wait in whole seconds, so it's counted down smoothly here from each change
-- of the game's number (read every frame meanwhile, so it's caught at once):
-- read as is, the edges moved in a step each second.
local function WaveLevel(now)
	local wave = WaveTimeLeft()
	if wave <= 0 then
		corpse.waveSeen, corpse.waveEnd = nil, nil
		return nil
	end
	if wave ~= corpse.waveSeen then
		corpse.waveSeen, corpse.waveEnd = wave, now + wave
	end
	-- In its last second, no corpse run as it ends (the wave brings you back).
	-- Before that, a wave gone means you walked out of its circle: the corpse
	-- run takes over (the edges went with it: tested).
	corpse.waited = corpse.waveEnd - now < WAVE_LAST
	return Lift(math.max(0, corpse.waveEnd - now), WAVE_SLOW, WAVE_FAST, 0, WAVE_EASE)
end

-- Keeps your body's position while dead, and the vignette wanted once
-- released (0-1; nil when not a ghost or not known).
local function CorpseRunLevel()
	local ghost = ns.Flag(UnitIsGhost("player"))
	-- (By the clock, not by adding up elapsed: the tint's loop looks only 5
	-- times a second while nothing of it fades, and hands over one frame's
	-- time, so the check came about 12 times late. Audit 2026-11-22.)
	local now = GetTime()
	if now - corpse.checkedAt < CORPSE_CHECK and ghost == corpse.ghost then -- (released: check now)
		if corpse.waveEnd then
			corpse.level = WaveLevel(GetTime()) or corpse.level
		end
		return corpse.level
	end
	corpse.checkedAt, corpse.ghost = now, ghost
	local dead = ns.Flag(UnitIsDead("player"))
	if dead and not ghost then
		corpse.x, corpse.y, corpse.instance = PlayerPosition()
	elseif not ghost then
		corpse.x, corpse.start, corpse.waited, corpse.waveEnd = nil, nil, nil, nil -- alive again
		corpse.walked, corpse.fakeX, corpse.fakeAt = nil, nil, nil
	end
	corpse.level = nil
	-- (The death camera on here, by its own code or as its script.)
	local deathCamOn = not ns.IsCameraOffHere("death")
		or (ns.CameraRowsScripted ~= nil and ns.CameraRowsScripted("death") and not ns.CameraOffBesidesRows("death"))
	if not (ghost and db.enabled and db.deathScreen and deathCamOn) then
		return nil
	end
	local wave = WaveLevel(GetTime())
	if wave then
		corpse.level = wave
	elseif db.deathCorpseRun and not corpse.waited then
		local distance = CorpseDistance()
		if distance then
			-- Full dark as far away as you've been. (The furthest, not the first
			-- reading: just released, the game can still put you at your body
			-- before moving you to the graveyard, which left it clear: tested.)
			corpse.start = math.max(corpse.start or 0, distance)
			corpse.level = Lift(distance, corpse.start, CORPSE_FAST, CORPSE_NEAR)
		else
			corpse.level = FakeCorpseRun()
		end
	end
	return corpse.level
end

-- For /cine debug corpse.
function ns.GetCorpseDebug()
	db = db or ns.GetDB()
	local distance, source = CorpseDistance()
	local mapDistance, mapSource = CorpseDistanceFromMap()
	return {
		distance = distance, source = source, mapDistance = mapDistance, mapSource = mapSource,
		saved = corpse.x ~= nil, start = corpse.start, level = corpse.level, walked = corpse.walked,
		-- The edges as shown now: how far they've crept in (0-1), and the
		-- share of the screen each covers (see ApplyDeathScreen).
		creep = deathCreep, wash = deathLevel,
		edgeSize = DEATH_VIGNETTE_START + (db.deathVignetteSize - DEATH_VIGNETTE_START)
			* deathCreep * deathCreep * (3 - 2 * deathCreep),
		ghost = ns.Flag(UnitIsGhost("player")), wave = WaveTimeLeft(),
		shown = deathFrame ~= nil and deathFrame:IsShown(), -- (the overlay up now)
	}
end

local function UpdateDeathScreen(elapsed)
	if not deathFrame then
		return
	end
	local want = db.enabled and db.deathScreen and ns.DeathCinematicWanted and ns.DeathCinematicWanted()
	local run = CorpseRunLevel()
	-- (Death Vision's Test: as if just dead, until it ends or Stop.)
	local test = ns.deathVisionTest
	if test and GetTime() >= test.endsAt then
		ns.deathVisionTest, test = nil, nil
	end
	if test and db.deathScreen then -- (page off: none, its Test too)
		want, run = true, nil
	end
	local target = want and 1 or 0
	local creepTarget = run or target
	if deathLevel ~= target or deathCreep ~= creepTarget then
		local wave = target == 0 and WaveTimeLeft() or 0
		deathLevel = Approach(deathLevel, target, elapsed,
			target > deathLevel and DEATH_FADE_IN or DeathFadeOut(deathLevel, wave))
		local creepTime
		if creepTarget > deathCreep then
			-- Closing in (after you die, released early, walking away, a new
			-- wave): never faster than the creep after you die.
			creepTime = math.max(db.deathVignetteTime, run and CORPSE_FOLLOW or 0)
		elseif run then
			creepTime = CORPSE_FOLLOW
		else
			creepTime = DeathFadeOut(deathCreep, wave)
		end
		deathCreep = Approach(deathCreep, creepTarget, elapsed, creepTime)
		ApplyDeathScreen(deathLevel, deathCreep)
	elseif deathCreep > 0 then
		ApplyDeathScreen(deathLevel, deathCreep) -- (settled: still drifting)
	end
end

-- The death banner (a nod to Elden Ring): shortly after the death camera
-- starts, the Death event's card (Cards.lua), a Banner to start with: "YOU
-- DIED" in dull red across the middle of the screen on a dark band with soft
-- edges. Or "wasted" (a nod to crime-sandbox films and games): a picture on a
-- flat black band (drawn in Pricedown by Tools/wasted-banner/render.py; the
-- font isn't shipped), sooner and kept up a second longer.
local BANNER_WAIT, WASTED_WAIT = 2, 1.5 -- seconds after the death camera starts
local WASTED_TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\Wasted"
local WASTED_SIZE = 0.1 -- the picture's height, a share of the screen's (4:1 wide)

-- The banner's words: your own with Custom (YOU DIED while left blank).
function ns.DeathBannerWords(style)
	local words = (style or ns.GetDB().deathBannerStyle) == "custom" and ns.GetDB().deathBannerText
	words = type(words) == "string" and words:match("^%s*(.-)%s*$") or ""
	return words ~= "" and words or L["YOU DIED"]
end

-- The Death event's card, in the style picked (style: or this one).
local function DeathCard(style)
	if (style or ns.GetDB().deathBannerStyle) == "wasted" then
		return { name = "", picture = WASTED_TEXTURE, pictureSize = WASTED_SIZE, pictureAspect = 4, holdExtra = 1 }
	end
	return { name = ns.DeathBannerWords(style) }
end
ns.CardSamples = ns.CardSamples or {}
ns.CardSamples.death = function() return DeathCard() end

-- As the death camera starts (not dead at login: nil until the first
-- check), its card a moment later; cut short as soon as it stops.
local deathWas, deathAt
local function UpdateDeathBanner()
	local want = db.enabled and ns.DeathCinematicWanted and ns.DeathCinematicWanted() or false
	if want and deathWas == false then
		local at, style = GetTime(), db.deathBannerStyle
		deathAt = at
		C_Timer.After(style == "wasted" and WASTED_WAIT or BANNER_WAIT, function()
			if deathAt == at and ns.DeathCinematicWanted and ns.DeathCinematicWanted() then
				if ns.Cards then ns.Cards.Fire("death", DeathCard(style)) end -- (none with Visions left out)
			end
		end)
	elseif not want and deathWas then
		deathAt = nil
		if ns.Cards then ns.Cards.Cut("death") end
	end
	deathWas = want
end


-- (The tint's calls: made with it at login, then each of its ticks.)
function ns.CreateDeathScreen()
	db = ns.GetDB()
	CreateDeathScreen()
end
function ns.UpdateDeathVision(elapsed)
	UpdateDeathScreen(elapsed)
	UpdateDeathBanner()
end
-- (Showing or fading: the tint doesn't skip its tick.)
function ns.DeathScreenBusy()
	return deathLevel ~= 0 or deathCreep ~= 0
end

-- Death Vision (Visions, World, 2026-11-19): the death screen's own page, so
-- players can reach it (before, its settings were on the dev copy's Camera
-- Settings page only). Its switch is deathScreen. It shows while the death
-- camera runs, as before.
-- Test: the death screen as if you'd just died, for its creep time and a few
-- seconds more (again: stop).
function ns.TestDeathVision()
	if ns.deathVisionTest then
		ns.deathVisionTest = nil
		return
	end
	db = db or ns.GetDB()
	ns.deathVisionTest = { endsAt = GetTime() + (db.deathVignetteTime or 10) + 5 }
end
function ns.DeathVisionTesting() return ns.deathVisionTest ~= nil end
-- Its overlay (made with the tint at login): the welcome window's demo keeps it
-- out of the whole UI's fade (ShowMe.lua).
function ns.DeathScreenFrame() return deathFrame end

function ns.CreateDeathVisionPanel(kit)
	local canvas, content = kit.CreateScrollPage()
	local title = kit.Label(content, "GameFontNormalLarge", L["Death Vision"])
	title:SetPoint("TOPLEFT", 16, -16)
	local intro = kit.PageIntro(content, title,
		L["The world dims and goes cold while you're dead, and dark edges close in. It shows with the death camera."])
	local switch = kit.PageSwitch(content, "deathScreen", L["Enable Page"],
		L["Turns Death Vision on or off."], intro)
	local stack = kit.Stack(switch, "check")
	local function On() return ns.GetDB() and ns.GetDB().deathScreen end

	local strength = stack:Add(kit.Slider(content, "deathScreenStrength", L["Strength"], 10, 100, 5,
		"%d%%", 100), "slider")
	kit.Tooltip(strength, L["How dim the world gets and how dark the edges get."])
	kit.GreyUnless(strength, On)
	local creep = stack:Add(kit.Slider(content, "deathVignetteTime", L["Edges creep in over"], 1, 30, 1,
		L["%d sec"]), "slider")
	kit.Tooltip(creep, L["How long the dark edges take to close in after you die."])
	kit.GreyUnless(creep, On)
	local reach = stack:Add(kit.Slider(content, "deathVignetteSize", L["Edges reach in"], 15, 50, 5,
		"%d%%", 100), "slider")
	kit.Tooltip(reach, L["How far the dark edges reach in from each side of the screen."])
	kit.GreyUnless(reach, On)
	local corpseRun = stack:Add(kit.Check(content, "deathCorpseRun", L["Edges lift as you near your body"],
		L["The dark edges lift as you walk back to your body."]), "check")
	kit.GreyUnless(corpseRun, On)

	-- Test (Stop while it runs, as the other Visions' tests).
	local row = CreateFrame("Frame", nil, content)
	row:SetSize(300, 26)
	stack:Add(row, "label")
	local button = ns.PanelButton(content)
	button:SetSize(100, 22)
	button:SetPoint("LEFT", row, "LEFT")
	local function Label() button:SetText(ns.DeathVisionTesting() and L["Stop"] or L["Test"]) end
	button:SetScript("OnClick", function()
		ns.TestDeathVision()
		Label()
	end)
	ns.SetOnUpdate(button, Label)
	button.Refresh = Label -- (before GreyUnless, which wraps it)
	kit.Tooltip(button, L["Shows the death screen for a few seconds (close the settings to see it)."])
	kit.GreyUnless(button, On)
	kit.AddControl(button)
	Label()

	-- Related: the death banner (Cards) and the game's own gray screen.
	stack:Header(content, L["Also on death"])
	if ns.CardsLink then -- (none with Visions left out: Modules.lua)
		stack:Add(ns.CardsLink(content, L["The death banner:"], "death"), "label")
	end
	local holder = CreateFrame("Frame", nil, content)
	holder:SetSize(420, 22)
	local label = kit.Label(holder, "GameFontHighlightSmall", L["The game's gray screen:"])
	label:SetPoint("LEFT", 2, 0)
	local open = ns.PanelButton(holder)
	open:SetSize(110, 22)
	open:SetText(L["Graphics Boost"])
	kit.Tooltip(open, L["Opens the Graphics Boost page."])
	open:SetScript("OnClick", function() ns.OpenOptions("Graphics+") end)
	open:SetPoint("LEFT", label, "RIGHT", 10, 0)
	stack:Add(holder, "label")

	canvas:SetScript("OnShow", kit.PageShown(kit.Refresh, content))
	canvas:Hide()
	kit.RegisterSubpage(canvas, "Death Vision")
end
end) -- (ns.Module "visions")
