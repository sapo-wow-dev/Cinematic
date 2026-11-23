-- The Visual Effects page's previews (offline, Lua 5.1 via run.py):
--   python -I Tools/offline/run.py Tools/offline/atmopreview.lua <forever|retail> < /dev/null
-- Tint.lua's ns.PreviewEffect drawn out of CineMode (2026-11-23: with the
-- settings open nothing showed, the effects being CineMode's only), with the
-- tint's tick driven by hand on pretend time. Checks:
--   the vignette's eased darkness (5% visible now) and the slider's preview;
--   each weather's colour at Weather strength Off (50%), indoors or not;
--   the inn glow with the Tint page off; previews end and fade out;
--   then /cine debug atmosphere (Dev/AtmosphereTest.lua) runs to DONE.
-- Says PASS or FAIL per check; exits 1 on any FAIL.
local client = ... or "forever"

-- luacheck: push ignore 111 112 113 121 122 212
local ns = dofile("Tools/offline/load.lua")(client, "CinematicDev.toc", function()
	-- (The game's weather types: the stand-in's stubs are all one value.)
	local E = rawget(_G, "Enum")
	if type(E) ~= "table" then E = {} rawset(_G, "Enum", E) end
	rawset(E, "WeatherType", { None = 0, Rain = 1, Snow = 2, Sandstorm = 3, Miscellaneous = 4 })
end)
-- luacheck: pop

