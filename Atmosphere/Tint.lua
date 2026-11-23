-- Cinematic screen tint: colour grading and a vignette over the game world
-- while cinematic mode is active. Driven from Core.lua's update loop.
local ADDON_NAME, ns = ...
local L = ns.L

-- What stays loaded with Atmosphere left out (Modules.lua): the vignette and
-- gradient helpers (Death Vision's and Low Health's screens) and the clock
-- the time of day's title and cards read (Visions/TimeOfDay.lua). The rest of
-- the file, the tint itself, only with Atmosphere loaded: it fills in the
-- tint's own frame and clock (its Local time, a previewed hour) below.
local function Approach(current, target, elapsed, duration)
	local step = duration > 0 and elapsed / duration or 1
	if current < target then
		return math.min(target, current + step)
	end
	return math.max(target, current - step)
end

-- Vignettes: a rounded corner piece in each corner (Media/make_vignette.py,
-- flipped by its texcoords) and its outer row stretched along each edge between
-- them, so the darkness eases in with no creases. (Four straight gradients
-- left a bright cross where they met, and a line where each began.)
local VIGNETTE_TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\Vignette"
local VIGNETTE_CORNERS = { -- point, texcoords (left, right, top, bottom)
	topLeft = { "TOPLEFT", 1, 0, 1, 0 }, topRight = { "TOPRIGHT", 0, 1, 1, 0 },
	bottomLeft = { "BOTTOMLEFT", 1, 0, 0, 1 }, bottomRight = { "BOTTOMRIGHT", 0, 1, 0, 1 },
}
local VIGNETTE_EDGES = { -- between corners (top left, bottom right), texcoords
	top = { "topLeft", "topRight", 0, 0, 1, 0 }, bottom = { "bottomLeft", "bottomRight", 0, 0, 0, 1 },
	left = { "topLeft", "bottomLeft", 1, 0, 0, 0 }, right = { "topRight", "bottomRight", 0, 1, 0, 0 },
}

local function CreateVignette(frame)
	local pieces = {}
	for name, corner in pairs(VIGNETTE_CORNERS) do
		local piece = frame:CreateTexture(nil, "ARTWORK")
		piece:SetTexture(VIGNETTE_TEXTURE)
		piece:SetTexCoord(corner[2], corner[3], corner[4], corner[5])
		piece:SetPoint(corner[1])
		pieces[name] = piece
	end
	for name, edge in pairs(VIGNETTE_EDGES) do
		local piece = frame:CreateTexture(nil, "ARTWORK")
		piece:SetTexture(VIGNETTE_TEXTURE)
		piece:SetTexCoord(edge[3], edge[4], edge[5], edge[6])
		local from, to = pieces[edge[1]], pieces[edge[2]]
		if name == "top" or name == "bottom" then
			piece:SetPoint("TOPLEFT", from, "TOPRIGHT")
			piece:SetPoint("BOTTOMRIGHT", to, "BOTTOMLEFT")
		else
			piece:SetPoint("TOPLEFT", from, "BOTTOMLEFT")
			piece:SetPoint("BOTTOMRIGHT", to, "TOPRIGHT")
		end
		pieces[name] = piece
	end
	return pieces
end

-- size: the fraction of the screen each edge covers; alpha: its darkness;
-- r, g, b: its colour (black if left out); w, h: the frame's size, if not
-- the screen's (a preview); sides: the sides' share of the width, if not size.
local function SetVignette(pieces, size, alpha, r, g, b, w, h, sides)
	local width, height = w or UIParent:GetWidth(), h or UIParent:GetHeight()
	for name, piece in pairs(pieces) do
		piece:SetShown(alpha > 0)
		piece:SetVertexColor(r or 0, g or 0, b or 0, alpha)
		if VIGNETTE_CORNERS[name] then
			piece:SetSize(width * (sides or size), height * size)
		end
	end
end
-- (Also LowHealth.lua's.)
ns.CreateVignette, ns.SetVignette = CreateVignette, SetVignette
-- The vignette's darkness for its strength setting (0-1). Eased so the low
-- end shows: drawn as-is, 5% was 5% black at the very corner and moving the
-- slider there changed nothing you could see (the user, 2026-11-23). 5% is
-- 17% now, 10% (the default) 25%, 50% 66%, 100% still all the way.
ns.VignetteAlpha = function(strength)
	strength = tonumber(strength) or 0
	return strength > 0 and math.min(1, strength) ^ 0.6 or 0
end

-- VERTICAL "from" is the bottom, for HORIZONTAL the left.
-- The two colour objects are made once and reused: CreateColor makes a new
-- one, with its own copy of every colour method, each call, and the tint
-- sets several gradients a few times a second.
local gradientColors
local function SetGradient(texture, orientation, from, to)
	if CreateColor and not gradientColors then
		gradientColors = { CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0) }
	end
	local fromColor, toColor = gradientColors and gradientColors[1], gradientColors and gradientColors[2]
	if fromColor and fromColor.SetRGBA then
		fromColor:SetRGBA(from[1], from[2], from[3], from[4])
		toColor:SetRGBA(to[1], to[2], to[3], to[4])
		if pcall(texture.SetGradient, texture, orientation, fromColor, toColor) then
			return
		end
	end
	if texture.SetGradientAlpha then
		texture:SetGradientAlpha(orientation, from[1], from[2], from[3], from[4], to[1], to[2], to[3], to[4])
	else
		texture:SetGradient(orientation, from[1], from[2], from[3], to[1], to[2], to[3])
	end
end

local function GameClock()
	local db = ns.db
	if db and db.tintClock == "local" then
		local now = date("*t")
		return now.hour, now.min
	end
	return GetGameTime()
end
ns.TintParts = { Approach = Approach, CreateVignette = CreateVignette, SetVignette = SetVignette,
	SetGradient = SetGradient, Frame = function() return nil end, GetClockTime = GameClock,
	Hour = function() return (GameClock()) end,
}

