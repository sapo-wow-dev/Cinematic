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

-- The camera haze's default, and the old one moved along (Migrations.lua).
Check("camera haze 15% by default", ns.DEFAULTS.dofIdle == 0.15 and ns.FocusScaledStrength(1) >= 0.15,
	ns.FocusScaledStrength(1))
do
	local old = { dofIdle = 0.025, dofCozy = 0.05, dofVista = 0, dofFlight = 0.025 }
	ns.RaiseOldHaze(old)
	Check("old 2.5% haze raised, hand-picked kept", old.dofIdle == 0.15 and old.dofFlight == 0.15
		and old.dofCozy == 0.05 and old.dofVista == 0)
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

-- /cine debug atmosphere on the stand-in. (Its page opened first, so the
-- buttons are made: a click runs its OnClick, as the game's does.)
ns.OpenOptions("Effects")
for _, button in ipairs(ns.effectPreviewButtons or {}) do
	button.Click = function(self) self:GetScript("OnClick")(self) end
end
ns.HandleSlash("debug atmosphere 1 2 3 4 5 6 7 8 9 10") -- (11, live: needs the game's CineMode tick)
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