local fails = 0
local function Check(name, ok, detail)
	if not ok then fails = fails + 1 end
	print(("%s %s: %s%s"):format(ok and "PASS" or "FAIL", client, name, detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 0.02 end

-- luacheck: push ignore 121 122
local now, timers, tickers = 100, {}, {}
GetTime = function() return now end
C_Timer.After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
C_Timer.NewTicker = function(every, fn)
	local t = { every = every, next = now + every, fn = fn, Cancel = function(self) self.cancelled = true end }
	tickers[#tickers + 1] = t
	return t
end
Screenshot = function() end
-- luacheck: pop
ns.PadTestBox, ns.PadTestBoxHide = function() end, function() end
ns.noRealLayout = true -- (the stand-in places every frame alike: r:Overlaps can't judge them)

-- Seconds of pretend time, the tint's tick (out of CineMode) every 0.1.
local function Run(seconds)
	for _ = 1, math.floor(seconds / 0.1 + 0.5) do
		now = now + 0.1
		local due = {}
		for i = #timers, 1, -1 do if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end end
		for i = #due, 1, -1 do due[i].fn() end
		for _, t in ipairs(tickers) do
			if not t.cancelled and t.next <= now then t.next = now + t.every t.fn(t) end
		end
		ns.UpdateTint(false, 0.1, false, false)
		for _, button in ipairs(ns.effectPreviewButtons or {}) do -- (their Stop text: OnUpdate)
			local update = button:GetScript("OnUpdate")
			if update then update(button, 0.1) end
		end
	end
end
local function Drawn() return ns.tintDrawn or {} end

local db = ns.db
Check("Atmosphere loaded, previews there", ns.PreviewEffect ~= nil and ns.UpdateTint ~= nil)
if not ns.PreviewEffect then os.exit(1) end
db.visualEffects, db.vignette, db.weatherTint, db.innGlow = true, true, true, true

-- The eased vignette.
Check("vignette 5% shows at 17%", Near(ns.VignetteAlpha(0.05), 0.166), ns.VignetteAlpha(0.05))
Check("vignette 100% stays 100%", ns.VignetteAlpha(1) == 1)
Check("vignette 0 stays 0", ns.VignetteAlpha(0) == 0)

-- Nothing out of CineMode without a preview.
Run(1)
Check("no vignette out of CineMode", (Drawn().vignette or 0) == 0, Drawn().vignette)

db.vignetteStrength = 0.05
ns.PreviewEffect("vignette")
Run(0.2)
Check("vignette preview drawn at once out of CineMode", Near(Drawn().vignette, ns.VignetteAlpha(0.05)), Drawn().vignette)
Check("the tint frame up for it", _G.CinematicTint and _G.CinematicTint:IsShown())
Run(ns.EFFECT_PREVIEW_SECONDS + (db.fadeOutTime or 1) + (db.fadeInTime or 1) + 1)
Check("vignette gone once the preview ends", (Drawn().vignette or 0) == 0, Drawn().vignette)
Check("the tint frame hidden again", not _G.CinematicTint:IsShown())

-- Weather at Off: 50% of each colour, indoors or not.
db.weatherTintStrength = 0
IsIndoors = function() return true end -- luacheck: ignore 121
for _, each in ipairs(ns.PreviewWeatherTypes()) do
	ns.PreviewEffect("weather", 4, each[1])
	Run(0.3)
	local d, c = Drawn(), each[3]
	Check(each[2] .. " previewed at 50%", Near(d.wr, 1 - (1 - c[1]) * 0.5) and Near(d.wg, 1 - (1 - c[2]) * 0.5)
		and Near(d.wb, 1 - (1 - c[3]) * 0.5), ("%s %s %s"):format(tostring(d.wr), tostring(d.wg), tostring(d.wb)))
end
ns.StopEffectPreview()
Run(4)
Check("weather layer gone after Stop", Near(Drawn().wr, 1) and Near(Drawn().wb, 1), Drawn().wr)

-- The inn glow with the Tint page off (it needed the tint itself showing).
db.tintPage, db.innGlowAmount = false, 0.1
ns.PreviewEffect("inn", 4)
Run(0.3)
Check("inn glow previewed with the Tint page off", Near(Drawn().glow, 0.1), Drawn().glow)
db.innGlow = false
ns.RefreshTint()
ns.PreviewEffect("inn", 4)
Run(0.6)
Check("no inn glow while Inn glow is Off", (Drawn().glow or 0) == 0, Drawn().glow)
db.innGlow, db.tintPage = true, true
Run(6)

-- The vignette off to start with (2026-11-23: it never showed till then,
-- and on for everyone would have brought it in unasked), every built-in
-- profile leaving it off, and the old saves turned off once (Migrations.lua).
Check("vignette off by default (switch and its row's Always)", ns.DEFAULTS.vignette == false
	and ns.DEFAULTS.vignetteAlways == false)
do
	local on = {}
	for _, name in ipairs(ns.ProfileNames()) do
		if ns.IsBuiltinProfile(name) then
			-- (Its base as built, not the live settings: this check's own run set the
			-- active one's vignette on above.)
			local t = ns.ProfileBase(name) or {}
			local switch, always = t.vignette, t.vignetteAlways
			if switch == nil then switch = ns.DEFAULTS.vignette end
			if always == nil then always = ns.DEFAULTS.vignetteAlways end
			if switch or always then on[#on + 1] = name end
		end
	end
	Check("no built-in profile turns the vignette on", #on == 0, table.concat(on, ", "))
	local old = { vignette = true, vignetteAlways = true, vignetteStrength = 0.4,
		camShow = { ["effect:vignette"] = true, ["effect:tint"] = true }, frameRules = { ["effect:vignette"] = "target" } }
	ns.VignetteOff(old)
	Check("an old save's vignette turned off, its strength and other rows kept", old.vignette == false
		and old.vignetteAlways == false and old.vignetteStrength == 0.4 and old.camShow["effect:vignette"] == nil
		and old.camShow["effect:tint"] == true and old.frameRules["effect:vignette"] == nil)
end

-- The Glow's and Haze's Show in rows (2026-11-23): not Always, their own
-- rules to start with (in an inn, the camera modes), in every built-in
-- profile; an old save with either off has its row nowhere (Migrations.lua);
-- the glow drawn by its row and slider alone, no preview and nothing about
-- inns left in the code (the row's rule says where), gone with its row off.
Check("Glow and Haze rows start from their rules", ns.DEFAULTS.innAlways == false and ns.DEFAULTS.hazeAlways == false
	and ns.RULE_DEFAULTS["effect:inn"] == "inn and indoors" and ns.RULE_DEFAULTS["effect:haze"] == "camera")
do
	local wrong = {}
	for _, name in ipairs(ns.ProfileNames()) do
		if ns.IsBuiltinProfile(name) then
			local rules = (ns.ProfileBase(name) or {}).frameRules or {}
			if rules["effect:inn"] ~= "inn and indoors" or rules["effect:haze"] ~= "camera" then wrong[#wrong + 1] = name end
		end
	end
	Check("every built-in profile has Glow in inns and Haze in the camera modes", #wrong == 0, table.concat(wrong, ", "))
	local old = { innGlow = false, depthOfField = true }
	ns.EffectRowsFromSwitches(old)
	Check("an old save's Off glow: its row nowhere (rule cleared), the haze's left", old.innAlways == false
		and old.frameRules["effect:inn"] == "" and old.hazeAlways == nil and old.frameRules["effect:haze"] == nil)
	db.innGlow, db.innGlowAmount, db.tintPage = true, 0.3, true
	ns.StopEffectPreview()
	Run(4)
	ns.effectWanted.inn = true
	ns.RefreshTint()
	Run(4)
	Check("inn glow drawn by its row and slider, no preview", Near(Drawn().glow, 0.3), Drawn().glow)
	ns.effectWanted.inn = false
	ns.RefreshTint()
	Run(4)
	Check("inn glow gone with its row off", (Drawn().glow or 0) == 0, Drawn().glow)
	-- The tint lifts only where the Glow shows (in an inn to start with): it
	-- lifted by the Glow's switch alone, every tint at 40% everywhere,
	-- 2026-11-23 ("this zone looked a lot darker").
	local preset, strength, drift = db.tintPreset, db.tintStrength, db.tintDrift
	db.tintPreset, db.tintStrength, db.tintDrift = "warm", 1, false
	local function TintRun(seconds)
		for _ = 1, math.floor(seconds / 0.1 + 0.5) do
			now = now + 0.1
			ns.UpdateTint(true, 0.1, false, false)
		end
	end
	ns.effectWanted.inn = false
	ns.RefreshTint()
	TintRun(6)
	Check("the tint at full strength with the Glow's row off (out of an inn)", Near(Drawn().strength, 1),
		Drawn().strength)
	ns.effectWanted.inn = true
	ns.RefreshTint()
	TintRun(6)
	Check("...lifted to 40% where the Glow's row shows (an inn)", Near(Drawn().strength, 0.4), Drawn().strength)
	ns.effectWanted.inn = false
	ns.RefreshTint()
	TintRun(6)
	db.tintPreset, db.tintStrength, db.tintDrift = preset, strength, drift
	ns.effectWanted.inn = nil
end

-- The haze: one strength, 0-100% in 1% steps, 0 to start with (2026-11-23: "haze seems
-- to be doing nothing"); an old save's 0-200% scale and the camera modes' own
-- strengths gone (Migrations.lua); the built-in cameras' haze is Haze
-- strength's, shown on their script page as that setting; a pale mist.
Check("Haze strength 0 to start with, the modes' own gone", ns.DEFAULTS.dofScale == 0
	and ns.DEFAULTS.dofIdle == nil and ns.DEFAULTS.dofFlight == nil)
do
	local old = { dofScale = 2, dofIdle = 0.15, dofWalk = 0, depthOfField = true }
	ns.HazeToOneStrength(old)
	Check("an old save's haze: 0, the modes' own gone, its switch kept", old.dofScale == 0 and old.dofIdle == nil
		and old.dofWalk == nil and old.depthOfField == true)
	local file = io.open("Camera/CameraScripts.lua")
	local text = file:read("*a")
	file:close()
	local own, set = 0, 0
	for _ in text:gmatch("haze = Db%(") do own = own + 1 end
	for _ in text:gmatch('haze = { "dofScale" }') do set = set + 1 end
	Check("built-in cameras: no haze of their own, Haze strength's instead", own == 0 and set == 4,
		("%d own, %d set by Haze strength"):format(own, set))
	file = io.open("Media/make_focus.py")
	local maker = file:read("*a")
	file:close()
	Check("the haze is a pale mist (its maker's grey 0.8 or more)", (tonumber(maker:match("g = ([%d.]+) %+")) or 0) >= 0.8)
end

-- No file names the addon's folder outright: "Interface\AddOns\Cinematic\"
-- found nothing in the dev copy (folder CinematicDev), so the haze's texture
-- never loaded there and it drew nothing (2026-11-23). ADDON_NAME instead.
do
	local pipe = io.popen('git ls-files "*.lua"')
	local hits = {}
	for path in pipe:lines() do
		local file = io.open(path)
		if file then
			local text = file:read("*a")
			file:close()
			if text:find("AddOns\\\\Cinematic\\\\", 1, true) and not path:find("^Tools/") then hits[#hits + 1] = path end
		end
	end
	pipe:close()
	Check("no file names the addon's folder outright (ADDON_NAME)", #hits == 0, table.concat(hits, ", "))
end

-- Core.lua's Step hands on only so many values: a call giving more lost the
-- rest (the tint's call lost the vignette's and weather's wanted, 2026-10-13
-- to 11-23: neither showed unless previewed). Every Step(...) call in
-- Core.lua counted against what Step takes.
local function StepFits(text)
	local params = text:match("local function Step%(fn,([^)]*)%)")
	local takes = 0
	for _ in (params or ""):gmatch("[%w_]+") do takes = takes + 1 end
	-- (Its own definition taken out first: not a call.)
	text = text:gsub("local function Step%b()", "")
	local worst, where = 0, nil
	for args in text:gmatch("[^%w_.:]Step(%b())") do
		-- (Top-level commas only: a call's own arguments, not nested ones.)
		local inner = args:sub(2, -2):gsub("%b()", "()"):gsub("%b{}", "{}")
		local count = 0
		for _ in inner:gmatch(",") do count = count + 1 end -- (after fn: one value per comma)
		if count > worst then worst, where = count, args:sub(1, 80) end
	end
	return takes > 0 and worst <= takes, takes, worst, where
end
do
	local file = io.open("Core.lua")
	local text = file:read("*a")
	file:close()
	local fits, takes, worst, where = StepFits(text)
	Check(("Core.lua's Step hands on every value its calls give (takes %d, most given %d)"):format(takes, worst),
		fits, where)
	-- (And it catches the old two: Step(fn, a, b) with the tint's call.)
	local old = text:gsub("local function Step%(fn,[^)]*%)", "local function Step(fn, a, b)")
	Check("the check catches a Step that takes two", not StepFits(old))
end

-- The rules' world words (2026-11-23, for the Atmosphere effects' rows):
-- each read from the game's answers, set by hand here and turned on and off
-- (rain, snow, sandstorm, storm, weather, outdoors only; dawn, day, dusk,
-- night by the tint's clock; underwater; fast), every word on the rule
-- editor's lines, and a rule using them compiled and read.
do
	local g = { kind = 0, intensity = 0, indoors = false, hour = 12, minute = 0, submerged = false, speed = 0 }
	-- luacheck: push ignore 121 122
	C_Weather = { GetCurrentWeather = function() return { type = g.kind, intensity = g.intensity } end }
	IsIndoors = function() return g.indoors end
	IsSubmerged = function() return g.submerged end
	GetUnitSpeed = function() return g.speed end
	GetGameTime = function() return g.hour, g.minute end
	-- (The stand-in's stub said "gliding at 0", and stands in for any name it
	-- hasn't: not gliding, said outright.)
	if C_PlayerInfo then C_PlayerInfo.GetGlidingInfo = function() return false, false, 0 end end
	local onTaxi = ns.OnTaxi
	ns.OnTaxi = function() return false end -- (its stub said yes: fast is never on a flight path)
	-- luacheck: pop
	db.tintClock = "game"
	local function Facts()
		now = now + 1 -- (past the facts' hold: worked out again)
		return ns.RuleFacts(false)
	end
	local function Expect(label, set, want)
		for k, v in pairs(set) do g[k] = v end
		local f = Facts()
		local wrong = {}
		for word, value in pairs(want) do
			if f[word] ~= value then wrong[#wrong + 1] = word .. "=" .. tostring(f[word]) end
		end
		if #wrong > 0 then
			wrong[#wrong + 1] = ("speed %s, taxi %s"):format(tostring(ns.PlayerSpeedNow()), tostring(f.taxi))
		end
		Check("world words: " .. label, #wrong == 0, table.concat(wrong, ", "))
	end
	Expect("clear day", { kind = 0, intensity = 0, hour = 12 }, { rain = false, snow = false, weather = false,
		storm = false, day = true, night = false, dawn = false, dusk = false })
	Expect("light rain", { kind = 1, intensity = 0.3 }, { rain = true, weather = true, storm = false, snow = false })
	Expect("heavy rain: storm", { kind = 1, intensity = 0.9 }, { rain = true, storm = true })
	Expect("rain under a roof: none", { indoors = true }, { rain = false, weather = false, storm = false })
	Expect("snow", { indoors = false, kind = 2, intensity = 0.7 }, { snow = true, storm = true, rain = false })
	Expect("sandstorm: no storm", { kind = 3, intensity = 1 }, { sandstorm = true, weather = true, storm = false })
	Expect("dawn 6:00", { kind = 0, hour = 6 }, { dawn = true, day = false, weather = false })
	Expect("dusk 18:30", { hour = 18, minute = 30 }, { dusk = true, day = false })
	Expect("night 23:00", { hour = 23, minute = 0 }, { night = true, dusk = false })
	Expect("night 2:00", { hour = 2 }, { night = true })
	Expect("under water", { submerged = true }, { underwater = true })
	Expect("fast at 14", { submerged = false, speed = 14 }, { fast = true, underwater = false })
	Expect("not fast at 7 (running)", { speed = 7 }, { fast = false })
	local missing = {}
	local onLines = {}
	for _, group in ipairs(ns.RulePieces()) do
		for _, piece in ipairs(group[3]) do onLines[piece[1]] = true end
	end
	for _, word in ipairs({ "rain", "snow", "sandstorm", "storm", "weather", "dawn", "day", "dusk", "night",
		"underwater", "fast" }) do
		if not (ns.RULE_WORDS[word] and onLines[word]) then missing[#missing + 1] = word end
	end
	Check("every world word a rule word and on the editor's lines", #missing == 0, table.concat(missing, ", "))
	local test = ns.CompileRule("(rain or snow) and not night")
	Expect("a rule with them compiles", { kind = 1, intensity = 0.5, hour = 12 }, {})
	Check("(rain or snow) and not night reads true in daytime rain", test ~= nil and test(Facts()) == true)
	g.kind = 0
	Facts()
	ns.OnTaxi = onTaxi
end

-- View distance in bad weather: 0 to start with and in every built-in
-- profile (2026-11-23, the user: no graphics changed by default); an old
-- save at the 100% Cinema and Shoulder Cam gave it goes to 0, a hand-picked
-- value stays (Migrations.lua).
do
	local on = {}
	for _, name in ipairs(ns.ProfileNames()) do
		if ns.IsBuiltinProfile(name) then
			local value = (ns.ProfileBase(name) or {}).rainViewScale
			if value == nil then value = ns.DEFAULTS.rainViewScale end
			if (tonumber(value) or 0) > 0 then on[#on + 1] = name end
		end
	end
	Check("view distance in bad weather: 0 to start with and in every built-in profile",
		ns.DEFAULTS.rainViewScale == 0 and #on == 0, table.concat(on, ", "))
	local full, picked = { rainViewScale = 1 }, { rainViewScale = 0.4 }
	ns.RainViewOff(full)
	ns.RainViewOff(picked)
	Check("an old save's 100% goes to 0, a hand-picked 40% stays", full.rainViewScale == 0 and picked.rainViewScale == 0.4)
end

-- The Weather page's screen effects (WeatherFX.lua, 2026-11-23): nothing to
-- start with (strengths 0, rows by their weather's rules); each wanted by
-- its row at a strength draws it (frost creeping in, drops and trails,
-- flashes over time, the density held), gone with its row off; a preview at
-- Off shows half.
do
	Check("weather effects: nothing to start with", ns.DEFAULTS.weatherFrostStrength == 0
		and ns.DEFAULTS.weatherRainLensStrength == 0 and ns.DEFAULTS.weatherLightningStrength == 0
		and ns.DEFAULTS.weatherDensityLevel == 0 and ns.RULE_DEFAULTS["effect:frost"] == "snow"
		and ns.RULE_DEFAULTS["effect:rainlens"] == "rain" and ns.RULE_DEFAULTS["effect:lightning"] == "storm"
		and ns.RULE_DEFAULTS["effect:density"] == "weather")
	local fx = _G.CinematicWeatherFX
	local drawn = ns.weatherFxDrawn
	local function Tick(seconds)
		for _ = 1, math.floor(seconds / 0.1 + 0.5) do
			now = now + 0.1
			ns.WakeFeatureLoop(fx)
			local update = fx:GetScript("OnUpdate")
			if update then update(fx, 0.1) end
		end
	end
	Check("weather effects' frame and drawing there", fx ~= nil and drawn ~= nil)
	-- (Nothing on screen as loaded, every strength 0: textures left shown as
	-- made covered the screen from login, the user 2026-11-23, even after
	-- Reset Settings: the update never ran to hide them.)
	local function Showing()
		local on = {}
		for name, tex in pairs(ns.weatherFxTextures or {}) do
			if tex:IsShown() then on[#on + 1] = name end
		end
		table.sort(on)
		return table.concat(on, ", ")
	end
	Check("nothing of the weather effects shown as loaded", ns.weatherFxTextures ~= nil and Showing() == "", Showing())
	-- (Its update runs only while it's shown: hidden till something drew,
	-- nothing ever did, in game run 1. Here the update's called by hand.)
	Check("weather effects' frame stays shown (a hidden frame's update never runs)", fx and fx:IsShown())
	db.enabled, db.visualEffects, db.weatherPage = true, true, true
	db.weatherFrostStrength, db.weatherRainLensStrength, db.weatherLightningStrength = 0.6, 0.5, 0.8
	db.weatherDensityLevel = 2
	ns.effectWanted.frost = true
	Tick(14)
	Check("frost creeps in to its strength", Near(drawn.frost, 0.6), drawn.frost)
	ns.effectWanted.frost = false
	Tick(6)
	Check("frost melts with its row off", drawn.frost == 0, drawn.frost)
	ns.effectWanted.rainlens = true
	Tick(3)
	Check("rain on the lens: drops and trails", (drawn.drops or 0) > 0 and Near(drawn.streaks, 0.5 * 0.45),
		("drops %s, streaks %s"):format(tostring(drawn.drops), tostring(drawn.streaks)))
	ns.effectWanted.rainlens = false
	Tick(6)
	Check("rain on the lens dries with its row off", drawn.drops == 0 and drawn.streaks == 0)
	ns.effectWanted.lightning = true
	local flashes, brightest = ns.lightningFlashes or 0, 0
	for _ = 1, 600 do
		Tick(0.1)
		brightest = math.max(brightest, drawn.flash or 0)
	end
	Check("lightning flashes in a storm (60 seconds)", (ns.lightningFlashes or 0) - flashes >= 2 and Near(brightest, 0.8 * 0.6),
		("%d flashes, brightest %.2f"):format((ns.lightningFlashes or 0) - flashes, brightest))
	ns.effectWanted.lightning = false
	Tick(2)
	ns.effectWanted.density = true
	Tick(0.2)
	Check("heavier weather holds the game's density at its level", drawn.density == 2, drawn.density)
	ns.effectWanted.density = false
	Tick(0.2)
	Check("...and lets it go with its row off", drawn.density == nil, drawn.density)
	db.weatherFrostStrength = 0
	ns.WeatherFxPreview("frost", 3)
	Tick(1)
	Check("a frost preview at Off shows half", Near(drawn.frost, 0.5), drawn.frost)
	ns.WeatherFxPreview(nil)
	Tick(6)
	Check("...gone after it", drawn.frost == 0, drawn.frost)
	Check("nothing of the weather effects shown with none wanted", Showing() == "", Showing())
	db.weatherRainLensStrength, db.weatherLightningStrength, db.weatherDensityLevel = 0, 0, 0
end

-- /cine debug atmosphere on the stand-in. (Its page opened first, so the
-- buttons are made: a click runs its OnClick, as the game's does.)
ns.OpenOptions("Effects")
for _, button in ipairs(ns.effectPreviewButtons or {}) do
	button.Click = function(self) self:GetScript("OnClick")(self) end
end
ns.HandleSlash("debug atmosphere 1 2 3 4 5 6 7 8 9 10 14") -- (11-13: need the game's CineMode tick)
Run(80)
local done
for _, line in ipairs(CinematicDB.atmosphereTestLog or {}) do
	if line:find("DONE: ", 1, true) or line:find("STOPPED: ", 1, true) then done = line end
	if line:find("verdict FAIL", 1, true) then print("  " .. line) end
end
Check("/cine debug atmosphere: DONE, 0 fail", done and done:find(" 0 fail", 1, true) ~= nil, done)

if fails > 0 then
	print(("%d FAIL"):format(fails))
	os.exit(1)
end
print("all PASS")