ns.Module("atmosphere", function() -- (the rest of this file: only with Atmosphere loaded, Modules.lua)

local db -- set once saved settings have loaded (ns.CreateTint runs at login)


-- Screen tint: a full-screen texture over the 3D world but under the UI
-- (BACKGROUND strata, like the letterbox). Multiply ("MOD") blending grades the
-- scene's colours, and can only darken; additive ("ADD") adds a glow. Strength
-- blends the tint toward no change. A vignette of four edge gradients can sit
-- on top. Both fade with cinematic mode.
local TINT_PRESETS = {
	{ key = "none", label = L["None"], tip = L["No color tint."] },
	{ key = "warm", label = L["Warm / golden hour"], mode = "MOD", color = { 1, 0.82, 0.6 },
		tip = L["Soft orange, like late-afternoon light."] },
	{ key = "cool", label = L["Cool"], mode = "MOD", color = { 0.75, 0.88, 1 },
		tip = L["Pale blue, crisp and wintry."] },
	{ key = "night", label = L["Night"], mode = "MOD", color = { 0.45, 0.55, 0.85 },
		tip = L["Deep blue and darker, like moonlight."] },
	{ key = "dusk", label = L["Dusk gradient"], mode = "MOD",
		top = { 1, 0.7, 0.45 }, bottom = { 0.6, 0.45, 0.85 },
		tip = L["Orange at the top fading to purple at the bottom, like a sunset."] },
	{ key = "sepia", label = L["Sepia-ish"], mode = "MOD", color = { 0.95, 0.8, 0.55 },
		tip = L["Warm brownish yellow, like an old photo. The world can't be fully desaturated."] },
	{ key = "dreamy", label = L["Dreamy"], mode = "ADD", color = { 0.3, 0.22, 0.12 },
		tip = L["A warm haze over everything."] },
	{ key = "custom", label = L["Custom"], mode = "MOD",
		tip = L["Your own color, chosen with the color picker below."] },
	{ key = "timeofday", label = L["Time of day"], mode = "MOD", dynamic = true,
		tip = L["Changes color through the day, from blue nights to golden evenings."] },
	{ key = "zone", label = L["Zone"], mode = "MOD", dynamic = true,
		tip = L["A mood color for the zone you're in, like pale blue in snow or sandy in deserts."] },
	{ key = "zonetime", label = L["Zone + time of day"], mode = "MOD", dynamic = true,
		tip = L["The zone's mood and the time-of-day color together."] },
}

-- Zone moods: subtle colours, multiplied over the scene.
local ZONE_MOODS = {
	snow = { { 0.82, 0.9, 1 }, L["Snow"] },
	desert = { { 1, 0.86, 0.66 }, L["Desert"] },
	savanna = { { 1, 0.92, 0.78 }, L["Savanna"] },
	swamp = { { 0.8, 0.92, 0.74 }, L["Swamp and jungle"] },
	blight = { { 0.88, 0.92, 0.62 }, L["Blighted"] },
	volcanic = { { 1, 0.8, 0.68 }, L["Volcanic"] },
	forest = { { 0.92, 0.98, 0.85 }, L["Forest"] },
	dusky = { { 0.72, 0.75, 0.92 }, L["Dusky"] },
	forge = { { 0.8, 0.72, 0.62 }, L["Forge"] },   -- dim, warm and smoky
	hearth = { { 1, 0.95, 0.88 }, L["Warm"] },      -- just a touch of golden warmth
	dusty = { { 1, 0.86, 0.74 }, L["Dusty red"] },  -- sun-baked, a little orange
	sickly = { { 0.8, 0.88, 0.7 }, L["Sickly"] },   -- dim and faintly green
	airy = { { 1, 0.98, 0.93 }, L["Airy"] },        -- bright and clear, barely warm
	moonlit = { { 0.84, 0.88, 1 }, L["Moonlit"] },  -- cool, soft blue
	gloomy = { { 0.76, 0.83, 0.82 }, L["Gloomy"] }, -- foggy grey-green, damp and eerie
	twilight = { { 0.86, 0.8, 1 }, L["Twilight"] }, -- cool, soft purple-blue
	deeptwilight = { { 0.72, 0.64, 1 }, L["Deep twilight"] }, -- twilight, much stronger
	golden = { { 1, 0.9, 0.7 }, L["Golden"] },      -- warm harvest gold
	autumn = { { 1, 0.88, 0.76 }, L["Autumn"] },    -- rust and amber, red rock and turning leaves
	summer = { { 0.95, 0.97, 0.96 }, L["Summer"] }, -- clear and fresh, tames red ground, keeps blue skies
	fel = { { 0.84, 1, 0.76 }, L["Fel"] },          -- sickly bright green, demon-scorched land
	void = { { 0.7, 0.64, 0.9 }, L["Void"] },       -- dark twilight violet, dimmer than deep twilight
}
-- Zones by area ID, so names match in any client language. IDs a client
-- doesn't have are skipped, so retail's zones sit here too. Matching is by
-- name, so zones that share one (the two Nagrands) share a mood.
local ZONE_AREA_IDS = {
	[1] = "snow", [618] = "snow", [36] = "snow",                       -- Dun Morogh, Winterspring, Alterac Mountains
	[440] = "desert", [1377] = "desert", [3] = "desert",               -- Tanaris, Silithus, Badlands
	[405] = "desert", [400] = "desert",                                -- Desolace, Thousand Needles
	[17] = "savanna", [14] = "savanna", [215] = "savanna",             -- The Barrens, Durotar, Mulgore
	[8] = "swamp", [15] = "swamp", [33] = "swamp", [490] = "swamp",    -- Swamp of Sorrows, Dustwallow, Stranglethorn, Un'Goro
	[28] = "blight", [139] = "blight", [361] = "blight",               -- Western/Eastern Plaguelands, Felwood
	[85] = "blight", [41] = "blight",                                  -- Tirisfal Glades, Deadwind Pass
	[46] = "volcanic", [51] = "volcanic",                              -- Burning Steppes, Searing Gorge
	[12] = "forest", [331] = "forest", [17065] = "forest",             -- Elwynn Forest, Ashenvale, Gilneas
	[10] = "dusky",                                                    -- Duskwood
	[1537] = "forge",                                                  -- Ironforge
	[1519] = "hearth",                                                 -- Stormwind City
	[1637] = "dusty", [1497] = "sickly",                               -- Orgrimmar, Undercity
	[1638] = "airy", [1657] = "moonlit",                               -- Thunder Bluff, Darnassus
	[11] = "gloomy",                                                   -- Wetlands
	[141] = "twilight",                                                -- Teldrassil
	[40] = "golden",                                                   -- Westfall
	[44] = "summer", [38] = "summer", [267] = "summer",                -- Redridge Mountains, Loch Modan, Hillsbrad Foothills
	[130] = "gloomy",                                                  -- Silverpine Forest
	[45] = "savanna",                                                  -- Arathi Highlands
	[47] = "forest", [406] = "forest",                                 -- The Hinterlands, Stonetalon Mountains
	[4] = "dusty",                                                     -- Blasted Lands
	[148] = "moonlit", [493] = "twilight",                             -- Darkshore, Moonglade
	[357] = "swamp",                                                   -- Feralas
	[16] = "autumn",                                                   -- Azshara
	-- Retail: zones split or renamed since Classic
	[4709] = "savanna",                                                -- Southern Barrens
	[5339] = "swamp", [5287] = "swamp",                                -- Stranglethorn Vale, The Cape of Stranglethorn
	[4706] = "gloomy", [4714] = "forest",                              -- Ruins of Gilneas, Gilneas (worgen start)
	[616] = "forest",                                                  -- Mount Hyjal
	-- The Burning Crusade
	[3483] = "dusty", [3522] = "dusty",                                -- Hellfire Peninsula, Blade's Edge Mountains
	[3521] = "twilight", [3523] = "twilight",                          -- Zangarmarsh, Netherstorm
	[3519] = "autumn",                                                 -- Terokkar Forest
	[3518] = "summer",                                                 -- Nagrand (Outland; same name as Draenor's)
	[3520] = "moonlit",                                                -- Shadowmoon Valley (Outland; same name as Draenor's)
	[3703] = "hearth",                                                 -- Shattrath City
	[3433] = "gloomy",                                                 -- Ghostlands
	[4080] = "airy",                                                   -- Isle of Quel'Danas
	[3524] = "summer", [3525] = "dusty", [3557] = "twilight",          -- Azuremyst Isle, Bloodmyst Isle, The Exodar
	-- Wrath of the Lich King
	[3537] = "snow", [65] = "snow", [67] = "snow", [4197] = "snow",    -- Borean Tundra, Dragonblight, The Storm Peaks, Wintergrasp
	[210] = "moonlit",                                                 -- Icecrown
	[394] = "forest", [3711] = "swamp",                                -- Grizzly Hills, Sholazar Basin
	[66] = "gloomy",                                                   -- Zul'Drak
	[2817] = "twilight", [4395] = "twilight",                          -- Crystalsong Forest, Dalaran (Northrend)
	-- Cataclysm
	[5034] = "desert", [5733] = "volcanic",                            -- Uldum, Molten Front
	[5095] = "gloomy", [5389] = "gloomy",                              -- Tol Barad, Tol Barad Peninsula
	[4737] = "summer", [4720] = "swamp",                               -- Kezan, The Lost Isles
	-- Mists of Pandaria
	[5785] = "forest", [5805] = "golden",                              -- The Jade Forest, Valley of the Four Winds
	[6134] = "swamp", [6661] = "swamp",                                -- Krasarang Wilds, Isle of Giants
	[5841] = "snow", [5842] = "savanna",                               -- Kun-Lai Summit, Townlong Steppes
	[6138] = "sickly", [5840] = "hearth",                              -- Dread Wastes, Vale of Eternal Blossoms
	[6507] = "gloomy",                                                 -- Isle of Thunder
	[6757] = "summer", [5736] = "summer",                              -- Timeless Isle, The Wandering Isle
	-- Warlords of Draenor
	[6720] = "snow", [6721] = "dusty",                                 -- Frostfire Ridge, Gorgrond
	[6662] = "autumn", [6722] = "autumn",                              -- Talador, Spires of Arak
	[6719] = "moonlit", [6755] = "summer",                             -- Shadowmoon Valley (Draenor), Nagrand (Draenor)
	[6723] = "fel",                                                    -- Tanaan Jungle
	-- Legion
	[7334] = "autumn", [7558] = "forest",                              -- Azsuna, Val'sharah
	[7503] = "summer", [7541] = "gloomy",                              -- Highmountain, Stormheim
	[7637] = "twilight", [7502] = "twilight",                          -- Suramar, Dalaran (Broken Isles)
	[7543] = "fel",                                                    -- Broken Shore
	[8574] = "fel", [8899] = "fel", [8701] = "twilight",               -- Krokuun, Antoran Wastes, Eredath (Argus)
	-- Battle for Azeroth
	[8567] = "summer", [9042] = "summer", [8721] = "autumn",           -- Tiragarde Sound, Stormsong Valley, Drustvar
	[8499] = "swamp", [8500] = "swamp", [8501] = "desert",             -- Zuldazar, Nazmir, Vol'dun
	[10052] = "moonlit", [10290] = "dusty",                            -- Nazjatar, Mechagon
	-- Shadowlands
	[10534] = "airy", [11462] = "sickly",                              -- Bastion, Maldraxxus
	[11510] = "twilight", [10413] = "dusky",                           -- Ardenweald, Revendreth
	[11400] = "gloomy", [13570] = "gloomy",                            -- The Maw, Korthia
	[13536] = "airy",                                                  -- Zereth Mortis
	-- Dragonflight
	[13644] = "autumn", [13645] = "summer",                            -- The Waking Shores, Ohn'ahran Plains
	[13646] = "snow", [13647] = "airy",                                -- The Azure Span, Thaldraszus
	[14022] = "forge",                                                 -- Zaralek Cavern
	[14529] = "forest", [15105] = "forest",                            -- Emerald Dream, Amirdrassil
	-- The War Within
	[14717] = "summer", [14795] = "forge",                             -- Isle of Dorn, The Ringing Deeps
	[14838] = "golden", [14752] = "void",                              -- Hallowfall, Azj-Kahet
	[15347] = "forge", [16093] = "forge",                              -- Undermine (two IDs, one name)
	[10416] = "gloomy", [15336] = "void",                              -- Siren Isle, K'aresh
	-- Midnight
	[15968] = "golden", [15969] = "hearth",                            -- Eversong Woods, Silvermoon City
	[16215] = "airy",                                                  -- Isle of Quel'Danas (Midnight)
	[15947] = "forest",                                                -- Zul'Aman
	[15355] = "deeptwilight",                                          -- Harandar
	[16648] = "void",                                                  -- Voidstorm
}
-- Mood order for the options page.
local ZONE_MOOD_ORDER = { "snow", "desert", "savanna", "swamp", "blight", "volcanic", "forest", "dusky", "forge", "hearth", "dusty",
	"sickly", "airy", "moonlit", "gloomy", "twilight", "deeptwilight", "golden", "autumn", "summer", "fel", "void" }
-- At a border the old mood fades out, there's a pause with no mood (the land
-- either side blends for a while, and snow under an ember tint looks red), then
-- the new mood fades in. The pause is longer in the air, where you see
-- further back over the old zone. Timings: db.zoneFadeTime, db.zoneGapTime and
-- db.zoneGapFlying (seconds).

-- Time-of-day tint: colours at times of day (minutes after midnight),
-- blended in between.
local TIME_OF_DAY = {
	{ 0, { 0.5, 0.58, 0.88 }, "Night" },
	{ 300, { 0.5, 0.58, 0.88 }, "Night" },
	{ 390, { 1, 0.78, 0.78 }, "Dawn" },
	{ 480, { 1, 1, 1 }, "Day" },
	{ 1020, { 1, 1, 1 }, "Day" },
	{ 1110, { 1, 0.82, 0.6 }, "Golden hour" },
	{ 1200, { 0.78, 0.62, 0.88 }, "Dusk" },
	{ 1290, { 0.5, 0.58, 0.88 }, "Night" },
	{ 1440, { 0.5, 0.58, 0.88 }, "Night" },
}
local TIME_OF_DAY_REFRESH = 20 -- seconds between colour updates
-- Phases you can recolour, with the hour the quick preview shows for each.
local TIME_PHASES = {
	{ "Night", 2 }, { "Dawn", 6 }, { "Day", 12 }, { "Golden hour", 18 }, { "Dusk", 20 },
}
local DEFAULT_PHASE_COLOR = {}
for _, key in ipairs(TIME_OF_DAY) do DEFAULT_PHASE_COLOR[key[3]] = key[2] end
-- Strength drift: two slow waves with unrelated periods, so it wanders rather
-- than pulses. Refreshed a few times a second; the steps are far too small to see.
local DRIFT_PERIOD_A, DRIFT_PERIOD_B = 170, 410 -- seconds
local DRIFT_REFRESH = 0.25 -- seconds between drift updates

-- Tint state. Declared before the functions that use it: a Lua local only
-- exists from its declaration on, so anything above would see a nil global.
local VIGNETTE_SIZE = 0.25 -- fraction of the screen each edge covers
local tintFrame, tintTexture, vignetteEdges

local tintLevel = 0
-- The vignette's and weather's own levels: they share the tint's overlay but
-- have their own rows in the Visual Effects page's grid.
-- (inn: the inn glow's own, wanted where the tint could show, CineMode or
-- Allow outside CineMode, whatever the tint's own page and row say: the glow
-- needed the tint itself showing, 2026-11-23.)
local layerLevel = { vignette = 0, weather = 0, inn = 0 }
local tintDirty = false
local tintPreview = false
-- /cine tinttest: each time of day in turn, its tint and its title.
local daySweep -- { started, each, shown } while it runs
local DAY_SWEEP_STOPS = { -- title, and the clock time (minutes) whose tint it shows
	{ "Dawn", 390 }, { "Morning", 600 }, { "Midday", 780 }, { "Afternoon", 930 },
	{ "Evening", 1110 }, { "Dusk", 1200 }, { "Night", 60 },
}
local DAY_SWEEP_GLIDE = 3 -- seconds the tint takes to move on to the next stop

-- The sweep's stop now, and its clock time in minutes (gliding in from the last).
local function DaySweepNow()
	local elapsed = GetTime() - daySweep.started
	local stops = daySweep.stops
	local index = math.min(#stops, math.floor(elapsed / daySweep.each) + 1)
	local from = stops[index == 1 and #stops or index - 1][2]
	local to = stops[index][2]
	local t = math.min(1, (elapsed - (index - 1) * daySweep.each) / (daySweep.glide or DAY_SWEEP_GLIDE))
	t = t * t * (3 - 2 * t) -- ease in and out
	return index, (from + ((to - from) % 1440) * t) % 1440, elapsed
end
local zoneMoodByName -- zone name -> mood key, built on first use
local zoneColor = { 1, 1, 1 } -- the zone colour shown now: zoneGoal, faded by zoneMix
local zoneGoal = { 1, 1, 1 } -- the mood being shown, or faded out or in
local zoneMix = 1 -- how much of zoneGoal shows (0: none)
local zonePhase -- nil when settled; "out", "gap" or "in" across a border
local zoneGapUntil = 0
local zoneStrength -- the Zone presets' strength shown now, blending toward the zone's own
local shownPreset -- the preset on screen; trails HerePreset() across a border
local presetFade = 1 -- dips to 0 and back to swap presets at a border
local PRESET_SWITCH_TIME = 1.5 -- seconds to fade out the old preset (and again to fade in the new)

-- Inn glow: indoors in an inn the outdoor mood (a gloomy marsh, a moonlit night)
-- partly lifts, and a soft hearth glow is added. Multiply can only darken, so
-- the glow is its own additive layer, brighter low down like firelight. The
-- glow takes on the zone's colour: cooler in the snow, greener in a swamp.
-- The glow's colour, scaled so its brightest part (red, at the bottom) adds
-- exactly the Glow amount setting.
local INN_GLOW_BOTTOM = { 1, 0.62, 0.23 }
local INN_GLOW_TOP = { 0.46, 0.27, 0.09 }
local INN_ZONE_WEIGHT = 2 -- how strongly the zone colours the glow (a power on its colour)
local INN_SOFTEN = 0.6    -- how much of the main tint lifts indoors in an inn
local INN_BLEND_TIME = 3  -- seconds to blend in or out at the door
local INN_CHECK = 0.5     -- seconds between indoor checks (there's no reliable event)
local innGlowTexture
local innLevel, innWanted, innCheckedAt = 0, false, 0

-- Weather: rain, snow and sandstorms grade the scene through their own
-- multiply layer, so they work with any preset (None included). Scaled by the
-- weather's intensity, off under a roof, and blended in and out as a storm
-- builds or you go indoors. Only on clients with C_Weather.
local WEATHER_TYPE = Enum and Enum.WeatherType or {}
local WEATHER_COLORS = {
	[WEATHER_TYPE.Rain or 1] = { 0.62, 0.66, 0.74 },      -- dark grey and cool, gloomy overcast
	[WEATHER_TYPE.Snow or 2] = { 0.86, 0.91, 1 },         -- pale blue, bright and cold
	[WEATHER_TYPE.Sandstorm or 3] = { 1, 0.82, 0.6 },     -- dusty orange haze
	[WEATHER_TYPE.Miscellaneous or 4] = { 0.86, 0.86, 0.9 }, -- a neutral grey haze
}
local WEATHER_BLEND_TIME = 8 -- seconds to blend as weather changes or at a door
local WEATHER_CHECK = 1      -- seconds between weather checks
local weatherTexture
local weatherColor = { 1, 1, 1 } -- the weather colour shown now, blending toward the current weather's
local weatherCheckedAt = 0
local weatherTarget = { 1, 1, 1 }

-- The mood key for the zone you're in, or nil.
local function CurrentZoneMood()
	if not zoneMoodByName then
		zoneMoodByName = {}
		for areaID, mood in pairs(ZONE_AREA_IDS) do
			local name = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(areaID)
			if name then
				zoneMoodByName[name] = mood
			end
		end
	end
	return zoneMoodByName[GetRealZoneText() or ""]
end

-- The Tint Style tab's settings (the preset, zones' tints and presets, the
-- day's phases, the clock): yours while its Enable Page is on, else the
-- defaults (no zone or phase of your own).
local function Look()
	if db and ns.PageOn("tintStyle") then return db end
	return ns.DEFAULTS
end

-- The zone tint for a zone: your override if you set one, else the built-in
-- mood. Returns the colour, a label and whether it's your override.
local function ZoneTint(zoneName)
	local look = Look()
	local override = look.zoneTints and look.zoneTints[zoneName]
	if type(override) == "table" then
		return override, L["Custom color"], true
	elseif override == "none" then
		return { 1, 1, 1 }, L["No tint"], true
	elseif override and ZONE_MOODS[override] then
		return ZONE_MOODS[override][1], ZONE_MOODS[override][2], true
	end
	CurrentZoneMood() -- builds the name lookup
	local mood = ZONE_MOODS[zoneMoodByName[zoneName]]
	if mood then
		return mood[1], mood[2], false
	end
	return { 1, 1, 1 }, L["No tint"], false
end

-- A zone's strength for the Zone presets: its own if set, else the main one.
local function ZoneStrength(zoneName)
	local look = Look()
	local own = look.zoneTintStrength and look.zoneTintStrength[zoneName]
	return own or db.tintStrength, own ~= nil
end

-- Areas within a zone (towns, ports, outposts): they take the zone's tint, but
-- some are softer built in (a clean harbour town in a swamp, say), and the
-- player can give any area its own colour or strength. Names are your game
-- language's.
local AREA_STRENGTH = {
	["Theramore Isle"] = 0.4, ["Booty Bay"] = 0.5, ["Ratchet"] = 0.5, ["Gadgetzan"] = 0.6,
	["Light's Hope Chapel"] = 0.5, ["Everlook"] = 0.6, ["Cenarion Hold"] = 0.6,
	["Menethil Harbor"] = 1.2, -- a little more haunted than the marsh around it
}

local function CurrentArea()
	local zone, area = GetRealZoneText() or "", GetSubZoneText() or ""
	if area ~= "" and area ~= zone then
		return area
	end
end

-- The tint where you're standing: the area's own choice if it has one, else
-- the zone's. Also returns whether it came from the area.
local function HereTint()
	local area = CurrentArea()
	local look = Look()
	if area and look.zoneTints and look.zoneTints[area] ~= nil then
		local color, label = ZoneTint(area)
		return color, label, true
	end
	local color, label = ZoneTint(GetRealZoneText() or "")
	return color, label, false
end

-- The strength where you're standing: the area's own, or the zone's (softened
-- for the built-in areas). Also returns the area's default and whether it
-- has its own.
local function HereStrength()
	local zoneStrength = (ZoneStrength(GetRealZoneText() or ""))
	local area = CurrentArea()
	if not area then
		return zoneStrength, zoneStrength, false
	end
	local default = zoneStrength * (AREA_STRENGTH[area] or 1)
	local look = Look()
	local own = look.zoneTintStrength and look.zoneTintStrength[area]
	return own or default, default, own ~= nil
end

local function ZoneTargetColor()
	return (HereTint())
end

-- Per-zone presets: a zone or area can swap in a whole preset of its own
-- (Night in Duskwood, None in a city). The area's wins over the zone's; with
-- neither, your main preset. Also returns where it came from: "area", "zone" or nil.
local function HerePreset()
	local look = Look()
	local presets = look.zonePresets
	if presets then
		local area = CurrentArea()
		if area and presets[area] then
			return presets[area], "area"
		end
		local zone = presets[GetRealZoneText() or ""]
		if zone then
			return zone, "zone"
		end
	end
	return look.tintPreset
end

local function SameColor(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local function InTheAir()
	return ns.OnTaxi() or (IsFlying and IsFlying()) or false
end

-- Moves the shown zone colour and strength toward the zone's: a new mood
-- fades the old one out, pauses, then fades in. True while anything changed.
local function BlendZoneColor(elapsed, instant)
	local target = ZoneTargetColor()
	local targetStrength = (HereStrength())
	local before1, before2, before3, beforeStrength = zoneColor[1], zoneColor[2], zoneColor[3], zoneStrength
	if instant or not zoneStrength then
		zoneGoal = { target[1], target[2], target[3] }
		zoneMix, zonePhase, zoneStrength = 1, nil, targetStrength
	else
		if not SameColor(target, zoneGoal) then
			if zonePhase == nil or zonePhase == "in" then
				zonePhase = "out"
			end
		elseif zonePhase == "out" then
			zonePhase = "in" -- turned back before the old mood had gone
		end
		if zonePhase == "out" then
			if SameColor(zoneGoal, { 1, 1, 1 }) then
				zoneMix = 0 -- an untinted zone: nothing to fade out
			end
			zoneMix = Approach(zoneMix, 0, elapsed, db.zoneFadeTime)
			if zoneMix == 0 then
				zonePhase = "gap"
				zoneGapUntil = GetTime() + (InTheAir() and db.zoneGapFlying or db.zoneGapTime)
			end
		end
		if zonePhase == "gap" then
			-- Nothing shows, so take on the new mood (and any later one) as is.
			zoneGoal = { target[1], target[2], target[3] }
			zoneStrength = targetStrength
			if GetTime() >= zoneGapUntil then
				zonePhase = "in"
			end
		end
		if zonePhase == "in" then
			zoneMix = Approach(zoneMix, 1, elapsed, db.zoneFadeTime)
			if zoneMix == 1 then
				zonePhase = nil
			end
		end
		if zonePhase ~= "out" and zonePhase ~= "gap" then
			zoneStrength = Approach(zoneStrength, targetStrength, elapsed, db.zoneFadeTime)
		end
	end
	for c = 1, 3 do
		zoneColor[c] = 1 - (1 - zoneGoal[c]) * zoneMix
	end
	return zoneColor[1] ~= before1 or zoneColor[2] ~= before2 or zoneColor[3] ~= before3
		or zoneStrength ~= beforeStrength
end

local function GetClockTime()
	if Look().tintClock == "local" then
		local now = date("*t")
		return now.hour, now.min
	end
	return GetGameTime()
end

-- Showing a preview: an hour picked in the Atmosphere hub's Tint tab's Preview time
-- (just opening the page shows nothing), or /cine tinttest is running.
local function Previewing()
	return (tintPreview and (db.tintPreviewHour or -1) >= 0) or daySweep ~= nil
end

-- A phase's colour: your own if you picked one, else the built-in.
local function PhaseColor(name)
	local look = Look()
	return look.timePhaseColors and look.timePhaseColors[name] or DEFAULT_PHASE_COLOR[name]
end

-- A phase's own strength (default full), and the colour as applied: blended
-- toward no change by that strength.
local DEFAULT_PHASE_STRENGTH = { Night = 0.65 } -- others: full
local function PhaseStrength(name)
	local look = Look()
	return look.timePhaseStrength and look.timePhaseStrength[name] or DEFAULT_PHASE_STRENGTH[name] or 1
end

local function AppliedPhaseColor(name)
	local color, strength = PhaseColor(name), PhaseStrength(name)
	return {
		1 - (1 - color[1]) * strength,
		1 - (1 - color[2]) * strength,
		1 - (1 - color[3]) * strength,
	}
end

-- The tint colour for the current time, the phase's name, and the time.
-- A previewed hour (/cine tinttest, or the Tint tab), else the clock.
-- Time-of-day strength blends the colour toward no change.
local function TimeOfDayColor()
	local hour, minute
	if daySweep then
		local _, minutes = DaySweepNow()
		hour, minute = math.floor(minutes / 60), minutes % 60
	elseif tintPreview and (db.tintPreviewHour or -1) >= 0 then
		hour, minute = db.tintPreviewHour, 0
	else
		hour, minute = GetClockTime()
	end
	local now = hour * 60 + minute
	local color, phase = { 1, 1, 1 }, TIME_OF_DAY[1][3]
	for i = 1, #TIME_OF_DAY - 1 do
		local from, to = TIME_OF_DAY[i], TIME_OF_DAY[i + 1]
		if now >= from[1] and now < to[1] then
			local t = (now - from[1]) / (to[1] - from[1])
			local fromColor, toColor = AppliedPhaseColor(from[3]), AppliedPhaseColor(to[3])
			for c = 1, 3 do
				color[c] = fromColor[c] + (toColor[c] - fromColor[c]) * t
			end
			phase = (t < 0.5 and from or to)[3]
			break
		end
	end
	local strength = db.timeTintStrength or 1
	for c = 1, 3 do
		color[c] = 1 - (1 - color[c]) * strength
	end
	return color, phase, hour, minute
end
-- The drift multiplier on tint strength: 1 +/- the drift amount, wandering
-- slowly. Off while previewing, so the Tint tab shows the strength you set.
local function DriftFactor()
	if not db.tintDrift or Previewing() then
		return 1
	end
	local now = GetTime()
	local wave = 0.6 * math.sin(now * 2 * math.pi / DRIFT_PERIOD_A)
		+ 0.4 * math.sin(now * 2 * math.pi / DRIFT_PERIOD_B + 1.3)
	return 1 + wave * (db.tintDriftAmount or 0)
end

local TINT_BY_KEY = {}
for _, preset in ipairs(TINT_PRESETS) do TINT_BY_KEY[preset.key] = preset end

-- My tints: looks you made on the Tint Style page (db.myTints, each { key =
-- "mine<n>", name, color = { r, g, b }, color2 = { r, g, b } or nil (the
-- bottom of the screen), glow = true: added light, not a color over it}).
-- Picked like a preset, by its key.
local GLOW_SCALE = 0.35 -- a glow's color as added light: Dreamy's is about this bright
local function MyTint(key)
	local list = db and db.myTints
	if type(key) ~= "string" or not list then return nil end
	for _, tint in ipairs(list) do
		if tint.key == key then return tint end
	end
end
local function MyTintPreset(key)
	local tint = MyTint(key)
	if not tint or type(tint.color) ~= "table" then return nil end
	local function shade(color)
		if not tint.glow then return color end
		return { color[1] * GLOW_SCALE, color[2] * GLOW_SCALE, color[3] * GLOW_SCALE }
	end
	return { key = key, label = tint.name or "?", mode = tint.glow and "ADD" or "MOD",
		top = shade(tint.color), bottom = shade(type(tint.color2) == "table" and tint.color2 or tint.color) }
end
local function PresetOf(key)
	return TINT_BY_KEY[key] or MyTintPreset(key) or TINT_BY_KEY.none
end

-- Gradient across a texture, coping with both the colour-object API of newer
-- clients and the older number-based one. Colours are { r, g, b, a }; for

local function CreateTint()
	tintFrame = CreateFrame("Frame", "CinematicTint", UIParent)
	ns.CoverWorld(tintFrame)
	tintFrame:SetFrameStrata("BACKGROUND")
	tintFrame:SetFrameLevel(0)
	tintFrame:EnableMouse(false)
	ns.AddOverlay(tintFrame)

	-- The washes (tint, inn glow, weather) are WorldFrame's own textures on
	-- Forever: the nameplates are in WorldFrame, under all of UIParent, so a
	-- wash on a frame of ours colours their names too (a warrior's name read
	-- as a druid's). Tested there with /cine debug tintlayer: a frame of ours
	-- lands over the names wherever it's put (child of WorldFrame or not, any
	-- strata); only WorldFrame's own textures draw under them. They show with
	-- the UI hidden too, and each is hidden when it has nothing to draw.
	-- (Retail and Classic Era: untested, as before.)
	local host = (ns.isRetail or ns.isClassicEra) and tintFrame or WorldFrame
	tintTexture = host:CreateTexture(nil, "BACKGROUND")
	tintTexture:SetAllPoints()
	tintTexture:SetColorTexture(1, 1, 1, 1)
	tintTexture:Hide()

	innGlowTexture = host:CreateTexture(nil, "BORDER")
	innGlowTexture:SetAllPoints()
	innGlowTexture:SetColorTexture(1, 1, 1, 1)
	innGlowTexture:SetBlendMode("ADD")
	innGlowTexture:Hide()

	weatherTexture = host:CreateTexture(nil, "BACKGROUND", nil, 1)
	weatherTexture:SetAllPoints()
	weatherTexture:SetColorTexture(1, 1, 1, 1)
	weatherTexture:SetBlendMode("MOD")
	weatherTexture:Hide()

	vignetteEdges = CreateVignette(tintFrame)
	tintFrame:Hide()
	-- Keep the letterbox bars above the tint so a glow doesn't tint them (and
	-- above Vitals Vision, a level over the tint).
	local letterbox = ns.GetLetterbox()
	if letterbox then
		letterbox:SetFrameLevel(tintFrame:GetFrameLevel() + 2)
	end
end

local CLASSIC_BOOST = 1.4 -- the tint's strength with Classic boost on (classic clients)

local function ApplyTint(level, vignetteLevel, weatherLevel)
	local preset = PresetOf(shownPreset)
	local isZone = preset.key == "zone" or preset.key == "zonetime"
	local strength = math.min(1, (isZone and zoneStrength or db.tintStrength) * DriftFactor())
		* level * presetFade * (1 - innLevel * INN_SOFTEN)

	if preset.mode and strength > 0 then
		-- Classic's brighter, more saturated world shows the same tint less:
		-- the boost pushes it past the colour, each channel kept in range.
		local boost = not ns.isRetail and db.tintClassicBoost and CLASSIC_BOOST or 1
		local function grade(color)
			local out = { 1, 1, 1, 1 }
			for c = 1, 3 do
				if preset.mode == "ADD" then
					out[c] = math.min(1, color[c] * strength * boost)
				else
					-- Multiply: blend from white (no change) toward the tint colour.
					out[c] = math.max(0, 1 - (1 - color[c]) * strength * boost)
				end
			end
			return out
		end
		local top, bottom
		if preset.key == "custom" then
			local look = Look()
			top = { look.tintCustomR, look.tintCustomG, look.tintCustomB }
			bottom = top
		elseif preset.key == "timeofday" then
			top = TimeOfDayColor()
			bottom = top
		elseif preset.key == "zone" then
			top = zoneColor
			bottom = top
		elseif preset.key == "zonetime" then
			local time = TimeOfDayColor()
			top = { zoneColor[1] * time[1], zoneColor[2] * time[2], zoneColor[3] * time[3] }
			bottom = top
		else
			top = preset.top or preset.color
			bottom = preset.bottom or preset.color
		end
		tintTexture:SetBlendMode(preset.mode)
		local low, high = grade(bottom), grade(top)
		SetGradient(tintTexture, "VERTICAL", low, high)
		tintTexture:Show()
		-- (What it drew, for the welcome window's demos' test: Dev/ShelfTest.lua.
		-- On ns, not a local: kept off this file's count. One table, reused.)
		local drawn = ns.tintDrawn or {}
		ns.tintDrawn = drawn
		drawn.preset, drawn.mode, drawn.strength, drawn.level = preset.key, preset.mode, strength, level
		drawn.r, drawn.g, drawn.b, drawn.weather, drawn.none = high[1], high[2], high[3], weatherLevel, false
		-- (The world map's dim: a darkening tint's middle colour. A glow, none.)
		for c = 1, 3 do
			ns.mapDim.color[c] = preset.mode == "MOD" and (low[c] + high[c]) / 2 or 1
		end
	else
		local drawn = ns.tintDrawn or {}
		ns.tintDrawn = drawn
		drawn.preset, drawn.mode, drawn.strength, drawn.level = preset.key, preset.mode, strength, level
		drawn.r, drawn.g, drawn.b, drawn.weather, drawn.none = nil, nil, nil, weatherLevel, true
		tintTexture:Hide()
		ns.mapDim.color[1], ns.mapDim.color[2], ns.mapDim.color[3] = 1, 1, 1
	end

	local glow = innLevel * layerLevel.inn * (db.innGlowAmount or 0)
	if glow > 0 then
		-- The zone's colour with its brightest channel at 1, so it shifts the
		-- glow's hue without dimming it.
		local zone = HereTint()
		local peak = math.max(zone[1], zone[2], zone[3], 0.01)
		local bottom, top = { 0, 0, 0, 1 }, { 0, 0, 0, 1 }
		for c = 1, 3 do
			local shade = (zone[c] / peak) ^ INN_ZONE_WEIGHT * glow
			bottom[c], top[c] = INN_GLOW_BOTTOM[c] * shade, INN_GLOW_TOP[c] * shade
		end
		SetGradient(innGlowTexture, "VERTICAL", bottom, top)
		innGlowTexture:Show()
	else
		innGlowTexture:Hide()
	end

	local weather = { 1, 1, 1, 1 }
	for c = 1, 3 do
		weather[c] = 1 - (1 - weatherColor[c]) * weatherLevel
	end
	if weather[1] < 1 or weather[2] < 1 or weather[3] < 1 then
		SetGradient(weatherTexture, "VERTICAL", weather, weather)
		weatherTexture:Show()
	else
		weatherTexture:Hide()
	end
	for c = 1, 3 do
		ns.mapDim.color[c] = ns.mapDim.color[c] * weather[c]
	end
	ns.mapDim.level = level
	ns.UpdateMapDim()

	local vignetteAlpha = db.vignette and ns.VignetteAlpha(db.vignetteStrength) * vignetteLevel or 0
	SetVignette(vignetteEdges, VIGNETTE_SIZE, vignetteAlpha)
	-- (What the vignette, glow and weather drew, for /cine debug atmosphere:
	-- Dev/AtmosphereTest.lua. In ns.tintDrawn, set above.)
	local drawn = ns.tintDrawn
	drawn.vignette, drawn.glow = vignetteAlpha, glow
	drawn.wr, drawn.wg, drawn.wb = weather[1], weather[2], weather[3]

	tintFrame:SetShown(level > 0 or vignetteLevel > 0 or weatherLevel > 0 or glow > 0)
end

-- The washes off, whatever else went wrong (they aren't the tint frame's own
-- on Forever: hiding it doesn't hide them).
function ns.HideTintWash()
	for _, texture in ipairs({ tintTexture or false, innGlowTexture or false, weatherTexture or false }) do
		if texture then texture:Hide() end
	end
	if tintFrame then tintFrame:Hide() end
	ns.mapDim.color[1], ns.mapDim.color[2], ns.mapDim.color[3] = 1, 1, 1
	ns.mapDim.level = 0
	ns.UpdateMapDim()
end

-- The world map dims with the world: in CineMode a dark scene (Duskwood at
-- night) made a maximized map flash bright. Laid over the map's scroll area
-- (its pins too, not the side panel or border): the tint's and weather's
-- darkening colour (color, from ApplyTint), times a flat dim (Dim the world
-- map), which comes and goes with the tint (level). The tint alone was too
-- light: most of a dark zone's dark is the game's own lighting.
-- The map loads on demand: hooked once it's there (UpdateTint looks), and
-- redrawn as it opens. (Fields on ns: no more locals for this main chunk.)
ns.mapDim = { color = { 1, 1, 1 }, level = 0 }
function ns.UpdateMapDim()
	local state = ns.mapDim
	local area = _G.WorldMapFrame and _G.WorldMapFrame.ScrollContainer
	if not area then return end
	local amount = db and db.mapDim or 0
	local r, g, b = 1, 1, 1
	if amount > 0 then
		local color = state.color
		if db.mapDimFollowTint then
			-- Match the tint: the slider is the most; a dark tint (night,
			-- a storm) gets all of it, a light one little, a clear day none.
			-- (The darkening colour's brightness: a full night tint is ~0.6.)
			local light = color[1] * 0.299 + color[2] * 0.587 + color[3] * 0.114
			amount = amount * math.min(1, math.max(0, 1 - light) / 0.4)
		end
		local keep = 1 - amount * (state.level or 0)
		r, g, b = color[1] * keep, color[2] * keep, color[3] * keep
	end
	if r > 0.995 and g > 0.995 and b > 0.995 then
		if state.frame then state.frame:Hide() end
		return
	end
	if not state.frame then
		local frame = CreateFrame("Frame", nil, area)
		frame:SetAllPoints(area)
		-- (Over the pins, which stack up from the map canvas's level.)
		frame:SetFrameLevel(math.min(area:GetFrameLevel() + 1500, 9000))
		frame:EnableMouse(false)
		local texture = frame:CreateTexture(nil, "OVERLAY")
		texture:SetAllPoints()
		texture:SetColorTexture(1, 1, 1, 1)
		texture:SetBlendMode("MOD")
		state.frame, state.texture = frame, texture
	end
	state.texture:SetVertexColor(r, g, b, 1)
	state.frame:Show()
end
function ns.HookMapDim()
	local map = _G.WorldMapFrame
	if ns.mapDim.hooked or not map then return end
	ns.mapDim.hooked = true
	map:HookScript("OnShow", function() ns.Guard(ns.UpdateMapDim) end)
	ns.UpdateMapDim()
end

-- cinematic: already false outside the situations ticked for the tint (see Core).
local function TintWanted(cinematic)
	-- (Show me's effects demo: with the effects switched off too, as before a profile's picked.)
	return (cinematic or Previewing()) and (db.visualEffects ~= false or ns.effectsDemo ~= nil)
end

-- The tint's own frame and clock for Death Vision and the time of day's
-- title and cards (above: what they have with Atmosphere left out).
local T = ns.TintParts
T.Frame = function() return tintFrame end
T.GetClockTime = function() db = db or ns.GetDB(); return GetClockTime() end
T.Hour = function()
	db = db or ns.GetDB()
	local _, _, hour = TimeOfDayColor()
	return hour
end

-- Indoors in an inn: resting outside a capital, under a roof. (The rested area
-- often spills out the door; the roof check keeps the street outside dark.)
local function InInn()
	-- (The Visual Effects page's inn preview: as if inside one.)
	if db.innGlow and ns.EffectPreviewing("inn") then return true end
	if not db.innGlow or ns.GetPlaceType() ~= "inn" then
		return false
	end
	local ok, indoors = pcall(IsIndoors)
	return ok and indoors == true
end

-- Moves the inn glow toward in or out. True while it changed.
local function UpdateInnGlow(elapsed)
	local now = GetTime()
	if now - innCheckedAt >= INN_CHECK then
		innCheckedAt = now
		innWanted = InInn()
	end
	local target = innWanted and 1 or 0
	if innLevel == target then
		return false
	end
	-- While the glow is hidden or previewed, just jump.
	innLevel = (layerLevel.inn == 0 or ns.atmoPreview.kind == "inn") and target
		or Approach(innLevel, target, elapsed, INN_BLEND_TIME)
	return true
end

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

-- The current weather's type and intensity (0-1), or nil if the client
-- doesn't say. (In clear weather the client gives { type = 0, intensity = 0 }.)
local function CurrentWeather()
	if not (C_Weather and C_Weather.GetCurrentWeather) then
		return nil
	end
	local ok, weather = pcall(C_Weather.GetCurrentWeather)
	if not ok or type(weather) ~= "table" or IsSecret(weather) then
		return nil
	end
	local kind, intensity = weather.type, weather.intensity
	if IsSecret(kind) or IsSecret(intensity) or type(kind) ~= "number" or type(intensity) ~= "number" then
		return nil
	end
	return kind, math.max(0, math.min(1, intensity))
end

-- Bad weather's intensity here (0-1): rain, snow or a sandstorm; 0 in clear
-- or other weather, under a roof or when the client doesn't say. (For the
-- view distance in bad weather: Graphics.lua.)
local BAD_WEATHER = {
	[WEATHER_TYPE.Rain or 1] = true,
	[WEATHER_TYPE.Snow or 2] = true,
	[WEATHER_TYPE.Sandstorm or 3] = true,
}
function ns.BadWeatherIntensity()
	local ok, indoors = pcall(IsIndoors)
	if ok and indoors then
		return 0
	end
	local kind, intensity = CurrentWeather()
	return kind and BAD_WEATHER[kind] and intensity or 0
end

-- The weather colour to show here: no change with the option off, indoors,
-- or in clear or unknown weather.
local function WeatherTargetColor()
	local kind, intensity
	local strength = db.weatherTintStrength or 0
	if db.weatherTint and ns.EffectPreviewing("weather") then
		-- (The Visual Effects page's weather preview: that weather at its
		-- heaviest, indoors too; at 50% while Weather strength is Off, so its
		-- buttons show what it would look like.)
		kind, intensity = ns.atmoPreview.weather, 1
		if strength <= 0 then strength = 0.5 end
	elseif db.weatherTint then
		local ok, indoors = pcall(IsIndoors)
		if not (ok and indoors) then
			kind, intensity = CurrentWeather()
		end
	end
	local color = kind and ns.WeatherColor(kind)
	local amount = color and intensity * strength or 0
	local target = { 1, 1, 1 }
	for c = 1, 3 do
		target[c] = color and 1 - (1 - color[c]) * amount or 1
	end
	return target
end

-- Moves the shown weather colour toward the weather's. True while it changed.
local function UpdateWeather(elapsed)
	local now = GetTime()
	if now - weatherCheckedAt >= WEATHER_CHECK then
		weatherCheckedAt = now
		weatherTarget = WeatherTargetColor()
	end
	local changed = false
	for c = 1, 3 do
		if weatherColor[c] ~= weatherTarget[c] then
			-- While the tint is hidden or previewed, just jump.
			weatherColor[c] = (layerLevel.weather == 0 or ns.atmoPreview.kind == "weather") and weatherTarget[c]
				or Approach(weatherColor[c], weatherTarget[c], elapsed, ns.WeatherBlendTime())
			changed = true
		end
	end
	return changed
end

local timeOfDayRefreshedAt = 0
local driftRefreshedAt = 0

-- When a zone's own preset takes over at a border, the old preset fades out
-- and the new one fades in. While the tint is hidden or previewed it just
-- swaps. True while anything changed.
local function UpdatePresetSwap(elapsed)
	local want = daySweep and "timeofday" or HerePreset()
	if want ~= shownPreset then
		if tintLevel == 0 or Previewing() or not shownPreset then
			shownPreset, presetFade = want, 1
		else
			if shownPreset == "none" then
				presetFade = 0 -- nothing to fade out
			end
			presetFade = Approach(presetFade, 0, elapsed, PRESET_SWITCH_TIME)
			if presetFade > 0 then
				return true
			end
			shownPreset = want
		end
		BlendZoneColor(0, true) -- a Zone preset starts at this zone's colour
		return true
	elseif presetFade < 1 then
		presetFade = Approach(presetFade, 1, elapsed, PRESET_SWITCH_TIME)
		return true
	end
	return false
end

-- A level (the tint's, vignette's or weather's) one step toward wanted (0 or 1).
local function FadeLevel(level, wanted, elapsed)
	local duration = wanted > level and ns.FadeOutTime() or ns.FadeInTime()
	-- (A Visual Effects page preview comes in at once, so a slider's move
	-- shows as you make it; it fades out as the effect would.)
	return (Previewing() or (ns.atmoPreview.kind and wanted > level)) and wanted
		or Approach(level, wanted, elapsed, duration)
end

-- cinematic, vignetteOn, weatherOn: whether each is wanted now (see Core).
-- (Asked every tick, 28 times a second: with nothing of it fading, wanted as
-- last time and no death screen, it looks only 5 times a second. What it
-- drew last time, or anything marked to redraw,
-- keeps it at every tick. On ns: no more locals for this file's main chunk.)
ns.tintPace = { elapsed = 0, every = 0.2 }
local function UpdateTint(cinematic, elapsed, vignetteOn, weatherOn)
	local pace = ns.tintPace
	pace.elapsed = pace.elapsed + elapsed
	local preview = ns.atmoPreview
	if preview.kind and GetTime() >= preview.untilT then
		preview.kind = nil -- (its time is up: back to what's wanted, fading out)
		tintDirty = true
		innCheckedAt, weatherCheckedAt = 0, 0
	end
	if not pace.busy and not tintDirty and not daySweep and not (ns.DeathScreenBusy and ns.DeathScreenBusy())
		and pace.tint == cinematic and pace.vignette == vignetteOn and pace.weather == weatherOn
		and pace.elapsed < pace.every and not Previewing() and not preview.kind then
		return
	end
	-- (This tick's own time, not the wait's: nothing was fading through it, and
	-- a fade starting now would jump by it.)
	pace.elapsed = 0
	pace.tint, pace.vignette, pace.weather, pace.busy = cinematic, vignetteOn, weatherOn, false
	if not ns.mapDim.hooked then ns.HookMapDim() end
	if ns.UpdateDeathVision then ns.UpdateDeathVision(elapsed) end -- (DeathVision.lua)
	local target = TintWanted(cinematic) and 1 or 0
	-- (A Visual Effects page preview: its effect wanted now, CineMode or not.)
	local vignetteWant = (TintWanted(vignetteOn) or preview.kind == "vignette") and 1 or 0
	local weatherWant = (TintWanted(weatherOn) or preview.kind == "weather") and 1 or 0
	local innWant = (TintWanted(cinematic or ns.lastCinematic) or preview.kind == "inn") and 1 or 0
	-- (None of them wanted or showing, nothing to redraw: the colour's
	-- inputs (the preset swap, an inn, the weather, the zone's mood) aren't
	-- looked at. Picked up again as one's wanted: its checks are due by then.)
	if target == 0 and vignetteWant == 0 and weatherWant == 0 and innWant == 0 and tintLevel == 0
		and layerLevel.vignette == 0 and layerLevel.weather == 0 and layerLevel.inn == 0
		and not tintDirty and not daySweep then
		return
	end
	if UpdatePresetSwap(elapsed) then
		tintDirty = true
	end
	if UpdateInnGlow(elapsed) then
		tintDirty = true
	end
	if UpdateWeather(elapsed) then
		tintDirty = true
	end
	-- The time-of-day colour drifts with the clock, so refresh it now and then.
	local now = GetTime()
	local preset = shownPreset
	local usesTime = preset == "timeofday" or preset == "zonetime"
	if usesTime and tintLevel > 0 and now - timeOfDayRefreshedAt >= TIME_OF_DAY_REFRESH then
		timeOfDayRefreshedAt = now
		tintDirty = true
	end
	if db.tintDrift and tintLevel > 0 and now - driftRefreshedAt >= DRIFT_REFRESH then
		driftRefreshedAt = now
		tintDirty = true
	end
	if daySweep then
		local index, _, elapsed = DaySweepNow()
		if elapsed >= #daySweep.stops * daySweep.each then
			ns.DaySweep() -- done: stop
		elseif index ~= daySweep.shown then
			daySweep.shown = index
			if not daySweep.quiet then ns.TestTimeChangeTitle(daySweep.stops[index][1]) end
		end
		tintDirty = true
	end
	-- Zone moods blend across borders; while hidden the colour just jumps.
	if preset == "zone" or preset == "zonetime" then
		if BlendZoneColor(elapsed, tintLevel == 0) then
			tintDirty = true
		end
	end
	if tintLevel == target and layerLevel.vignette == vignetteWant and layerLevel.weather == weatherWant
		and layerLevel.inn == innWant and not tintDirty then
		return
	end
	tintDirty = false
	pace.busy = true -- (something moved: every tick till it's still)
	tintLevel = FadeLevel(tintLevel, target, elapsed)
	layerLevel.vignette = FadeLevel(layerLevel.vignette, vignetteWant, elapsed)
	layerLevel.weather = FadeLevel(layerLevel.weather, weatherWant, elapsed)
	layerLevel.inn = FadeLevel(layerLevel.inn, innWant, elapsed)
	ApplyTint(tintLevel, layerLevel.vignette, layerLevel.weather)
end

-- Entry points for Core.lua and the options page
-- The old single Custom color, where it was picked (the main look or a
-- place's), becomes a My tint of that color, picked there instead.
local function MoveCustomToMyTints()
	local used = db.tintPreset == "custom"
	for _, preset in pairs(db.zonePresets or {}) do
		if preset == "custom" then used = true end
	end
	if not used then return end
	local key = ns.AddMyTint({ name = L["My color"],
		color = { db.tintCustomR or 1, db.tintCustomG or 0.8, db.tintCustomB or 0.6 } })
	if db.tintPreset == "custom" then db.tintPreset = key end
	for name, preset in pairs(db.zonePresets or {}) do
		if preset == "custom" then db.zonePresets[name] = key end
	end
end

function ns.CreateTint()
	db = ns.GetDB()
	MoveCustomToMyTints()
	CreateTint()
	if ns.CreateDeathScreen then ns.CreateDeathScreen() end -- (DeathVision.lua)
end

ns.UpdateTint = UpdateTint
-- The Visual Effects page's previews (2026-11-23): a slider moved or a
-- Preview button shows that effect over the world for a few seconds, in
-- CineMode or out of it ("is it even on?": nothing showed outside CineMode,
-- and there was no way to see weather or an inn's glow on demand).
-- kind: "vignette", "weather" or "inn"; weather: the Enum.WeatherType to
-- show (default: the Weather page's pick, weatherPreviewKind).
-- (On ns: no more locals for this file's main chunk.)
ns.atmoPreview = { kind = nil, untilT = 0, weather = nil }
ns.EFFECT_PREVIEW_SECONDS = 3
ns.EffectPreviewing = function(kind, weather)
	local p = ns.atmoPreview
	if not p.kind or GetTime() >= p.untilT then return false end
	return (kind == nil or p.kind == kind) and (weather == nil or p.weather == weather)
end
ns.PreviewEffect = function(kind, seconds, weather)
	db = db or ns.GetDB()
	local p = ns.atmoPreview
	if kind == "weather" then
		-- (Else the Weather page's pick, Rain to start with.)
		p.weather = weather or ns.WeatherTypeOf(db.weatherPreviewKind or "Rain")
	end
	p.kind, p.untilT = kind, GetTime() + (seconds or ns.EFFECT_PREVIEW_SECONDS)
	tintDirty = true
	innCheckedAt, weatherCheckedAt = 0, 0
	-- (Out of CineMode the main tick waits a second at a time: at the full
	-- pace now, and till it has faded out after.)
	local idle = ns.idleTick
	if idle then
		idle.wake = true
		idle.busyUntil = math.max(idle.busyUntil or 0, p.untilT + (ns.FadeOutTime() or 1) + 1)
		idle.busyWhy = "effect preview"
	end
end
ns.StopEffectPreview = function()
	local p = ns.atmoPreview
	if not p.kind then return end
	p.untilT = 0 -- (UpdateTint lets it go, and it fades out)
	if ns.idleTick then ns.idleTick.wake = true end
end
-- The weather types the Weather pages offer: { type, label, its colour now,
-- name (Rain, Snow, Sandstorm: the Weather Style page's weather<Name>R/G/B
-- and the preview's weatherPreviewKind) } each.
ns.WEATHER_NAMES = { "Rain", "Snow", "Sandstorm" }
ns.WeatherTypeOf = function(name)
	local fallback = { Rain = 1, Snow = 2, Sandstorm = 3 }
	return WEATHER_TYPE[name] or fallback[name] or fallback.Rain
end
ns.PreviewWeatherTypes = function()
	local list = {}
	for _, name in ipairs(ns.WEATHER_NAMES) do
		local kind = ns.WeatherTypeOf(name)
		list[#list + 1] = { kind, L[name], ns.WeatherColor(kind), name }
	end
	return list
end
-- A weather's colour: yours from the Weather Style page while it's on (Style
-- loaded, Enable Style and the page's switch), else the built-in one.
ns.WeatherColor = function(kind)
	db = db or ns.GetDB()
	local builtIn = WEATHER_COLORS[kind]
	if not (builtIn and db and ns.StyleOn and ns.StyleOn("weatherStyle", db)) then return builtIn end
	for _, name in ipairs(ns.WEATHER_NAMES) do
		if ns.WeatherTypeOf(name) == kind then
			local r, g, b = db["weather" .. name .. "R"], db["weather" .. name .. "G"], db["weather" .. name .. "B"]
			if type(r) == "number" and type(g) == "number" and type(b) == "number" then return { r, g, b } end
		end
	end
	return builtIn
end
-- Seconds the weather's tint takes to come in or go: the Weather Style
-- page's while it's on, else WEATHER_BLEND_TIME.
ns.WeatherBlendTime = function()
	db = db or ns.GetDB()
	if db and ns.StyleOn and ns.StyleOn("weatherStyle", db) and type(db.weatherBlendTime) == "number" then
		return db.weatherBlendTime
	end
	return WEATHER_BLEND_TIME
end
ns.RefreshTint = function()
	tintDirty = true
	innCheckedAt = 0 -- pick up an inn glow setting change right away
	weatherCheckedAt = 0 -- ...and a weather one
end
-- For /cine debug weather: what the client reports (unclamped), whether you're
-- indoors, and the colour aimed for and shown.
ns.GetWeatherDebug = function()
	db = db or ns.GetDB()
	local info = { api = C_Weather ~= nil and C_Weather.GetCurrentWeather ~= nil }
	if info.api then
		local ok, weather = pcall(C_Weather.GetCurrentWeather)
		if not ok then
			info.error = true
		elseif type(weather) == "table" and not IsSecret(weather) then
			info.kind, info.intensity = weather.type, weather.intensity
			info.secret = IsSecret(info.kind) or IsSecret(info.intensity)
		end
	end
	for name, value in pairs(WEATHER_TYPE) do
		if value == info.kind then
			info.kindName = name
		end
	end
	local ok, indoors = pcall(IsIndoors)
	info.indoors = ok and indoors
	info.target, info.shown = weatherTarget, weatherColor
	return info
end
-- The Tint tab (Atmosphere) is open: its Preview time can show the tint.
ns.SetTintPreview = function(on)
	tintPreview = on
	tintDirty = true
	if not on then
		-- Leaving the page: go back to the real clock. (The page is also hidden
		-- once while the options load, before saved settings exist.)
		db = db or ns.GetDB()
		if db then
			db.tintPreviewHour = -2 -- (the box starts empty next time)
		end
	end
end
-- Time-of-day phases for the options page and menu: { name, color, own, hour }.
-- (The options page builds before saved settings exist; built-in colours then.)
ns.GetTimePhases = function()
	db = db or ns.GetDB()
	local list = {}
	for _, phase in ipairs(TIME_PHASES) do
		list[#list + 1] = {
			name = phase[1], color = PhaseColor(phase[1]), hour = phase[2],
			own = db ~= nil and db.timePhaseColors ~= nil and db.timePhaseColors[phase[1]] ~= nil,
			strength = PhaseStrength(phase[1]),
			ownStrength = db ~= nil and db.timePhaseStrength ~= nil and db.timePhaseStrength[phase[1]] ~= nil,
		}
	end
	return list
end
-- Your own colour for a phase ({ r, g, b }), or nil for the built-in one.
ns.SetTimePhaseColor = function(name, color)
	db = db or ns.GetDB()
	db.timePhaseColors[name] = color
	tintDirty = true
end
-- Your own strength for a phase (0-1), or nil for its default.
ns.SetTimePhaseStrength = function(name, strength)
	db = db or ns.GetDB()
	if strength and math.abs(strength - (DEFAULT_PHASE_STRENGTH[name] or 1)) < 0.001 then
		strength = nil -- same as the default: nothing of your own to keep
	end
	db.timePhaseStrength[name] = strength
	tintDirty = true
end
-- /cine tinttest: each time of day in turn (Dawn to Night), this many seconds
-- each: the tint glides to it, whatever your preset, and its title shows (with
-- its sound). Called while running (or with no seconds), it stops. True if it
-- started. onStop runs when it stops, either way. quiet: no titles, and each
-- glide done within its stop, and only the times with a color (the day itself
-- is untinted: three white stops showed nothing, 2026-11-20). The welcome
-- window's Tint demo: the colors, not seven title cards.
ns.DaySweep = function(seconds, onStop, quiet)
	if daySweep or not seconds then
		if daySweep then
			local stopped = daySweep.onStop
			daySweep = nil
			tintDirty = true
			if stopped then stopped() end
		end
		return false
	end
	daySweep = { started = GetTime(), each = seconds, onStop = onStop, quiet = quiet,
		glide = quiet and math.min(DAY_SWEEP_GLIDE, seconds * 0.7) or nil,
		stops = quiet and { { "Dawn", 390 }, { "Golden hour", 1110 }, { "Dusk", 1200 }, { "Night", 60 } }
			or DAY_SWEEP_STOPS }
	tintDirty = true
	return true
end
-- Phase name at a given hour, for labelling the preview choices.
ns.GetTimeOfDayPhaseAt = function(hour)
	local minutes = hour * 60
	for i = 1, #TIME_OF_DAY - 1 do
		local from, to = TIME_OF_DAY[i], TIME_OF_DAY[i + 1]
		if minutes >= from[1] and minutes < to[1] then
			local t = (minutes - from[1]) / (to[1] - from[1])
			return (t < 0.5 and from or to)[3]
		end
	end
	return TIME_OF_DAY[1][3]
end
ns.TINT_PRESETS = TINT_PRESETS
ns.TintSetGradient = SetGradient -- (the Tint Style page's pictures)
ns.OnLanguage(function()
	ns.TranslateFields(TINT_PRESETS, "label", "tip")
	ns.TranslateFields(ZONE_MOODS, 2)
end)

-- For the options page: the zone (default: the one you're in), its tint's
-- label, whether that's your override, and the colour.
ns.GetZoneTintInfo = function(zoneName)
	db = db or ns.GetDB()
	zoneName = zoneName or GetRealZoneText() or ""
	local color, label, isOverride = ZoneTint(zoneName)
	return zoneName, label, isOverride, color
end
-- Built-in moods for the override menu: { key, label, color } in order.
-- Every zone with a built-in mood, by name (this client's language), sorted:
-- { name, mood } each, mood its key. (For the Tint Style page's zone list.)
ns.GetMoodZones = function()
	CurrentZoneMood() -- (builds the name lookup)
	local list = {}
	for name, mood in pairs(zoneMoodByName) do list[#list + 1] = { name = name, mood = mood } end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end
ns.GetZoneMoods = function()
	local list = {}
	for _, key in ipairs(ZONE_MOOD_ORDER) do
		list[#list + 1] = { key = key, label = ZONE_MOODS[key][2], color = ZONE_MOODS[key][1] }
	end
	return list
end
-- Sets a zone's override: "none", a mood key, { r, g, b }, or nil to go back
-- to the built-in mood.
ns.SetZoneTint = function(zoneName, value)
	db = db or ns.GetDB()
	db.zoneTints[zoneName] = value
	tintDirty = true
end
-- A zone's strength for the Zone presets (0-1), or nil to use the main
-- Strength. GetZoneTintStrength also returns whether the zone has its own.
ns.SetZoneTintStrength = function(zoneName, value)
	db = db or ns.GetDB()
	db.zoneTintStrength[zoneName] = value
	tintDirty = true
end
ns.GetZoneTintStrength = function(zoneName)
	db = db or ns.GetDB()
	return ZoneStrength(zoneName)
end
-- The area you're in (or nil), its tint's label, whether that's the area's own,
-- the colour, its strength, its default strength, and whether it has its own.
ns.GetAreaTintInfo = function()
	db = db or ns.GetDB()
	local area = CurrentArea()
	if not area or not db then -- (no saved settings yet while the options page builds)
		return nil
	end
	local color, label, own = HereTint()
	local strength, default, ownStrength = HereStrength()
	return area, own and label or L["same as the zone"], own, color, strength, default, ownStrength
end
-- The preset where you're standing (a zone's or area's own, else the main
-- one), and where it came from: "area", "zone" or nil.
ns.GetTintPresetHere = function()
	db = db or ns.GetDB()
	if not db then
		return nil -- (the options page builds before saved settings exist)
	end
	return HerePreset()
end
-- A zone's or area's own preset (a preset key), or nil to use the main one.
ns.SetZonePreset = function(name, preset)
	db = db or ns.GetDB()
	db.zonePresets[name] = preset
	tintDirty = true
end
ns.GetZonePreset = function(name)
	db = db or ns.GetDB()
	return db and db.zonePresets and db.zonePresets[name]
end
ns.GetTintPresetLabel = function(key)
	if TINT_BY_KEY[key] then return TINT_BY_KEY[key].label end
	db = db or ns.GetDB()
	local mine = MyTint(key)
	return mine and mine.name or key
end
-- My tints (see MyTint): the list, in order, and changing it.
ns.GetMyTints = function()
	db = db or ns.GetDB()
	return db and db.myTints or {}
end
ns.GetMyTint = function(key)
	db = db or ns.GetDB()
	return MyTint(key)
end
-- Adds one ({ name, color, color2, glow }); returns its key.
ns.AddMyTint = function(tint)
	db = db or ns.GetDB()
	db.myTints = db.myTints or {}
	local n = (db.myTintNext or 0) + 1
	for _, each in ipairs(db.myTints) do -- (never a key that's taken)
		local used = tonumber(tostring(each.key):match("^mine(%d+)$"))
		if used and used >= n then n = used + 1 end
	end
	db.myTintNext = n
	tint.key = "mine" .. n
	db.myTints[#db.myTints + 1] = tint
	tintDirty = true
	return tint.key
end
ns.UpdateMyTint = function(key, fields)
	db = db or ns.GetDB()
	local tint = MyTint(key)
	if not tint then return end
	for field, value in pairs(fields) do tint[field] = value end
	if fields.color2 == false then tint.color2 = nil end
	tintDirty = true
end
-- Removes one; wherever it was picked goes back to the usual look.
ns.DeleteMyTint = function(key)
	db = db or ns.GetDB()
	local list = db and db.myTints
	if not list then return end
	for i = #list, 1, -1 do
		if list[i].key == key then table.remove(list, i) end
	end
	if db.tintPreset == key then db.tintPreset = ns.DEFAULTS and ns.DEFAULTS.tintPreset or "zonetime" end
	for name, preset in pairs(db.zonePresets or {}) do
		if preset == key then db.zonePresets[name] = nil end
	end
	tintDirty = true
end
-- For the Tint Style page's pictures: a look's colors as they'd be here and
-- now, before its strength: top, bottom (r, g, b each) and its mode ("MOD",
-- "ADD"), or nil for no tint.
ns.GetTintPictureColors = function(key)
	db = db or ns.GetDB()
	if not db then return nil end
	local preset = PresetOf(key)
	if not preset.mode then return nil end
	local top, bottom
	if key == "custom" then
		top = { db.tintCustomR, db.tintCustomG, db.tintCustomB }
	elseif key == "timeofday" then
		top = TimeOfDayColor()
	elseif key == "zone" then
		top = HereTint()
	elseif key == "zonetime" then
		local zone, time = HereTint(), TimeOfDayColor()
		top = { zone[1] * time[1], zone[2] * time[2], zone[3] * time[3] }
	else
		top, bottom = preset.top or preset.color, preset.bottom or preset.color
	end
	return top, bottom or top, preset.mode
end
-- The strength a look shows with here: a zone look's is the zone's (or the
-- area's) own, else the main one.
ns.GetTintStrengthFor = function(key)
	db = db or ns.GetDB()
	if key == "zone" or key == "zonetime" then return (HereStrength()) end
	return db.tintStrength
end
-- A phase's color as the day cycle blends it at hour:30 (with each phase's
-- own strength, before the Time of day strength), for the day bar.
ns.GetTimeOfDayColorAt = function(hour)
	db = db or ns.GetDB()
	local now = hour * 60 + 30
	for i = 1, #TIME_OF_DAY - 1 do
		local from, to = TIME_OF_DAY[i], TIME_OF_DAY[i + 1]
		if now >= from[1] and now < to[1] then
			local t = (now - from[1]) / (to[1] - from[1])
			local a, b = AppliedPhaseColor(from[3]), AppliedPhaseColor(to[3])
			return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
		end
	end
	return AppliedPhaseColor(TIME_OF_DAY[1][3])
end
-- For the options page: the current time-of-day phase name and clock time.
ns.GetTimeOfDayInfo = function()
	db = db or ns.GetDB()
	local _, phase, hour, minute = TimeOfDayColor()
	return phase, hour, minute
end
end)
