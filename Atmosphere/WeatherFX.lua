-- Weather on the screen (2026-11-23, the Weather page): Frost creeping in on
-- the screen's edges, Rain on the lens (drops and trails), Lightning flashes
-- with thunder, and Heavier weather (the game's own rain and snow thicker,
-- weatherDensity). Each its Show in row (Core.lua's effectWanted frost,
-- rainlens, lightning, density: rules snow, rain, storm, weather to start
-- with, Core.lua's RULE_DEFAULTS) and its strength, 0 to start with: nothing
-- shows till you set one. Our own textures (Media/make_frost.py,
-- make_rain.py): the game's screen effects' files are retail's only.
local ADDON_NAME, ns = ...
ns.Module("atmosphere", function() -- (only with Atmosphere loaded, Modules.lua)

local TEX = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\"
local FROST_IN, FROST_OUT = 12, 5   -- seconds: frost creeping in, melting away
local RAIN_IN, RAIN_OUT = 2, 5      -- ...drops gathering, drying
local DROPS_MOVE = { 3, 7 }         -- seconds between the drops' shuffles
local DROPS_SWAP = 0.6              -- seconds a shuffle fades over
local STREAK_SPEED = 0.06           -- trails' textures a second, sliding down
local DROPS_TILE = 420              -- UI units one tile of drops covers (512 pixels: a little under)
local STREAK_TILE_W, STREAK_TILE_H = 200, 420 -- ...one tile of trails (256 x 512)
local FLASH_EVERY = { 7, 22 }       -- seconds between flashes in a storm
local PREVIEW_FLASH = 2.5           -- ...while previewing
local THUNDER_AFTER = { 0.6, 2.8 }  -- seconds from a flash to its thunder
local PREVIEW_STRENGTH = 0.5        -- a preview at Off shows this much
-- What each effect's strength and switch are (its row sets the switch).
local KEYS = {
	frost = { strength = "weatherFrostStrength", switch = "weatherFrost" },
	rainlens = { strength = "weatherRainLensStrength", switch = "weatherRainLens" },
	lightning = { strength = "weatherLightningStrength", switch = "weatherLightning" },
	density = { strength = "weatherDensityLevel", switch = "weatherDensityOn" },
}
ns.WEATHER_FX_KEYS = KEYS
-- The game's thunder (sound file ids, from Wowhead's sound pages,
-- 2026-11-23): distant rumbles first (FX_Skybox_DistantThunder_01-05, Mists
-- of Pandaria on: retail's), then the Blasted Lands' sky lightning (its
-- three, on every client). One the game says won't play is left out after.
ns.THUNDER_SOUNDS = ns.THUNDER_SOUNDS or { 656081, 656083, 656085, 656087, 656089, 567124, 567019, 566684 }
local thunderMissing = {}

-- Over the world, beside the tint and haze, under the letterbox and the UI.
local frame = CreateFrame("Frame", "CinematicWeatherFX", UIParent)
ns.CoverWorld(frame)
frame:SetFrameStrata("BACKGROUND")
frame:SetFrameLevel(1)
frame:EnableMouse(false)
ns.AddOverlay(frame)
-- (Always shown: its textures hide themselves. A hidden frame's update never
-- runs, and hidden till something drew, nothing ever did: in game, run 1.)

local frost = frame:CreateTexture(nil, "ARTWORK", nil, 2)
frost:SetAllPoints()
local drops = frame:CreateTexture(nil, "ARTWORK", nil, 3)
drops:SetAllPoints()
local streaks = frame:CreateTexture(nil, "ARTWORK", nil, 4)
streaks:SetAllPoints()
streaks:SetBlendMode("ADD")
local flash = frame:CreateTexture(nil, "OVERLAY")
flash:SetAllPoints()
flash:SetColorTexture(0.85, 0.9, 1, 1)
flash:SetBlendMode("ADD")
flash:SetAlpha(0)
-- (Each hidden till its update draws it: the frame's always shown, and its
-- update runs only while one's wanted, so a texture left as made, shown at
-- full, covered the screen from login with every strength 0, the user
-- 2026-11-23, even after Reset Settings.)
frost:Hide()
drops:Hide()
streaks:Hide()
flash:Hide()
ns.weatherFxTextures = { frost = frost, drops = drops, streaks = streaks, flash = flash } -- (for the checks)
-- (Whether the game found each file: /cine debug atmosphere checks them.)
ns.weatherFxLoaded = {
	frost = frost:SetTexture(TEX .. "Frost"),
	drops = drops:SetTexture(TEX .. "RainDrops", "REPEAT", "REPEAT"),
	streaks = streaks:SetTexture(TEX .. "RainStreaks", "REPEAT", "REPEAT"),
}

local level = { frost = 0, rainlens = 0 }
local preview = { kind = nil, untilT = 0 }
local dropsAt, dropsNext, dropsFade = 0, 0, 1
local du, dv = 0, 0
local streakV = 0
local flashAt, nextFlash, thunderAt = -math.huge, nil, nil
-- (What was drawn, for /cine debug atmosphere and the offline check.)
local drawn = { frost = 0, drops = 0, streaks = 0, flash = 0, density = nil }
ns.weatherFxDrawn = drawn

local function Approach(v, target, elapsed, seconds)
	local step = seconds > 0 and elapsed / seconds or 1
	if v < target then return math.min(target, v + step) end
	return math.max(target, v - step)
end

local function Previewing(kind)
	return preview.kind == kind and GetTime() < preview.untilT
end

-- An effect's strength now (0-1; density: its level 0-3), and whether it's
-- wanted: its row (or a preview), the page and Visual Effects on.
local function Strength(kind)
	local db = ns.db or {}
	-- (Stopped for the session: none, as the rest of Cinematic. The rows'
	-- last answers stay as asked, and drew and thundered on, the density
	-- held again. Audit 2026-11-25, C16.)
	if ns.IsSuspended() then return 0, false end
	local value = tonumber(db[KEYS[kind].strength]) or 0
	if Previewing(kind) then return value > 0 and value or (kind == "density" and 3 or PREVIEW_STRENGTH), true end
	if not db.enabled or db.visualEffects == false or db.weatherPage == false or db[KEYS[kind].switch] == false then
		return 0, false
	end
	local wanted = ns.effectWanted and ns.effectWanted[kind]
	return value, wanted and value > 0 or false
end

-- The thunder after a flash: a distant rumble if this client has them, else
-- the Blasted Lands' (each tried in turn: the first that plays).
local function Thunder()
	local list, tried = ns.THUNDER_SOUNDS, 0
	local distant = {}
	for i = 1, 5 do if list[i] and not thunderMissing[list[i]] then distant[#distant + 1] = list[i] end end
	local near = {}
	for i = 6, #list do if not thunderMissing[list[i]] then near[#near + 1] = list[i] end end
	for _, pool in ipairs({ distant, near }) do
		while #pool > 0 and tried < 4 do
			tried = tried + 1
			local index = math.random(#pool)
			local file = pool[index]
			local ok, willPlay = pcall(PlaySoundFile, file, "Ambience")
			ns.thunderPlayed = { file = file, ok = ok, willPlay = ok and willPlay or false, at = GetTime() }
			if ok and willPlay then return end
			thunderMissing[file] = true
			table.remove(pool, index)
		end
	end
end

local densitySet = ns.CVarSet("Heavier weather",
	"The Weather page's Heavier weather: the game's rain and snow thicker while its row is on",
	{ values = { weatherDensity = "3" } })

local function OnUpdate(_, elapsed)
	local now = GetTime()
	if preview.kind and now >= preview.untilT then preview.kind = nil end
	-- Frost: creeps in slowly, melts a little faster.
	local fs, fw = Strength("frost")
	level.frost = Approach(level.frost, fw and 1 or 0, elapsed,
		Previewing("frost") and 0.4 or (fw and FROST_IN or FROST_OUT))
	drawn.frost = level.frost * fs
	frost:SetAlpha(drawn.frost)
	frost:SetShown(drawn.frost > 0)
	-- Rain on the lens: drops shuffled now and then (fading out and back in
	-- elsewhere), trails sliding down.
	local rs, rw = Strength("rainlens")
	level.rainlens = Approach(level.rainlens, rw and 1 or 0, elapsed,
		Previewing("rainlens") and 0.3 or (rw and RAIN_IN or RAIN_OUT))
	if level.rainlens > 0 then
		if now >= dropsNext then
			dropsAt, dropsNext = now, now + DROPS_MOVE[1] + math.random() * (DROPS_MOVE[2] - DROPS_MOVE[1])
		end
		local t = (now - dropsAt) / DROPS_SWAP
		if t < 1 then
			dropsFade = math.abs(1 - 2 * t) -- (out, then in at the new spot)
			if t >= 0.5 and not frame.dropsMoved then
				du, dv, frame.dropsMoved = math.random(), math.random(), true
			end
		else
			dropsFade, frame.dropsMoved = 1, false
		end
		-- (Tiled at about their own size, in UI units: stretched to the screen,
		-- one trail ran its whole height, a thick glowing bar, 2026-11-23.)
		local w, h = frame:GetSize()
		w, h = math.max(w, 1), math.max(h, 1)
		drops:SetTexCoord(du, du + w / DROPS_TILE, dv, dv + h / DROPS_TILE)
		streakV = (streakV - elapsed * STREAK_SPEED) % 1
		streaks:SetTexCoord(0, w / STREAK_TILE_W, streakV, streakV + h / STREAK_TILE_H)
	end
	drawn.drops = level.rainlens * rs * dropsFade
	drawn.streaks = level.rainlens * rs * 0.45
	drops:SetAlpha(drawn.drops)
	streaks:SetAlpha(drawn.streaks)
	drops:SetShown(drawn.drops > 0)
	streaks:SetShown(drawn.streaks > 0)
	-- Lightning: a flash now and then (a quick double strike, then fading),
	-- its thunder a moment after.
	local ls, lw = Strength("lightning")
	if lw then
		if not nextFlash then
			nextFlash = now + (Previewing("lightning") and 0.2
				or FLASH_EVERY[1] + math.random() * (FLASH_EVERY[2] - FLASH_EVERY[1]))
		end
		if now >= nextFlash then
			flashAt, frame.flashStrength = now, ls
			nextFlash = now + (Previewing("lightning") and PREVIEW_FLASH
				or FLASH_EVERY[1] + math.random() * (FLASH_EVERY[2] - FLASH_EVERY[1]))
			thunderAt = now + THUNDER_AFTER[1] + math.random() * (THUNDER_AFTER[2] - THUNDER_AFTER[1])
			ns.lightningFlashes = (ns.lightningFlashes or 0) + 1
		end
	else
		nextFlash = nil
	end
	local since = now - flashAt
	local envelope = 0
	if since < 0.06 then envelope = 1
	elseif since < 0.12 then envelope = 0.3
	elseif since < 0.18 then envelope = 0.9
	elseif since < 0.9 then envelope = 0.9 * (1 - (since - 0.18) / 0.72) end
	-- (At the strength it struck with: a row going off mid-flash lets it fade.)
	drawn.flash = envelope * (frame.flashStrength or 0) * 0.6
	flash:SetAlpha(drawn.flash)
	flash:SetShown(drawn.flash > 0)
	if thunderAt and now >= thunderAt then
		thunderAt = nil
		Thunder()
	end
	-- Heavier weather: the game's own density held while its row is on.
	local dl, dw = Strength("density")
	local want = dw and math.floor(math.max(1, math.min(3, dl)) + 0.5) or nil
	if want and tostring(want) ~= densitySet.values.weatherDensity and densitySet.active then
		ns.ApplyCVarSet(densitySet, false) -- (a new level: let go, held again below)
	end
	if want then densitySet.values.weatherDensity = tostring(want) end
	ns.ApplyCVarSet(densitySet, want ~= nil)
	drawn.density = want
end

-- (Runs while any is wanted, showing or previewing; else no loop at all.)
local function Wanted()
	if preview.kind and GetTime() < preview.untilT then return true end
	if level.frost > 0 or level.rainlens > 0 or flashAt > GetTime() - 1 or densitySet.active then return true end
	-- (Only one that can draw: its row, its strength up, its switch and the
	-- page on. Its row alone ran the loop every frame in any rain at the
	-- default Off, release review 2026-11-23, fix card
	-- 2026-11-23-weather-loop-strength.md.)
	for kind in pairs(KEYS) do
		local _, on = Strength(kind)
		if on then return true end
	end
	return false
end
-- (Its loop turned off for failing: frost, rain and the flash put away, their
-- levels and the preview reset, and the game's weather density let go, so it
-- starts afresh as it's next wanted. Audit 2026-11-25.)
local function Clear()
	level.frost, level.rainlens = 0, 0
	preview.kind, preview.untilT = nil, 0
	flashAt, nextFlash, thunderAt = -math.huge, nil, nil
	drawn.frost, drawn.drops, drawn.streaks, drawn.flash, drawn.density = 0, 0, 0, 0, nil
	frost:Hide()
	drops:Hide()
	streaks:Hide()
	flash:SetAlpha(0)
	flash:Hide()
	if densitySet.active then ns.ApplyCVarSet(densitySet, false) end
end
ns.FeatureLoop(frame, ns.Profiled and ns.Profiled("Weather effects", OnUpdate) or OnUpdate, Wanted, nil, Clear)

-- The Weather page's previews: kind "frost", "rainlens", "lightning" or
-- "density" for seconds (default 3), CineMode or not; again with none stops.
function ns.WeatherFxPreview(kind, seconds)
	preview.kind, preview.untilT = kind, kind and GetTime() + (seconds or 3) or 0
	if kind == "lightning" then nextFlash = nil end
	ns.WakeFeatureLoop(frame)
end
function ns.WeatherFxPreviewing(kind)
	return Previewing(kind)
end
end) -- (ns.Module "atmosphere")
